# FTMM COMPASS — Database Schema V2.1 RC1

**Status:** Final sementara / integrated baseline untuk progress saat ini.  
**Target DBMS:** PostgreSQL 16+  
**Canonical schema:** `schema_v2_1_rc1.sql`  
**Diagram review:** `schema_v2_1_rc1.dbml`

## Tujuan

V2.1 RC1 menggabungkan keputusan bisnis yang sudah dikonfirmasi, frontend FTMM COMPASS terbaru,
audit dataset mata kuliah 5 prodi (raw + extract), panduan akademik, serta audit repository GitHub.

Schema ini **tidak menganggap JSON ekstraksi sebagai data canonical**. Data ekstraksi masuk staging,
direkonsiliasi, kemudian hanya record yang sudah diverifikasi yang dipromosikan ke catalog utama.

## Inventory

Total **36 tabel**:

- Identity/Student: 3
- Curriculum History: 3
- Source/Staging: 2
- Academic Catalog: 9
- Academic Requirements: 2
- Academic Policy: 4
- Planning/Academic History: 3
- Course Delivery: 5
- Timetable: 2
- Feedback: 1
- Chat History: 2

## Keputusan yang dikunci

### User & curriculum
- Akun mahasiswa terkait satu program studi.
- `current_semester` mendukung 1–14; `curriculum_courses.recommended_semester` tetap 1–8 sebagai roadmap standar, sedangkan penempatan aktual pada Degree Planner dapat diperpanjang sampai semester 14 untuk mahasiswa terlambat/retake.
- Pergantian kurikulum disimpan sebagai history melalui `student_curriculum_assignments`.
- Planner lama diarsipkan dan tetap dapat diakses; planner baru mulai kosong.
- Banyak Degree Planner diperbolehkan, maksimal satu aktif per user.

### Catalog
- `courses` adalah identity global; SKS/semester/type ada di `curriculum_courses`.
- Shared/PDB courses tetap dapat dipakai lintas prodi melalui offering eligibility.
- Konflik kode/nama/SKS dari extraction ditahan di staging, bukan dipaksa masuk canonical catalog.
- Alias/abbreviation/typo disimpan di `course_aliases`.
- Mata kuliah resmi teori dan praktikum yang mempunyai kode berbeda tetap menjadi dua course;
  hubungan akademiknya dicatat di `curriculum_course_relations`.
- Jika satu official course memiliki teori/tutorial/praktikum sebagai komponen delivery,
  komponen tersebut ditangani oleh `offering_components`.

### Academic requirements
- Model edge sederhana `course_prerequisites` diganti dengan rule tree:
  `course_requirement_rules` + `course_requirement_nodes`.
- Mendukung AND, OR, course passed, concurrent/corequisite, minimum completed/passed SKS, minimum attempted/taken SKS,
  minimum semester, dan minimum SKS dari choice group.
- Hanya requirement berstatus `verified` yang boleh dianggap authoritative oleh validator. Tree yang sudah verified dikunci dari perubahan; untuk mengedit, status rule harus dikembalikan ke `unresolved`.
- Raw expression tetap disimpan untuk traceability.

### Academic policy
- Nilai akhir disimpan untuk IPS/IPK, bukan sebagai threshold prerequisite.
- Grade scale: A, AB, B, BC, C, D, E; D passing.
- Batas SKS berbasis IPS diversi/versioning melalui policy + band.
- Band mempunyai inclusive/exclusive boundary karena panduan antar tahun berbeda.
- `minimum_graduation_credits` tersimpan di curriculum; current FTMM S1 baseline = 144.

### Degree Planner & timetable
- `degree_plan_items` hanya rencana: `planned` / `wishlist`; `planned_semester` mendukung 1–14, sementara semester rekomendasi kurikulum tetap 1–8.
- Fakta akademik ada di `student_course_records`.
- Course opening per periode ada di `course_offerings`.
- PDB/shared offering menggunakan `course_offering_eligibilities`.
- Jumlah class section dinamis.
- Clash timetable dihitung, bukan disimpan sebagai conflict table permanen.
- User memilih mata kuliah terlebih dahulu, section setelah jadwal periode tersedia.

### Chat
- Conversation history dipersistenkan dengan `chat_sessions` dan `chat_messages`.
- `chat_messages.payload` dapat menyimpan structured action seperti `APPLY_DEGREE_PLAN`.

## Sengaja ditunda
- notification persistence
- official KRS section enrollment
- actual section-to-lecturer assignments
- room/building master
- MBKM activity model dan authoritative Cumlaude calculation
- direct-client RLS sampai deployment architecture diputuskan
- automatic course equivalency
- automatic promotion of dirty extraction data

## Import flow

`Official raw document -> source_documents -> extracted dataset -> catalog_source_records
-> reconciliation/manual review -> verified canonical catalog -> PostgreSQL-backed API`

Jangan seed lima JSON hasil ekstraksi langsung ke `courses` / `curriculum_courses`.

## Integrity rules tambahan hasil final release audit
- Untuk rule SKS, schema membedakan `minimum_completed_sks` (SKS yang sudah lulus/selesai)
  dan `minimum_attempted_sks` (SKS yang sudah ditempuh) agar frasa sumber tidak disamakan secara paksa.
- Maksimal satu requirement tree canonical berstatus `verified` per `curriculum_course`.
- Active Degree Planner dengan target kelulusan tidak boleh menarget semester yang sudah lewat dari `current_semester`.
- Strict `course_passed` dependency diperlakukan sebagai DAG dan dicegah membentuk cycle.
- `course_taken_or_concurrent` tidak dipaksa acyclic karena corequisite mutual dapat valid.
- Verified requirement tree wajib memiliki tepat satu root; operator `all/any` tidak boleh kosong; leaf tidak boleh memiliki child.
- Active cohort rules dengan priority yang sama tidak boleh overlap untuk prodi yang sama.
- Ketika curriculum assignment menjadi historical, seluruh planner terkait otomatis diarsipkan dan timetable terkait dinonaktifkan.
