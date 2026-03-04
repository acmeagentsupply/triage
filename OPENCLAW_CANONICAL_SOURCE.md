OPENCLAW CANONICAL SOURCE

This repository is the canonical writable source for this tool.

Rules for agents and automation:
	1.	All code changes must be made in this repository.
	2.	Vendored copies located elsewhere in the OpenClaw tree are read-only.
	3.	If multiple copies of this tool exist on disk, only the repository containing this file is authoritative.
	4.	Never modify vendored copies such as:
~/openclaw/tools/*
	5.	When committing or tagging releases, always operate from this repository root.

Purpose:

This file enables OpenClaw agents to reliably detect the correct development location for a tool and prevents accidental edits to vendored or packaged copies.

If this file is missing, assume the repository is NOT the canonical source.
