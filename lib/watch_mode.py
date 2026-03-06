#!/usr/bin/env python3
"""
OpenClaw Observe — Live Reliability Monitor
octriage -watch

Spec: ARCH/OPS CONTROL PLANE SPEC — EXACT OBSERVE LAYER CLI LAYOUT
Refresh: 10s (configurable via --interval)
Safety: read-only, display-only, never modifies system state
"""

from __future__ import annotations
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
HOME         = Path.home()
OC_ROOT      = HOME / ".openclaw"
WS           = OC_ROOT / "workspace"
REPORTS      = WS / "reports"
PROT_LOG     = WS / "logs" / "protection_events.ndjson"
OPS_LOG      = OC_ROOT / "ops" / "ops_events.log"

OBSERVE_SNAP = REPORTS / "observe_snapshot.json"
SCORE_FILE   = REPORTS / "reliability_score.json"
PROT_REPORT  = REPORTS / "protection_report.json"
RECOVERY_S   = REPORTS / "recovery_status.json"
RECOVERY_H   = REPORTS / "recovery_history.json"
TOPOLOGY     = REPORTS / "agent_topology.json"
HYGIENE      = REPORTS / "runtime_hygiene.json"
DIGEST_FILE  = WS / "DIGEST.md"

ORP_RUNS_DIR = REPORTS / "orp_runs"

# ── Colors ────────────────────────────────────────────────────────────────────
NO_COLOR = os.environ.get("NO_COLOR", "") != "" or not sys.stdout.isatty()

def _c(code: str, text: str) -> str:
    if NO_COLOR:
        return text
    return f"\033[{code}m{text}\033[0m"

def green(t):  return _c("1;32", t)
def yellow(t): return _c("1;33", t)
def red(t):    return _c("1;31", t)
def cyan(t):   return _c("1;36", t)
def bold(t):   return _c("1",    t)
def dim(t):    return _c("90",   t)

def colorize_state(val: str) -> str:
    v = val.upper()
    if any(k in v for k in ("OK","HEALTHY","ACTIVE","MATCH","READY","PASS","NORMAL","SCHEDULED","NOMINAL")):
        return green(val)
    if any(k in v for k in ("WARN","DEGRADED","MISMATCH","ALERT","PARTIAL","UNKNOWN")):
        return yellow(val)
    if any(k in v for k in ("FAIL","AT_RISK","AT RISK","RISK","ERROR","STOP","MISS")):
        return red(val)
    return val

def colorize_severity(sev: str) -> str:
    s = sev.lower()
    if s in ("info", "debug"):    return dim(sev)
    if s in ("warn", "warning"):  return yellow(sev)
    if s in ("error", "critical"):return red(sev)
    return sev

# ── Data helpers ──────────────────────────────────────────────────────────────
def rj(path: Path, default=None):
    """Read JSON file, return default on any error."""
    try:
        return json.loads(path.read_text())
    except Exception:
        return default if default is not None else {}

def safe(d: dict, *keys, fallback="unknown"):
    """Safe nested dict get with fallback."""
    cur = d
    for k in keys:
        if not isinstance(cur, dict):
            return fallback
        cur = cur.get(k, None)
        if cur is None:
            return fallback
    return cur if cur is not None else fallback

def probe_gateway(port=18789, timeout=1.5) -> str:
    try:
        import urllib.request
        urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=timeout)
        return "OK (http_ok)"
    except Exception:
        return "FAIL (probe_timeout)"

def check_disk() -> str:
    try:
        result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=2)
        parts = result.stdout.strip().splitlines()
        if len(parts) >= 2:
            cols = parts[1].split()
            pct = cols[4].rstrip("%")
            avail = cols[3]
            pct_int = int(pct)
            state = "OK" if pct_int < 80 else ("WARN" if pct_int < 90 else "CRITICAL")
            return f"{state} ({pct}% used, {avail} free)"
    except Exception:
        pass
    return "unknown"

def check_digest() -> str:
    try:
        content = DIGEST_FILE.read_text()
        return "STALE" if "stale: true" in content else "HEALTHY"
    except Exception:
        return "unknown"

def check_builder() -> str:
    try:
        result = subprocess.run(["launchctl", "list"], capture_output=True, text=True, timeout=2)
        if "digest_builder" in result.stdout:
            return "SCHEDULED"
        return "UNLOADED"
    except Exception:
        return "unknown"

def check_verify() -> tuple[str, str, str]:
    """Returns (state, installed_sha, expected_sha)."""
    try:
        oc_dir = Path(__file__).parent.parent
        ver_file = oc_dir / "VERSION"
        sha_file = oc_dir / "SHA256SUMS"
        canonical_file = oc_dir / "OPENCLAW_CANONICAL_SOURCE.md"

        installed_sha = ""
        # Check script sha
        script = oc_dir / "bin" / "control-plane-triage"
        if script.exists():
            r = subprocess.run(["shasum", "-a", "256", str(script)], capture_output=True, text=True, timeout=2)
            if r.returncode == 0:
                installed_sha = r.stdout.split()[0][:8]

        expected_sha = "unknown"
        if sha_file.exists():
            lines = sha_file.read_text().splitlines()
            for line in lines:
                if "control-plane-triage" in line:
                    expected_sha = line.split()[0][:8]
                    break

        if installed_sha and expected_sha != "unknown":
            state = "MATCH" if installed_sha == expected_sha else "MISMATCH"
        else:
            state = "UNKNOWN"
        return state, installed_sha, expected_sha
    except Exception:
        return "UNKNOWN", "?", "?"

# ── Sprint 2 helpers ──────────────────────────────────────────────────────────

def agent_activity_rate() -> str:
    """Task 1: events/sec over last 5-minute window."""
    ops = OC_ROOT / "watchdog" / "ops_events.log"
    wd  = OC_ROOT / "watchdog" / "watchdog.log"
    log = ops if ops.exists() else (wd if wd.exists() else None)
    if log is None:
        return "unknown (no log)"
    cutoff = time.time() - 300
    count = 0
    try:
        for line in log.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                ts = d.get("ts") or d.get("timestamp") or ""
                if ts:
                    t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    if t.timestamp() >= cutoff:
                        count += 1
            except Exception:
                pass
    except Exception:
        pass
    if count == 0:
        return "0 events/sec (possible stall)"
    return f"{count/300:.2f} events/sec (5m window)"


def compaction_status() -> str:
    """Task 5: last compaction status from SENTINEL events or alert_state fallback."""
    ops = OC_ROOT / "watchdog" / "ops_events.log"
    if ops.exists():
        last = None
        try:
            for line in ops.read_text().splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                    ev = d.get("event") or d.get("event_type") or ""
                    if ev == "SENTINEL_COMPACTION_COMPLETE":
                        last = d
                except Exception:
                    pass
        except Exception:
            pass
        if last:
            status = last.get("status", "UNKNOWN")
            dur = last.get("duration_minutes", last.get("duration_m", "?"))
            return f"{status} ({dur}m)"
    # Fallback: compaction_alert_state.json
    alert_f = OC_ROOT / "watchdog" / "compaction_alert_state.json"
    if alert_f.exists():
        d = rj(alert_f)
        return d.get("alert_level", "UNKNOWN")
    return "UNKNOWN"


def reliability_trend() -> str:
    """Task 3: compare current score to ~24h-ago score from radcheck_history.ndjson."""
    history = OC_ROOT / "watchdog" / "radcheck_history.ndjson"
    if not history.exists():
        return "insufficient history"
    entries: list[tuple] = []
    try:
        for line in history.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                ts = d.get("ts", "")
                score = d.get("score")
                if ts and score is not None:
                    t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    entries.append((t, int(score)))
            except Exception:
                pass
    except Exception:
        pass
    if len(entries) < 2:
        return "insufficient history"
    from datetime import timezone, timedelta
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=24)
    cur_score = entries[-1][1]
    past = [(abs((t - cutoff).total_seconds()), s) for t, s in entries if t <= cutoff]
    if not past:
        old_score = entries[0][1]
    else:
        past.sort()
        old_score = past[0][1]
    delta = cur_score - old_score
    sign = "+" if delta >= 0 else ""
    return f"{old_score} → {cur_score} ({sign}{delta})"


def fleet_identity() -> tuple[str, str]:
    """Task 4: (fleet_id, node_name)."""
    node = hostname()
    try:
        import getpass
        uname = getpass.getuser().upper()
    except Exception:
        uname = "LOCAL"
    node_up = node.upper()
    fleet = f"{uname}-{node_up}"
    return fleet, node.lower()


def events_detected_24h() -> int:
    """Task 2: count ops_events.log entries in last 24h."""
    ops = OC_ROOT / "watchdog" / "ops_events.log"
    if not ops.exists():
        return 0
    cutoff = time.time() - 86400
    count = 0
    try:
        for line in ops.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                ts = d.get("ts") or d.get("timestamp") or ""
                if ts:
                    t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    if t.timestamp() >= cutoff:
                        count += 1
            except Exception:
                pass
    except Exception:
        pass
    return count

# ─────────────────────────────────────────────────────────────────────────────

def recent_events(n=5) -> list[dict]:
    """Return last N events from protection_events.ndjson, newest first."""
    events = []
    log = PROT_LOG if PROT_LOG.exists() else OPS_LOG
    if not log.exists():
        return events
    try:
        lines = log.read_text().splitlines()[-200:]
        for line in reversed(lines):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
                events.append(e)
                if len(events) >= n:
                    break
            except Exception:
                continue
    except Exception:
        pass
    return events

def latest_orp() -> dict:
    """Return latest ORP run JSON."""
    if not ORP_RUNS_DIR.exists():
        return {}
    runs = sorted(ORP_RUNS_DIR.glob("orp_run_*.json"))
    if not runs:
        return {}
    return rj(runs[-1])

def dominant_status(gw, digest, builder, recovery_ready, runtime_alerts, score, verify_state):
    """Priority-ordered status reduction."""
    if "FAIL" in str(gw).upper():
        return "FAILED", "gateway unreachable"
    if verify_state in ("MISMATCH",):
        return "DEGRADED", "installed_mismatch"
    if verify_state == "UNKNOWN":
        return "DEGRADED", "verify unknown"
    if "STALE" in str(digest).upper():
        return "DEGRADED", "digest stale"
    if "UNLOAD" in str(builder).upper():
        return "DEGRADED", "builder unloaded"
    if not recovery_ready:
        return "AT_RISK", "recovery_ready=false"
    if runtime_alerts and int(runtime_alerts) > 0:
        return "DEGRADED", f"runtime_alerts={runtime_alerts}"
    if score and isinstance(score, (int, float)):
        if score < 70:
            return "AT_RISK", f"score={score}"
        if score < 85:
            return "DEGRADED", f"score={score}"
    return "HEALTHY", "all core layers stable"

def fmt_ts_short(ts_str: str) -> str:
    """Convert ISO timestamp to short HH:MM:SS display."""
    try:
        t = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        local = t.astimezone()
        return local.strftime("%H:%M:%S")
    except Exception:
        return ts_str[:19] if len(ts_str) >= 19 else ts_str

def local_ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")

def hostname() -> str:
    try:
        return subprocess.run(["hostname", "-s"], capture_output=True, text=True, timeout=1).stdout.strip()
    except Exception:
        return os.environ.get("HOSTNAME", "unknown")

def octriage_version() -> str:
    try:
        ver_file = Path(__file__).parent.parent / "VERSION"
        return ver_file.read_text().strip()
    except Exception:
        return "0.1.x"

# ── Screen render ─────────────────────────────────────────────────────────────
def render(interval: int):
    # ── Load all data sources ─────────────────────────────────────────────────
    observe  = rj(OBSERVE_SNAP)
    score_d  = rj(SCORE_FILE)
    prot     = rj(PROT_REPORT)
    rec_s    = rj(RECOVERY_S)
    rec_h    = rj(RECOVERY_H)
    topology = rj(TOPOLOGY)
    hygiene  = rj(HYGIENE)
    orp      = latest_orp()

    score    = score_d.get("score")
    pstate   = prot.get("protection_state", observe.get("protection_state", "unknown"))

    # SYSTEM HEALTH data
    gw      = probe_gateway()
    disk    = check_disk()
    digest  = check_digest()
    builder = check_builder()
    verify_state, v_inst, v_exp = check_verify()

    agents_d  = topology.get("agent_health", {})
    agents_n  = topology.get("gateway_agents", observe.get("agents", "unknown"))
    sessions  = topology.get("session_count", observe.get("sessions", "unknown"))
    orphans   = topology.get("orphan_sessions", observe.get("orphan_sessions", 0))
    recent_t  = sum(1 for v in agents_d.values() if v == "active") if agents_d else "?"
    sessions_str = f"NORMAL (agents={agents_n} recent={recent_t} orphan={orphans} total={sessions})"

    r_alerts   = observe.get("runtime_alerts", hygiene.get("stall_events", 0))
    gw_warn    = observe.get("gateway_warnings", hygiene.get("gateway_warnings", 0))
    pred_alerts= hygiene.get("predictive_alerts", 0)

    recovery_ready = rec_s.get("recovery_ready", False)
    a911_state = "READY" if rec_s.get("snapshot_available") and rec_s.get("workspace_integrity") else "UNVERIFIED"
    laz_state  = "SIMULATION PASS" if rec_h.get("simulation_success") else ("SIMULATION FAIL" if rec_h else "UNKNOWN")
    rec_score  = score_d.get("layer_scores", {}).get("recovery", "unknown")
    last_orp_ts = orp.get("timestamp", "never")
    last_fc    = orp.get("failure_class", "NOMINAL" if orp else "unknown")

    # Dominant status
    dom_state, dom_reason = dominant_status(
        gw, digest, builder, recovery_ready, r_alerts, score, verify_state
    )

    events = recent_events(5)

    # ── Clear and draw ────────────────────────────────────────────────────────
    print("\033[2J\033[H", end="")  # clear + home

    # Header
    print(bold("OpenClaw Observe") + " — " + cyan("Live Reliability Monitor"))
    print(dim(f"{local_ts()} | host: {hostname()} | octriage: {octriage_version()} | refresh: {interval}s"))
    print()

    # ── Fleet identity ────────────────────────────────────────────────────────
    fleet_id, node_name = fleet_identity()

    # ── Sprint 2 signals ─────────────────────────────────────────────────────
    activity_str   = agent_activity_rate()
    compact_str    = compaction_status()
    trend_str      = reliability_trend()
    detected_24h   = events_detected_24h()

    # ── Section 1: SYSTEM HEALTH ──────────────────────────────────────────────
    print(cyan("SYSTEM HEALTH"))
    print(f"fleet:      {bold(fleet_id)}")
    print(f"node:       {node_name}")
    print(f"gateway:    {colorize_state(gw)}")
    print(f"sessions:   {colorize_state(sessions_str)}")
    print(f"digest:     {colorize_state(digest)}")
    print(f"builder:    {colorize_state(builder)}")
    print(f"disk:       {colorize_state(disk)}")
    if verify_state == "MATCH":
        vline = f"{green('MATCH')} (inst={v_inst} exp={v_exp})"
    elif verify_state == "MISMATCH":
        vline = f"{red('MISMATCH')} (inst={v_inst} exp={v_exp})"
    else:
        vline = yellow(verify_state)
    print(f"verify:     {vline}")
    score_str = f"{score}/100" if score is not None else "unknown"
    score_col = green(score_str) if (score or 0) >= 85 else (yellow(score_str) if (score or 0) >= 70 else red(score_str))
    print(f"reliability:{score_col}")
    print(f"protection: {colorize_state(str(pstate))}")
    # Task 1 + Task 5
    act_col = yellow(activity_str) if "stall" in activity_str else activity_str
    print(f"activity:   {act_col}")
    comp_col = colorize_state(compact_str)
    print(f"compaction: {comp_col}")
    print()

    # ── Section 2: OBSERVE ────────────────────────────────────────────────────
    print(cyan("OBSERVE"))
    print(f"agents:            {agents_n}")
    print(f"active_sessions:   {sessions}")
    print(f"orphan_sessions:   {orphans}")
    ra_str = str(r_alerts)
    print(f"runtime_alerts:    {yellow(ra_str) if int(r_alerts or 0) > 0 else ra_str}")
    gw_str = str(gw_warn)
    print(f"gateway_warnings:  {yellow(gw_str) if int(gw_warn or 0) > 0 else gw_str}")
    pa_str = str(pred_alerts)
    print(f"predictive_alerts: {yellow(pa_str) if int(pred_alerts or 0) > 0 else pa_str}")
    print(f"reliability_score: {score_col}")
    # Task 3
    trend_col = green(trend_str) if "(+" in trend_str else (red(trend_str) if "(-" in trend_str else dim(trend_str))
    print(f"reliability_trend: {trend_col}")
    print()

    # ── Section 3: PROTECTION ─────────────────────────────────────────────────
    print(cyan("PROTECTION SUMMARY (24h)"))
    def pf(field, label):
        val = prot.get(field, "unknown")
        return f"{label}: {val}"
    print(f"events detected:   {detected_24h}")
    print(pf("memory_drift_prevented_24h", "memory drift prevented"))
    print(pf("digest_rebuilds_24h",        "digest rebuilds"))
    stalls = prot.get("stalls_detected_24h", "unknown")
    stall_str = str(stalls)
    print(f"stalls detected:   {yellow(stall_str) if stalls and int(stalls) > 0 else stall_str}")
    print(pf("recoveries_verified_24h",    "recoveries verified"))
    print(pf("recoveries_executed_24h",    "recoveries executed"))
    print(f"protection state:  {colorize_state(str(pstate))}")
    print()

    # ── Section 4: RECOVERY ───────────────────────────────────────────────────
    print(cyan("RECOVERY"))
    print(f"agent911:          {colorize_state(a911_state)}")
    print(f"lazarus:           {colorize_state(laz_state)}")
    rs_str = f"{rec_score}/25" if rec_score != "unknown" else "unknown"
    print(f"recovery score:    {rs_str}")
    print(f"last ORP run:      {last_orp_ts}")
    print(f"last failure class:{colorize_state(str(last_fc))}")
    print()

    # ── Section 5: RECENT EVENTS ──────────────────────────────────────────────
    print(cyan("RECENT EVENTS"))
    if events:
        for e in events:
            ts_short = fmt_ts_short(e.get("timestamp", ""))
            comp     = e.get("component", "?")[:12]
            etype    = e.get("event_type", "?")[:35]
            sev      = colorize_severity(e.get("severity", "info"))
            print(f"  {dim(ts_short)} | {comp:<12} | {etype:<35} | {sev}")
    else:
        print(f"  {dim('no events found')}")
    print()

    # ── Section 6: STATUS ─────────────────────────────────────────────────────
    if dom_state == "HEALTHY":
        status_line = f"STATUS: [{green(dom_state)}] ({dom_reason})"
    elif dom_state in ("DEGRADED",):
        status_line = f"STATUS: [{yellow(dom_state)}] ({dom_reason})"
    else:  # AT_RISK, FAILED
        status_line = f"STATUS: [{red(dom_state)}] ({dom_reason})"
    print(status_line)
    print(dim(f"  press Ctrl+C to exit | next refresh in {interval}s"))


def main(interval: int = 10):
    # Handle Ctrl+C cleanly
    def _exit(sig, frame):
        print("\n\033[?25h", end="")  # restore cursor
        sys.exit(0)
    signal.signal(signal.SIGINT, _exit)
    signal.signal(signal.SIGTERM, _exit)

    # Hide cursor during watch
    print("\033[?25l", end="", flush=True)

    try:
        while True:
            try:
                render(interval)
            except Exception as e:
                print(f"\033[2J\033[H{red('Render error:')} {e}")
            sys.stdout.flush()
            time.sleep(interval)
    finally:
        print("\033[?25h", end="")  # always restore cursor


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="OpenClaw Observe — Live Reliability Monitor")
    parser.add_argument("--interval", "-interval", type=int, default=10, help="Refresh interval in seconds")
    args = parser.parse_args()
    main(interval=args.interval)
