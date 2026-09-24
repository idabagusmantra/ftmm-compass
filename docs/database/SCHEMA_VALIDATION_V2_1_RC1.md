# FTMM COMPASS — V2.1 RC1 Final Release Audit

Generated: 2026-09-19T15:45:49+00:00

## Verdict

**PASS — 97/97 release checks passed.**

This report is the final static cross-check of the current package. It verifies the SQL,
DBML, design record, changelog, and the locked revision contract used for the FTMM COMPASS
database baseline.

## Object inventory
- Tables: **36**
- Foreign-key references: **70**
- Explicit indexes: **57**
- Functions: **26**
- Triggers: **44**
- Views: **2**

## Audit checks
- PASS — SQL table inventory = 36
- PASS — Locked table order/inventory exact
- PASS — DBML table inventory = 36
- PASS — SQL/DBML table sets identical
- PASS — SQL/DBML columns identical per table
- PASS — DBML groups cover all 36 tables exactly once
- PASS — All FK targets/columns valid
- PASS — All inline FK targets created before use
- PASS — No duplicate table names
- PASS — No duplicate constraint names
- PASS — No duplicate function names
- PASS — No duplicate trigger names
- PASS — No duplicate index names
- PASS — No duplicate view names
- PASS — All trigger target tables/functions valid
- PASS — All index target tables valid
- PASS — SQL dollar quote pairs balanced
- PASS — SQL contains top-level BEGIN
- PASS — SQL ends with COMMIT
- PASS — Legacy course_prerequisites removed
- PASS — Legacy minimum_grade removed
- PASS — Legacy item_status removed
- PASS — Student current semester 1–14
- PASS — Curriculum recommended semester 1–8
- PASS — Planner placement 1–14
- PASS — Minimum graduation credits
- PASS — Standard duration semesters
- PASS — Lecture credits
- PASS — Tutorial credits
- PASS — Practicum credits
- PASS — Optional workload
- PASS — Wajib konsentrasi
- PASS — Raw staging payload
- PASS — Reviewer audit
- PASS — Source checksum
- PASS — Source derivation
- PASS — Course aliases
- PASS — Dual course relation
- PASS — Choice-group credit rules
- PASS — Requirement tree
- PASS — Minimum completed SKS
- PASS — Minimum attempted SKS
- PASS — Concurrent/corequisite
- PASS — Minimum choice SKS
- PASS — One verified rule/course
- PASS — Verified rule metadata guard
- PASS — Verified tree mutation guard
- PASS — One root
- PASS — No empty all/any
- PASS — Leaf cannot have child
- PASS — Strict DAG only course_passed
- PASS — Equivalency pending nullable
- PASS — IPS inclusive min
- PASS — IPS inclusive max
- PASS — Wishlist
- PASS — Target graduation semester
- PASS — Active target not in past
- PASS — PDB eligibility
- PASS — Offering components
- PASS — Dynamic class sections
- PASS — Chat sessions
- PASS — Structured chat payload
- PASS — Dynamic timetable conflict view
- PASS — Current-assignment unique
- PASS — Active planner unique
- PASS — Active timetable/period unique
- PASS — Curriculum lifecycle sync
- PASS — Manual curriculum reason
- PASS — Switch cannot bypass initial helper
- PASS — Plan curriculum validation
- PASS — Plan later-semester parity
- PASS — Record curriculum validation
- PASS — Offering global course validation
- PASS — Offering term validation
- PASS — Timetable period validation
- PASS — Timetable curriculum eligibility
- PASS — One section/component
- PASS — Required components activation
- PASS — Active timetable immutable items
- PASS — Dual-model SQL comment
- PASS — Notifications deferred
- PASS — Official KRS enrollment deferred
- PASS — Section lecturers deferred
- PASS — Room master deferred
- PASS — Community review table deferred
- PASS — Design says 36 tables
- PASS — Design declares SQL canonical
- PASS — Design stages dirty JSON
- PASS — Design covers planner 1–14
- PASS — Design covers dual theory/practicum
- PASS — Design covers attempted SKS
- PASS — Design covers verified immutability
- PASS — Design defers MBKM/Cumlaude
- PASS — Changelog 31→36
- PASS — Changelog planner 1–14
- PASS — Changelog attempted SKS
- PASS — Changelog dual-model comment

## Errors
- None.

## Final scope statement

For the **current confirmed project scope**, no known structural/revision-contract mismatch remains.
The 36-table architecture is unchanged by final hardening. The extracted 5-program JSON stays in
staging until reconciliation/verification; it is not direct canonical seed data.

Intentionally deferred rather than forgotten: notifications, official KRS section enrollment,
actual section lecturers, room/building master, MBKM/Cumlaude persistence, community reviews,
and direct-client RLS.

## Runtime limitation

This environment has no PostgreSQL server/`psql`, so live PostgreSQL 16 execution remains the
only unperformed technical gate. Static structure and cross-file consistency are PASS; a clean
PostgreSQL 16 execution is still required before calling the schema runtime-validated/migrated.

## SHA-256 authoritative files
- `schema_v2_1_rc1.sql`: `976510618c50d5ec73f6b16a969929430c04b735c3e64b1ba0fcc2e42028d2dc`
- `schema_v2_1_rc1.dbml`: `2e7ee090b60b1904eb5b9d260f33db94935b087815cbf7db34e7fad4bfa1e924`
- `DATABASE_SCHEMA_V2_1_RC1.md`: `418cec0f27979c85d8430d5e5f6c802bb3f3799534a8c985ce556e0f1ac739fe`
- `CHANGELOG_V2_TO_V2_1_RC1.md`: `a30cc44cf103cbc7d4467a1cb3d9dffc57ae77ef4b84a5d232bf07c6e1cf57b7`
