# FTMM COMPASS — Changelog V2 → V2.1 RC1

## Replace
- `course_prerequisites` → `course_requirement_rules` + `course_requirement_nodes`

## Add tables
- `course_aliases`
- `curriculum_course_relations`
- `chat_sessions`
- `chat_messages`

Net change: 31 → 36 tables.

## Modify
- `student_profiles.current_semester`: 1–8 → 1–14
- `source_documents`: add file/checksum/version/derivation provenance
- `curricula`: add minimum graduation credits + standard duration
- `curriculum_courses`: add lecture/tutorial/practicum SKS + optional workload
- `curriculum_courses.course_type`: add `wajib_konsentrasi`
- `catalog_source_records`: raw JSON payload + extraction/source locator + reviewer audit
- `curriculum_choice_groups`: generalized to alternative/elective/concentration/religion groups,
  with both choice-count and credit requirements
- `course_equivalencies`: verifier fields nullable while pending (fixes impossible pending state)
- `academic_load_bands`: inclusive/exclusive IPS boundaries
- `degree_plans`: add target graduation semester
- `degree_plan_items`: add `planning_status = planned|wishlist`
- chat messages: structured action payload support

## Keep
- curriculum-history model
- multiple planners, max one active
- passed-based prerequisite fulfillment
- final grade for IPS/IPK only
- course vs curriculum-course normalization
- PDB/shared course offering eligibility
- dynamic class sections
- offering components
- timetable alternatives + dynamic conflict calculation
- staging/manual review before canonical import

## Do not copy from GitHub baseline
Current `RANCANGAN DIAGRAM AWAL.sql` is a 22-table historical baseline and remains superseded.

## Final release-audit fixes
- `degree_plan_items.planned_semester`: diperluas 1–14; curriculum recommended semester tetap 1–8.
- Semester parity planner sekarang menggunakan odd/even parity, sehingga semester 9–14 dapat direpresentasikan.
- Verified requirement tree dibuat immutable sampai rule dikembalikan ke `unresolved`.
- AND/OR kosong dan leaf dengan child ditolak saat requirement diverifikasi.
- Cycle detection hanya untuk strict passed-before dependency; mutual concurrent/corequisite tetap dapat direpresentasikan.
- Active cohort rules dengan priority sama tidak boleh overlap.
- Menutup current curriculum assignment otomatis mengarsipkan planner terkait dan menonaktifkan timetable terkait.
- Requirement engine membedakan `minimum_completed_sks` dan `minimum_attempted_sks`.
- Hanya satu canonical requirement rule dapat berstatus `verified` per curriculum course.
- Authoritative metadata pada verified requirement rule dikunci sampai status dikembalikan ke `unresolved`.
- Active plan target graduation semester tidak boleh lebih kecil dari current semester.
- `switch_student_curriculum()` sekarang hanya untuk switch existing assignment; initial assignment memakai helper khusus.
- SQL comment offering components diperjelas agar konsisten dengan dual theory/practicum model.
