-- FTMM COMPASS Database Schema V2.1 RC1 — Integrated Baseline
-- Target: PostgreSQL 16+
-- Status: final sementara / release candidate untuk current confirmed scope.
--
-- Evidence merged into this baseline:
--   * confirmed FTMM COMPASS product/business rules
--   * latest frontend behavior and Compass AI flow
--   * audit of 5-program extracted course datasets
--   * cross-check against raw curriculum/academic-guide sources
--   * GitHub repository architecture and schema review history
--
-- IMPORTANT:
--   * extracted JSON is staging input, NOT canonical seed data
--   * only verified catalog/requirement records should be promoted
--   * exact IPS rounding and retake treatment remain policy data
--   * this file is a schema baseline; run on a clean PostgreSQL 16 instance
--     and execute acceptance tests before calling it production-migrated.

BEGIN;

-- ============================================================
-- 1. MASTER / IDENTITY
-- ============================================================

CREATE TABLE users (
    user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email varchar(255) NOT NULL UNIQUE,
    full_name varchar(150) NOT NULL,
    role varchar(30) NOT NULL DEFAULT 'student',
    is_active boolean NOT NULL DEFAULT true,
    anonymized_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT users_role_check
        CHECK (role IN ('student', 'lecturer', 'faculty_staff', 'admin')),
    CONSTRAINT users_email_not_blank_check CHECK (btrim(email) <> ''),
    CONSTRAINT users_name_not_blank_check CHECK (btrim(full_name) <> '')
);

CREATE TABLE study_programs (
    study_program_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    program_code varchar(20) NOT NULL UNIQUE,
    program_name varchar(150) NOT NULL UNIQUE,
    degree_level varchar(30) NOT NULL DEFAULT 'sarjana',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT study_programs_code_not_blank_check CHECK (btrim(program_code) <> ''),
    CONSTRAINT study_programs_name_not_blank_check CHECK (btrim(program_name) <> '')
);

CREATE TABLE student_profiles (
user_id uuid PRIMARY KEY REFERENCES users(user_id) ON DELETE RESTRICT,
study_program_id uuid NOT NULL REFERENCES study_programs(study_program_id) ON DELETE RESTRICT,
student_number varchar(30) UNIQUE,
admission_year smallint NOT NULL,
current_semester smallint NOT NULL,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT student_profiles_semester_check CHECK (current_semester BETWEEN 1 AND 14),
CONSTRAINT student_profiles_admission_year_lower_check CHECK (admission_year >= 2000)
);

-- ============================================================
-- 2. SOURCE DOCUMENTS / CATALOG
-- ============================================================

CREATE TABLE source_documents (
source_document_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
document_title varchar(255) NOT NULL,
document_type varchar(50) NOT NULL,
academic_year_label varchar(30),
file_name varchar(255),
checksum_sha256 char(64),
source_version varchar(80),
source_url text,
derived_from_source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
verification_status varchar(30) NOT NULL DEFAULT 'unverified',
last_verified_at timestamptz,
verified_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
verification_notes text,
is_active boolean NOT NULL DEFAULT true,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT source_documents_type_check CHECK (
    document_type IN (
        'silabus', 'kurikulum', 'panduan_akademik', 'panduan_pkl',
        'panduan_skripsi', 'panduan_yudisium', 'jadwal_kuliah',
        'dataset_extract', 'other'
    )
),
CONSTRAINT source_documents_checksum_check CHECK (
    checksum_sha256 IS NULL OR checksum_sha256 ~ '^[0-9a-fA-F]{64}$'
),
CONSTRAINT source_documents_verification_status_check
    CHECK (verification_status IN ('unverified', 'verified', 'needs_revision')),
CONSTRAINT source_documents_verifier_pair_check CHECK (
    (last_verified_at IS NULL AND verified_by_user_id IS NULL)
    OR
    (last_verified_at IS NOT NULL AND verified_by_user_id IS NOT NULL)
),
CONSTRAINT source_documents_verified_requires_actor_check CHECK (
    verification_status <> 'verified'
    OR (last_verified_at IS NOT NULL AND verified_by_user_id IS NOT NULL)
),
CONSTRAINT source_documents_no_self_derivation_check CHECK (
    derived_from_source_document_id IS NULL
    OR derived_from_source_document_id <> source_document_id
),
CONSTRAINT source_documents_title_not_blank_check CHECK (btrim(document_title) <> '')
);

CREATE TABLE curricula (
curriculum_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
study_program_id uuid NOT NULL REFERENCES study_programs(study_program_id) ON DELETE RESTRICT,
source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
curriculum_name varchar(150) NOT NULL,
curriculum_year smallint NOT NULL,
minimum_graduation_credits smallint NOT NULL DEFAULT 144,
standard_duration_semesters smallint NOT NULL DEFAULT 8,
valid_from date,
valid_until date,
is_active boolean NOT NULL DEFAULT true,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT curricula_program_year_unique UNIQUE (study_program_id, curriculum_year),
CONSTRAINT curricula_year_check CHECK (curriculum_year BETWEEN 2000 AND 2100),
CONSTRAINT curricula_graduation_credits_check CHECK (minimum_graduation_credits BETWEEN 1 AND 300),
CONSTRAINT curricula_standard_duration_check CHECK (standard_duration_semesters BETWEEN 1 AND 14),
CONSTRAINT curricula_validity_check CHECK (
    valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from
),
CONSTRAINT curricula_name_not_blank_check CHECK (btrim(curriculum_name) <> '')
);

-- Initial/default curriculum selection by cohort. This is policy data so the
-- mapping can change without changing application code.
CREATE TABLE curriculum_cohort_rules (
    curriculum_cohort_rule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    study_program_id uuid NOT NULL REFERENCES study_programs(study_program_id) ON DELETE RESTRICT,
    curriculum_id uuid NOT NULL REFERENCES curricula(curriculum_id) ON DELETE RESTRICT,
    source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
    admission_year_from smallint NOT NULL,
    admission_year_to smallint,
    priority smallint NOT NULL DEFAULT 100,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT curriculum_cohort_rules_years_check CHECK (
        admission_year_from >= 2000
        AND (admission_year_to IS NULL OR admission_year_to >= admission_year_from)
    ),
    CONSTRAINT curriculum_cohort_rules_priority_check CHECK (priority > 0)
);

CREATE TABLE student_curriculum_assignments (
    student_curriculum_assignment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    curriculum_id uuid NOT NULL REFERENCES curricula(curriculum_id) ON DELETE RESTRICT,
    assigned_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
    assignment_source varchar(30) NOT NULL DEFAULT 'cohort_rule',
    change_reason text,
    is_current boolean NOT NULL DEFAULT true,
    effective_from timestamptz NOT NULL DEFAULT now(),
    effective_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT student_curriculum_assignments_source_check
        CHECK (assignment_source IN ('cohort_rule', 'student_change', 'admin_override', 'migration')),
    CONSTRAINT student_curriculum_assignments_dates_check
        CHECK (effective_until IS NULL OR effective_until >= effective_from),
    CONSTRAINT student_curriculum_assignments_current_end_check
        CHECK ((is_current AND effective_until IS NULL) OR (NOT is_current AND effective_until IS NOT NULL)),
    CONSTRAINT student_curriculum_assignments_reason_check CHECK (
        assignment_source NOT IN ('student_change','admin_override')
        OR (change_reason IS NOT NULL AND btrim(change_reason) <> '')
    )
);

CREATE UNIQUE INDEX student_curriculum_assignments_one_current
    ON student_curriculum_assignments (user_id)
    WHERE is_current;

CREATE TABLE courses (
    course_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_code varchar(30) NOT NULL UNIQUE,
    course_name varchar(200) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT courses_code_format_check CHECK (course_code ~ '^[A-Z]+[0-9]{3,4}$'),
    CONSTRAINT courses_name_not_blank_check CHECK (btrim(course_name) <> '')
);

CREATE TABLE course_aliases (
course_alias_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
course_id uuid NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT,
alias_text varchar(255) NOT NULL,
alias_type varchar(30) NOT NULL DEFAULT 'name',
source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
is_verified boolean NOT NULL DEFAULT false,
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT course_aliases_type_check CHECK (
    alias_type IN ('name', 'code', 'abbreviation', 'source_typo')
),
CONSTRAINT course_aliases_text_not_blank_check CHECK (btrim(alias_text) <> ''),
CONSTRAINT course_aliases_unique UNIQUE (course_id, alias_text, alias_type)
);

CREATE TABLE curriculum_courses (
curriculum_course_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
curriculum_id uuid NOT NULL REFERENCES curricula(curriculum_id) ON DELETE RESTRICT,
course_id uuid NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT,
credits_total smallint NOT NULL,
lecture_credits smallint,
tutorial_credits smallint,
practicum_credits smallint,
workload_hours_per_semester numeric(8,2),
recommended_semester smallint NOT NULL,
term varchar(20) NOT NULL,
course_type varchar(30) NOT NULL,
course_scope varchar(30) NOT NULL DEFAULT 'program_studi',
description text,
verification_status varchar(30) NOT NULL DEFAULT 'unverified',
is_active boolean NOT NULL DEFAULT true,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT curriculum_courses_curriculum_course_unique UNIQUE (curriculum_id, course_id),
CONSTRAINT curriculum_courses_credits_check CHECK (credits_total BETWEEN 1 AND 24),
CONSTRAINT curriculum_courses_component_credits_check CHECK (
    (lecture_credits IS NULL OR lecture_credits BETWEEN 0 AND 24)
    AND (tutorial_credits IS NULL OR tutorial_credits BETWEEN 0 AND 24)
    AND (practicum_credits IS NULL OR practicum_credits BETWEEN 0 AND 24)
    AND COALESCE(lecture_credits,0)
        + COALESCE(tutorial_credits,0)
        + COALESCE(practicum_credits,0) <= credits_total
),
CONSTRAINT curriculum_courses_workload_check CHECK (
    workload_hours_per_semester IS NULL OR workload_hours_per_semester > 0
),
CONSTRAINT curriculum_courses_semester_check CHECK (recommended_semester BETWEEN 1 AND 8),
CONSTRAINT curriculum_courses_term_check CHECK (term IN ('ganjil', 'genap')),
CONSTRAINT curriculum_courses_semester_term_check CHECK (
    (term = 'ganjil' AND recommended_semester IN (1,3,5,7))
    OR
    (term = 'genap' AND recommended_semester IN (2,4,6,8))
),
CONSTRAINT curriculum_courses_type_check CHECK (
    course_type IN ('wajib', 'wajib_konsentrasi', 'pilihan', 'pilihan_terbatas')
),
CONSTRAINT curriculum_courses_scope_check
    CHECK (course_scope IN ('program_studi', 'fakultas', 'universitas')),
CONSTRAINT curriculum_courses_verification_check
    CHECK (verification_status IN ('unverified', 'verified', 'needs_revision'))
);

CREATE TABLE course_learning_outcomes (
    learning_outcome_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
    outcome_order smallint NOT NULL,
    outcome_text text NOT NULL,
    CONSTRAINT course_learning_outcomes_order_check CHECK (outcome_order > 0),
    CONSTRAINT course_learning_outcomes_text_not_blank_check CHECK (btrim(outcome_text) <> ''),
    CONSTRAINT course_learning_outcomes_order_unique UNIQUE (curriculum_course_id, outcome_order)
);

CREATE TABLE course_instructor_references (
    instructor_reference_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
    source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
    instructor_name varchar(200) NOT NULL,
    instructor_role varchar(30) NOT NULL DEFAULT 'other',
    CONSTRAINT course_instructor_references_role_check
        CHECK (instructor_role IN ('pjmk', 'teaching_team', 'lecturer', 'other')),
    CONSTRAINT course_instructor_references_name_not_blank_check CHECK (btrim(instructor_name) <> '')
);

-- Staging/provenance table for extracted JSON/Excel rows. Invalid or conflicting
-- rows stay here and are never forced into the canonical course catalog.
CREATE TABLE catalog_source_records (
catalog_source_record_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
source_document_id uuid NOT NULL REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
source_record_key varchar(80) NOT NULL,
source_locator text,
extraction_version varchar(80),
raw_program_name varchar(200),
raw_course_code varchar(80),
raw_course_name varchar(255),
raw_credits varchar(30),
raw_semester varchar(30),
raw_course_type varchar(100),
raw_prerequisite_text text,
raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
import_status varchar(30) NOT NULL DEFAULT 'pending',
mapped_curriculum_course_id uuid REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
reviewed_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
reviewed_at timestamptz,
review_notes text,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT catalog_source_records_key_unique UNIQUE (source_document_id, source_record_key),
CONSTRAINT catalog_source_records_status_check CHECK (
    import_status IN ('pending', 'needs_review', 'verified', 'mapped', 'rejected')
),
CONSTRAINT catalog_source_records_review_pair_check CHECK (
    (reviewed_by_user_id IS NULL AND reviewed_at IS NULL)
    OR (reviewed_by_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
),
CONSTRAINT catalog_source_records_mapping_check CHECK (
    (import_status = 'mapped'
        AND mapped_curriculum_course_id IS NOT NULL
        AND reviewed_by_user_id IS NOT NULL
        AND reviewed_at IS NOT NULL)
    OR
    (import_status <> 'mapped' AND mapped_curriculum_course_id IS NULL)
),
CONSTRAINT catalog_source_records_final_review_check CHECK (
    import_status NOT IN ('verified','rejected')
    OR (reviewed_by_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
)
);

CREATE TABLE curriculum_course_relations (
curriculum_course_relation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
from_curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
to_curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
relation_type varchar(30) NOT NULL,
source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
verification_status varchar(30) NOT NULL DEFAULT 'unverified',
verified_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
verified_at timestamptz,
notes text,
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT curriculum_course_relations_no_self CHECK (
    from_curriculum_course_id <> to_curriculum_course_id
),
CONSTRAINT curriculum_course_relations_type_check CHECK (
    relation_type IN ('practicum_of', 'paired_with', 'continuation_of')
),
CONSTRAINT curriculum_course_relations_status_check CHECK (
    verification_status IN ('unverified', 'verified', 'rejected')
),
CONSTRAINT curriculum_course_relations_verifier_pair_check CHECK (
    (verification_status = 'unverified'
        AND verified_by_user_id IS NULL AND verified_at IS NULL)
    OR
    (verification_status IN ('verified','rejected')
        AND verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
),
CONSTRAINT curriculum_course_relations_unique UNIQUE (
    from_curriculum_course_id, to_curriculum_course_id, relation_type
)
);

CREATE TABLE curriculum_choice_groups (
curriculum_choice_group_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
curriculum_id uuid NOT NULL REFERENCES curricula(curriculum_id) ON DELETE RESTRICT,
group_code varchar(40) NOT NULL,
group_name varchar(150) NOT NULL,
group_type varchar(30) NOT NULL DEFAULT 'other',
minimum_choices smallint NOT NULL DEFAULT 0,
maximum_choices smallint,
minimum_credits smallint NOT NULL DEFAULT 0,
maximum_credits smallint,
notes text,
CONSTRAINT curriculum_choice_groups_code_unique UNIQUE (curriculum_id, group_code),
CONSTRAINT curriculum_choice_groups_type_check CHECK (
    group_type IN ('alternative', 'elective_pool', 'concentration', 'religion', 'other')
),
CONSTRAINT curriculum_choice_groups_choice_limits_check CHECK (
    minimum_choices >= 0
    AND (maximum_choices IS NULL OR maximum_choices >= minimum_choices)
),
CONSTRAINT curriculum_choice_groups_credit_limits_check CHECK (
    minimum_credits >= 0
    AND (maximum_credits IS NULL OR maximum_credits >= minimum_credits)
)
);

CREATE TABLE curriculum_choice_group_courses (
    curriculum_choice_group_id uuid NOT NULL REFERENCES curriculum_choice_groups(curriculum_choice_group_id) ON DELETE RESTRICT,
    curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
    PRIMARY KEY (curriculum_choice_group_id, curriculum_course_id)
);

CREATE TABLE course_requirement_rules (
course_requirement_rule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
catalog_source_record_id uuid REFERENCES catalog_source_records(catalog_source_record_id) ON DELETE RESTRICT,
raw_expression text NOT NULL,
verification_status varchar(30) NOT NULL DEFAULT 'unresolved',
verified_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
verified_at timestamptz,
notes text,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT course_requirement_rules_expression_not_blank CHECK (btrim(raw_expression) <> ''),
CONSTRAINT course_requirement_rules_status_check CHECK (
    verification_status IN ('unresolved', 'verified', 'rejected')
),
CONSTRAINT course_requirement_rules_verifier_pair_check CHECK (
    (verification_status = 'unresolved'
        AND verified_by_user_id IS NULL AND verified_at IS NULL)
    OR
    (verification_status IN ('verified','rejected')
        AND verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
)
);

CREATE TABLE course_requirement_nodes (
course_requirement_node_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
course_requirement_rule_id uuid NOT NULL REFERENCES course_requirement_rules(course_requirement_rule_id) ON DELETE RESTRICT,
parent_node_id uuid REFERENCES course_requirement_nodes(course_requirement_node_id) ON DELETE RESTRICT,
node_order smallint NOT NULL DEFAULT 1,
node_type varchar(40) NOT NULL,
referenced_curriculum_course_id uuid REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
referenced_choice_group_id uuid REFERENCES curriculum_choice_groups(curriculum_choice_group_id) ON DELETE RESTRICT,
threshold_value numeric(10,2),
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT course_requirement_nodes_order_check CHECK (node_order > 0),
CONSTRAINT course_requirement_nodes_type_check CHECK (
    node_type IN (
        'all', 'any',
        'course_passed', 'course_taken_or_concurrent',
        'minimum_completed_sks', 'minimum_attempted_sks', 'minimum_semester', 'minimum_choice_sks'
    )
),
CONSTRAINT course_requirement_nodes_shape_check CHECK (
    (node_type IN ('all','any')
        AND referenced_curriculum_course_id IS NULL
        AND referenced_choice_group_id IS NULL
        AND threshold_value IS NULL)
    OR
    (node_type IN ('course_passed','course_taken_or_concurrent')
        AND referenced_curriculum_course_id IS NOT NULL
        AND referenced_choice_group_id IS NULL
        AND threshold_value IS NULL)
    OR
    (node_type IN ('minimum_completed_sks','minimum_attempted_sks','minimum_semester')
        AND referenced_curriculum_course_id IS NULL
        AND referenced_choice_group_id IS NULL
        AND threshold_value IS NOT NULL
        AND threshold_value > 0)
    OR
    (node_type = 'minimum_choice_sks'
        AND referenced_curriculum_course_id IS NULL
        AND referenced_choice_group_id IS NOT NULL
        AND threshold_value IS NOT NULL
        AND threshold_value > 0)
),
CONSTRAINT course_requirement_nodes_sibling_order_unique
    UNIQUE (course_requirement_rule_id, parent_node_id, node_order)
);


-- Only explicit/verified equivalencies are stored. Changing curriculum does NOT
-- automatically copy the old planner; this table is for future/manual mapping.
CREATE TABLE course_equivalencies (
course_equivalency_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
from_curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
to_curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
equivalency_status varchar(30) NOT NULL DEFAULT 'pending',
source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
verified_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
verified_at timestamptz,
notes text,
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT course_equivalencies_pair_unique UNIQUE (
    from_curriculum_course_id, to_curriculum_course_id
),
CONSTRAINT course_equivalencies_no_self CHECK (
    from_curriculum_course_id <> to_curriculum_course_id
),
CONSTRAINT course_equivalencies_status_check CHECK (
    equivalency_status IN ('pending', 'verified', 'rejected')
),
CONSTRAINT course_equivalencies_verifier_pair_check CHECK (
    (equivalency_status = 'pending'
        AND verified_at IS NULL AND verified_by_user_id IS NULL)
    OR
    (equivalency_status IN ('verified','rejected')
        AND verified_at IS NOT NULL AND verified_by_user_id IS NOT NULL)
)
);

-- ============================================================
-- 3. ACADEMIC POLICY / GRADES
-- ============================================================

CREATE TABLE grade_scale (
    grade_label varchar(2) PRIMARY KEY,
    grade_points numeric(2,1) NOT NULL,
    is_passing boolean NOT NULL,
    CONSTRAINT grade_scale_label_check CHECK (grade_label IN ('A','AB','B','BC','C','D','E')),
    CONSTRAINT grade_scale_points_check CHECK (grade_points BETWEEN 0 AND 4)
);

INSERT INTO grade_scale (grade_label, grade_points, is_passing) VALUES
    ('A',  4.0, true),
    ('AB', 3.5, true),
    ('B',  3.0, true),
    ('BC', 2.5, true),
    ('C',  2.0, true),
    ('D',  1.0, true),
    ('E',  0.0, false);

CREATE TABLE academic_load_policies (
    academic_load_policy_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name varchar(150) NOT NULL,
    first_semester_max_credits smallint NOT NULL DEFAULT 24,
    ips_rounding_mode varchar(30),
    retake_ips_mode varchar(30),
    source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
    valid_from date,
    valid_until date,
    is_active boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT academic_load_policies_first_semester_check
        CHECK (first_semester_max_credits BETWEEN 1 AND 24),
    CONSTRAINT academic_load_policies_rounding_check
        CHECK (ips_rounding_mode IS NULL OR ips_rounding_mode IN ('none', 'floor_2dp', 'round_2dp')),
    CONSTRAINT academic_load_policies_retake_check
        CHECK (retake_ips_mode IS NULL OR retake_ips_mode IN ('all_attempts', 'latest_attempt', 'highest_attempt')),
    CONSTRAINT academic_load_policies_validity_check
        CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

CREATE TABLE academic_load_bands (
academic_load_band_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
academic_load_policy_id uuid NOT NULL REFERENCES academic_load_policies(academic_load_policy_id) ON DELETE RESTRICT,
min_ips numeric(3,2) NOT NULL,
max_ips numeric(3,2) NOT NULL,
min_inclusive boolean NOT NULL DEFAULT true,
max_inclusive boolean NOT NULL DEFAULT true,
max_credits smallint NOT NULL,
CONSTRAINT academic_load_bands_range_check CHECK (
    min_ips BETWEEN 0 AND 4
    AND max_ips BETWEEN 0 AND 4
    AND (
        max_ips > min_ips
        OR (max_ips = min_ips AND min_inclusive AND max_inclusive)
    )
),
CONSTRAINT academic_load_bands_credits_check CHECK (max_credits BETWEEN 1 AND 24),
CONSTRAINT academic_load_bands_unique UNIQUE (
    academic_load_policy_id, min_ips, max_ips, min_inclusive, max_inclusive
)
);

CREATE UNIQUE INDEX academic_load_policies_one_active
    ON academic_load_policies (is_active)
    WHERE is_active;

-- ============================================================
-- 4. ACADEMIC PERIOD / STUDY RECORDS / DEGREE PLANNER
-- ============================================================

CREATE TABLE academic_periods (
    academic_period_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    academic_year_start smallint NOT NULL,
    term varchar(20) NOT NULL,
    start_date date,
    end_date date,
    is_active boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT academic_periods_year_check CHECK (academic_year_start BETWEEN 2000 AND 2100),
    CONSTRAINT academic_periods_term_check CHECK (term IN ('ganjil', 'genap', 'pendek')),
    CONSTRAINT academic_periods_dates_check CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
    CONSTRAINT academic_periods_year_term_unique UNIQUE (academic_year_start, term)
);

CREATE TABLE degree_plans (
degree_plan_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
student_curriculum_assignment_id uuid NOT NULL REFERENCES student_curriculum_assignments(student_curriculum_assignment_id) ON DELETE RESTRICT,
plan_name varchar(100) NOT NULL DEFAULT 'Rencana Utama',
status varchar(30) NOT NULL DEFAULT 'draft',
start_academic_year smallint,
target_graduation_semester smallint,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT degree_plans_status_check CHECK (status IN ('draft', 'active', 'archived')),
CONSTRAINT degree_plans_target_check CHECK (
    target_graduation_semester IS NULL OR target_graduation_semester BETWEEN 7 AND 14
),
CONSTRAINT degree_plans_name_not_blank_check CHECK (btrim(plan_name) <> ''),
CONSTRAINT degree_plans_assignment_name_unique UNIQUE (
    student_curriculum_assignment_id, plan_name
)
);

CREATE UNIQUE INDEX degree_plans_one_active_per_user
    ON degree_plans (user_id)
    WHERE status = 'active';

CREATE TABLE degree_plan_items (
degree_plan_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
degree_plan_id uuid NOT NULL REFERENCES degree_plans(degree_plan_id) ON DELETE RESTRICT,
curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
planned_semester smallint NOT NULL,
planning_status varchar(20) NOT NULL DEFAULT 'planned',
notes text,
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT degree_plan_items_semester_check CHECK (planned_semester BETWEEN 1 AND 14),
CONSTRAINT degree_plan_items_status_check CHECK (planning_status IN ('planned', 'wishlist')),
CONSTRAINT degree_plan_items_course_unique UNIQUE (
    degree_plan_id, curriculum_course_id
)
);

CREATE TABLE student_course_records (
    student_course_record_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    student_curriculum_assignment_id uuid NOT NULL REFERENCES student_curriculum_assignments(student_curriculum_assignment_id) ON DELETE RESTRICT,
    curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
    academic_period_id uuid NOT NULL REFERENCES academic_periods(academic_period_id) ON DELETE RESTRICT,
    record_status varchar(30) NOT NULL,
    final_grade varchar(2) REFERENCES grade_scale(grade_label) ON DELETE RESTRICT,
    completed_at date,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT student_course_records_status_check
        CHECK (record_status IN ('taking', 'passed', 'failed', 'transferred')),
    CONSTRAINT student_course_records_attempt_unique
        UNIQUE (user_id, curriculum_course_id, academic_period_id)
);

-- ============================================================
-- 5. COURSE OFFERINGS / PDB / THEORY-PRACTICUM / TIMETABLE
-- ============================================================

-- One course can have multiple separate offerings in the same period.
-- Example: a shared PDB offering versus a program-specific offering.
CREATE TABLE course_offerings (
    course_offering_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    academic_period_id uuid NOT NULL REFERENCES academic_periods(academic_period_id) ON DELETE RESTRICT,
    course_id uuid NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT,
    source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
    offering_code varchar(40) NOT NULL,
    offering_scope varchar(30) NOT NULL DEFAULT 'program_studi',
    is_term_override boolean NOT NULL DEFAULT false,
    term_override_reason text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT course_offerings_scope_check
        CHECK (offering_scope IN ('program_studi', 'fakultas', 'universitas')),
    CONSTRAINT course_offerings_override_reason_check CHECK (
        (NOT is_term_override AND term_override_reason IS NULL)
        OR
        (is_term_override AND term_override_reason IS NOT NULL AND btrim(term_override_reason) <> '')
    ),
    CONSTRAINT course_offerings_period_course_code_unique
        UNIQUE (academic_period_id, course_id, offering_code)
);

-- Eligibility lets the same actual offering/class be visible to multiple FTMM
-- curricula (PDB/shared course). External-faculty participants do not need to be
-- modeled just to make FTMM eligibility work.
CREATE TABLE course_offering_eligibilities (
    course_offering_id uuid NOT NULL REFERENCES course_offerings(course_offering_id) ON DELETE RESTRICT,
    curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
    PRIMARY KEY (course_offering_id, curriculum_course_id)
);

-- For an official course whose theory/tutorial/practicum are delivery components
-- of ONE canonical course, components can have independent selectable sections/schedules.
-- If theory/practicum are separate official course codes, keep them as separate
-- curriculum_courses and relate them through curriculum_course_relations instead.
CREATE TABLE offering_components (
    offering_component_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_offering_id uuid NOT NULL REFERENCES course_offerings(course_offering_id) ON DELETE RESTRICT,
    component_code varchar(30) NOT NULL,
    component_type varchar(30) NOT NULL,
    component_name varchar(100),
    is_required boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT offering_components_type_check
        CHECK (component_type IN ('lecture', 'practicum', 'tutorial', 'other')),
    CONSTRAINT offering_components_code_unique UNIQUE (course_offering_id, component_code),
    CONSTRAINT offering_components_code_not_blank_check CHECK (btrim(component_code) <> '')
);

-- Number of classes is intentionally unbounded by schema: one course may have
-- 1 class in a low-demand period and 3-4+ in a high-demand period.
CREATE TABLE class_sections (
    class_section_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_component_id uuid NOT NULL REFERENCES offering_components(offering_component_id) ON DELETE RESTRICT,
    section_code varchar(30) NOT NULL,
    capacity smallint,
    enrollment_status varchar(30) NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT class_sections_capacity_check CHECK (capacity IS NULL OR capacity > 0),
    CONSTRAINT class_sections_status_check CHECK (enrollment_status IN ('planned', 'open', 'closed', 'cancelled')),
    CONSTRAINT class_sections_component_code_unique UNIQUE (offering_component_id, section_code),
    CONSTRAINT class_sections_code_not_blank_check CHECK (btrim(section_code) <> '')
);

CREATE TABLE class_schedules (
    class_schedule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    class_section_id uuid NOT NULL REFERENCES class_sections(class_section_id) ON DELETE RESTRICT,
    source_document_id uuid REFERENCES source_documents(source_document_id) ON DELETE RESTRICT,
    day_of_week smallint NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    room_name varchar(100),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT class_schedules_day_check CHECK (day_of_week BETWEEN 1 AND 5),
    CONSTRAINT class_schedules_time_check CHECK (
        start_time >= TIME '07:00'
        AND end_time <= TIME '17:00'
        AND end_time > start_time
    ),
    CONSTRAINT class_schedules_slot_unique UNIQUE (class_section_id, day_of_week, start_time, end_time)
);

CREATE TABLE timetables (
    timetable_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    student_curriculum_assignment_id uuid NOT NULL REFERENCES student_curriculum_assignments(student_curriculum_assignment_id) ON DELETE RESTRICT,
    academic_period_id uuid NOT NULL REFERENCES academic_periods(academic_period_id) ON DELETE RESTRICT,
    timetable_name varchar(100) NOT NULL DEFAULT 'Jadwal Utama',
    is_active boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT timetables_name_not_blank_check CHECK (btrim(timetable_name) <> ''),
    CONSTRAINT timetables_assignment_period_name_unique UNIQUE (student_curriculum_assignment_id, academic_period_id, timetable_name)
);

CREATE UNIQUE INDEX timetables_one_active_per_period
    ON timetables (user_id, academic_period_id)
    WHERE is_active;

CREATE TABLE timetable_items (
    timetable_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    timetable_id uuid NOT NULL REFERENCES timetables(timetable_id) ON DELETE RESTRICT,
    class_section_id uuid NOT NULL REFERENCES class_sections(class_section_id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT timetable_items_section_unique UNIQUE (timetable_id, class_section_id)
);

-- ============================================================
-- 6. CHAT / COMPASS AI HISTORY
-- ============================================================

CREATE TABLE chat_sessions (
chat_session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
title varchar(200),
is_archived boolean NOT NULL DEFAULT false,
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE chat_messages (
chat_message_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
chat_session_id uuid NOT NULL REFERENCES chat_sessions(chat_session_id) ON DELETE RESTRICT,
sender_role varchar(20) NOT NULL,
message_type varchar(30) NOT NULL DEFAULT 'text',
message_text text,
action_type varchar(60),
payload jsonb,
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT chat_messages_sender_check CHECK (
    sender_role IN ('user', 'assistant', 'system', 'tool')
),
CONSTRAINT chat_messages_type_check CHECK (
    message_type IN ('text', 'action', 'tool_result', 'system')
),
CONSTRAINT chat_messages_content_check CHECK (
    message_text IS NOT NULL OR payload IS NOT NULL
)
);

-- ============================================================
-- 7. FEEDBACK
-- ============================================================

CREATE TABLE course_reports (
    course_report_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    curriculum_course_id uuid NOT NULL REFERENCES curriculum_courses(curriculum_course_id) ON DELETE RESTRICT,
    report_type varchar(50) NOT NULL,
    description text NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'submitted',
    resolved_by_user_id uuid REFERENCES users(user_id) ON DELETE RESTRICT,
    resolution_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT course_reports_type_check CHECK (
        report_type IN ('wrong_description', 'wrong_credit', 'wrong_prerequisite', 'wrong_semester', 'other')
    ),
    CONSTRAINT course_reports_status_check CHECK (status IN ('submitted', 'reviewing', 'resolved', 'rejected')),
    CONSTRAINT course_reports_description_not_blank_check CHECK (btrim(description) <> ''),
    CONSTRAINT course_reports_resolution_check CHECK (
        (status IN ('resolved','rejected') AND resolved_by_user_id IS NOT NULL AND resolved_at IS NOT NULL)
        OR
        (status IN ('submitted','reviewing') AND resolved_by_user_id IS NULL AND resolved_at IS NULL)
    )
);

-- ============================================================
-- 8. FK-SIDE / QUERY INDEXES
-- ============================================================

CREATE INDEX idx_student_profiles_study_program_id ON student_profiles(study_program_id);
CREATE INDEX idx_source_documents_verified_by_user_id ON source_documents(verified_by_user_id);
CREATE INDEX idx_source_documents_derived_from ON source_documents(derived_from_source_document_id);
CREATE INDEX idx_curricula_study_program_id ON curricula(study_program_id);
CREATE INDEX idx_curricula_source_document_id ON curricula(source_document_id);
CREATE INDEX idx_curriculum_cohort_rules_program_years
    ON curriculum_cohort_rules(study_program_id, admission_year_from, admission_year_to);
CREATE INDEX idx_curriculum_cohort_rules_curriculum_id ON curriculum_cohort_rules(curriculum_id);
CREATE INDEX idx_student_curriculum_assignments_curriculum_id ON student_curriculum_assignments(curriculum_id);
CREATE INDEX idx_student_curriculum_assignments_assigned_by ON student_curriculum_assignments(assigned_by_user_id);

CREATE INDEX idx_course_aliases_course_id ON course_aliases(course_id);
CREATE INDEX idx_course_aliases_alias_text_lower ON course_aliases(lower(alias_text));
CREATE INDEX idx_curriculum_courses_course_id ON curriculum_courses(course_id);
CREATE INDEX idx_curriculum_courses_curriculum_semester
    ON curriculum_courses(curriculum_id, recommended_semester);
CREATE INDEX idx_course_learning_outcomes_curriculum_course_id
    ON course_learning_outcomes(curriculum_course_id);
CREATE INDEX idx_course_instructor_refs_curriculum_course_id
    ON course_instructor_references(curriculum_course_id);
CREATE INDEX idx_course_instructor_refs_source_document_id
    ON course_instructor_references(source_document_id);
CREATE INDEX idx_catalog_source_records_source_status
    ON catalog_source_records(source_document_id, import_status);
CREATE INDEX idx_catalog_source_records_mapped_course_id
    ON catalog_source_records(mapped_curriculum_course_id);
CREATE INDEX idx_catalog_source_records_reviewer
    ON catalog_source_records(reviewed_by_user_id);

CREATE INDEX idx_curriculum_course_relations_from
    ON curriculum_course_relations(from_curriculum_course_id);
CREATE INDEX idx_curriculum_course_relations_to
    ON curriculum_course_relations(to_curriculum_course_id);
CREATE INDEX idx_curriculum_choice_groups_curriculum_id
    ON curriculum_choice_groups(curriculum_id);
CREATE INDEX idx_curriculum_choice_group_courses_course_id
    ON curriculum_choice_group_courses(curriculum_course_id);
CREATE INDEX idx_course_requirement_rules_course_status
    ON course_requirement_rules(curriculum_course_id, verification_status);
CREATE INDEX idx_course_requirement_rules_source_record
    ON course_requirement_rules(catalog_source_record_id);
CREATE INDEX idx_course_requirement_nodes_rule_parent
    ON course_requirement_nodes(course_requirement_rule_id, parent_node_id, node_order);
CREATE INDEX idx_course_requirement_nodes_course_ref
    ON course_requirement_nodes(referenced_curriculum_course_id);
CREATE INDEX idx_course_requirement_nodes_choice_group_ref
    ON course_requirement_nodes(referenced_choice_group_id);
CREATE UNIQUE INDEX course_requirement_rules_one_verified_per_course
    ON course_requirement_rules(curriculum_course_id)
    WHERE verification_status = 'verified';

CREATE UNIQUE INDEX course_requirement_nodes_one_root_per_rule
    ON course_requirement_nodes(course_requirement_rule_id)
    WHERE parent_node_id IS NULL;

CREATE INDEX idx_course_equivalencies_from_id ON course_equivalencies(from_curriculum_course_id);
CREATE INDEX idx_course_equivalencies_to_id ON course_equivalencies(to_curriculum_course_id);
CREATE INDEX idx_academic_load_bands_policy_id ON academic_load_bands(academic_load_policy_id);

CREATE INDEX idx_degree_plans_assignment_id ON degree_plans(student_curriculum_assignment_id);
CREATE INDEX idx_degree_plan_items_plan_semester
    ON degree_plan_items(degree_plan_id, planned_semester);
CREATE INDEX idx_degree_plan_items_course_id ON degree_plan_items(curriculum_course_id);
CREATE INDEX idx_student_course_records_user_period
    ON student_course_records(user_id, academic_period_id);
CREATE INDEX idx_student_course_records_assignment_id
    ON student_course_records(student_curriculum_assignment_id);
CREATE INDEX idx_student_course_records_course_id
    ON student_course_records(curriculum_course_id);

CREATE INDEX idx_course_offerings_period_id ON course_offerings(academic_period_id);
CREATE INDEX idx_course_offerings_course_id ON course_offerings(course_id);
CREATE INDEX idx_course_offering_eligibilities_course_id
    ON course_offering_eligibilities(curriculum_course_id);
CREATE INDEX idx_offering_components_offering_id ON offering_components(course_offering_id);
CREATE INDEX idx_class_sections_component_id ON class_sections(offering_component_id);
CREATE INDEX idx_class_schedules_section_id ON class_schedules(class_section_id);
CREATE INDEX idx_timetables_assignment_id ON timetables(student_curriculum_assignment_id);
CREATE INDEX idx_timetables_period_id ON timetables(academic_period_id);
CREATE INDEX idx_timetable_items_section_id ON timetable_items(class_section_id);

CREATE INDEX idx_course_reports_user_id ON course_reports(user_id);
CREATE INDEX idx_course_reports_curriculum_course_id ON course_reports(curriculum_course_id);
CREATE INDEX idx_course_reports_status ON course_reports(status);
CREATE INDEX idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX idx_chat_messages_session_created
    ON chat_messages(chat_session_id, created_at);

-- ============================================================
-- 9. GENERIC UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_touch_updated_at
BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_student_profiles_touch_updated_at
BEFORE UPDATE ON student_profiles FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_source_documents_touch_updated_at
BEFORE UPDATE ON source_documents FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_curricula_touch_updated_at
BEFORE UPDATE ON curricula FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_courses_touch_updated_at
BEFORE UPDATE ON courses FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_curriculum_courses_touch_updated_at
BEFORE UPDATE ON curriculum_courses FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_catalog_source_records_touch_updated_at
BEFORE UPDATE ON catalog_source_records FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_course_requirement_rules_touch_updated_at
BEFORE UPDATE ON course_requirement_rules FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_academic_load_policies_touch_updated_at
BEFORE UPDATE ON academic_load_policies FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_degree_plans_touch_updated_at
BEFORE UPDATE ON degree_plans FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_student_course_records_touch_updated_at
BEFORE UPDATE ON student_course_records FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_course_offerings_touch_updated_at
BEFORE UPDATE ON course_offerings FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_class_sections_touch_updated_at
BEFORE UPDATE ON class_sections FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_class_schedules_touch_updated_at
BEFORE UPDATE ON class_schedules FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_timetables_touch_updated_at
BEFORE UPDATE ON timetables FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_chat_sessions_touch_updated_at
BEFORE UPDATE ON chat_sessions FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE OR REPLACE FUNCTION validate_staff_actor_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor_text text;
    v_actor_id uuid;
    v_role varchar(30);
    v_active boolean;
BEGIN
    v_actor_text := to_jsonb(NEW) ->> TG_ARGV[0];
    IF v_actor_text IS NULL OR v_actor_text = '' THEN
        RETURN NEW;
    END IF;

    v_actor_id := v_actor_text::uuid;
    SELECT role, is_active INTO v_role, v_active FROM users WHERE user_id = v_actor_id;

    IF v_role IS NULL OR NOT v_active OR v_role NOT IN ('lecturer','faculty_staff','admin') THEN
        RAISE EXCEPTION '% must reference an active lecturer/faculty_staff/admin user', TG_ARGV[0];
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_source_documents_validate_verifier_role
BEFORE INSERT OR UPDATE OF verified_by_user_id ON source_documents
FOR EACH ROW EXECUTE FUNCTION validate_staff_actor_column('verified_by_user_id');

CREATE TRIGGER trg_catalog_source_records_validate_reviewer_role
BEFORE INSERT OR UPDATE OF reviewed_by_user_id ON catalog_source_records
FOR EACH ROW EXECUTE FUNCTION validate_staff_actor_column('reviewed_by_user_id');

CREATE TRIGGER trg_curriculum_course_relations_validate_verifier_role
BEFORE INSERT OR UPDATE OF verified_by_user_id ON curriculum_course_relations
FOR EACH ROW EXECUTE FUNCTION validate_staff_actor_column('verified_by_user_id');

CREATE TRIGGER trg_course_requirement_rules_validate_verifier_role
BEFORE INSERT OR UPDATE OF verified_by_user_id ON course_requirement_rules
FOR EACH ROW EXECUTE FUNCTION validate_staff_actor_column('verified_by_user_id');

CREATE TRIGGER trg_course_equivalencies_validate_verifier_role
BEFORE INSERT OR UPDATE OF verified_by_user_id ON course_equivalencies
FOR EACH ROW EXECUTE FUNCTION validate_staff_actor_column('verified_by_user_id');

CREATE TRIGGER trg_course_reports_validate_resolver_role
BEFORE INSERT OR UPDATE OF resolved_by_user_id ON course_reports
FOR EACH ROW EXECUTE FUNCTION validate_staff_actor_column('resolved_by_user_id');

-- ============================================================
-- 10. CROSS-TABLE VALIDATION TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION guard_user_role_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.role = 'student' AND NEW.role <> 'student'
       AND EXISTS (SELECT 1 FROM student_profiles WHERE user_id = NEW.user_id) THEN
        RAISE EXCEPTION 'cannot change a user away from student role while a student profile exists';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_guard_role_change
BEFORE UPDATE OF role ON users
FOR EACH ROW EXECUTE FUNCTION guard_user_role_change();

CREATE OR REPLACE FUNCTION validate_student_profile_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_role varchar(30);
BEGIN
    SELECT role INTO v_role FROM users WHERE user_id = NEW.user_id;
    IF v_role IS NULL OR v_role <> 'student' THEN
        RAISE EXCEPTION 'student_profiles can only reference users with role=student';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_student_profiles_validate_role
BEFORE INSERT OR UPDATE OF user_id ON student_profiles
FOR EACH ROW EXECUTE FUNCTION validate_student_profile_role();

CREATE OR REPLACE FUNCTION validate_student_profile_admission_year()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.admission_year > EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
        RAISE EXCEPTION 'admission_year (%) cannot be later than the current year', NEW.admission_year;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_student_profiles_validate_admission_year
BEFORE INSERT OR UPDATE OF admission_year ON student_profiles
FOR EACH ROW EXECUTE FUNCTION validate_student_profile_admission_year();

CREATE OR REPLACE FUNCTION validate_curriculum_cohort_rule_program()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_program uuid;
BEGIN
    SELECT study_program_id INTO v_program FROM curricula WHERE curriculum_id = NEW.curriculum_id;
    IF v_program IS NULL OR v_program <> NEW.study_program_id THEN
        RAISE EXCEPTION 'curriculum cohort rule curriculum must belong to the same study program';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_curriculum_cohort_rules_validate_program
BEFORE INSERT OR UPDATE ON curriculum_cohort_rules
FOR EACH ROW EXECUTE FUNCTION validate_curriculum_cohort_rule_program();


CREATE OR REPLACE FUNCTION validate_curriculum_cohort_rule_overlap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_overlap boolean;
BEGIN
    IF NEW.is_active THEN
        SELECT EXISTS (
            SELECT 1
            FROM curriculum_cohort_rules r
            WHERE r.curriculum_cohort_rule_id <> NEW.curriculum_cohort_rule_id
              AND r.study_program_id = NEW.study_program_id
              AND r.priority = NEW.priority
              AND r.is_active
              AND NEW.admission_year_from <= COALESCE(r.admission_year_to, 32767)
              AND r.admission_year_from <= COALESCE(NEW.admission_year_to, 32767)
        ) INTO v_overlap;

        IF v_overlap THEN
            RAISE EXCEPTION
                'active cohort rules with the same priority may not overlap for one study program';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_curriculum_cohort_rules_validate_overlap
BEFORE INSERT OR UPDATE ON curriculum_cohort_rules
FOR EACH ROW EXECUTE FUNCTION validate_curriculum_cohort_rule_overlap();

CREATE OR REPLACE FUNCTION validate_student_curriculum_assignment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_profile_program uuid;
    v_curriculum_program uuid;
BEGIN
    SELECT study_program_id INTO v_profile_program FROM student_profiles WHERE user_id = NEW.user_id;
    IF v_profile_program IS NULL THEN
        RAISE EXCEPTION 'student profile does not exist for user %', NEW.user_id;
    END IF;

    SELECT study_program_id INTO v_curriculum_program FROM curricula WHERE curriculum_id = NEW.curriculum_id;
    IF v_curriculum_program IS NULL OR v_profile_program <> v_curriculum_program THEN
        RAISE EXCEPTION 'assigned curriculum must belong to the student profile study program';
    END IF;

    IF NEW.assignment_source = 'student_change' AND NEW.assigned_by_user_id IS DISTINCT FROM NEW.user_id THEN
        RAISE EXCEPTION 'student_change must be initiated by the same user';
    END IF;

    IF NEW.assignment_source = 'admin_override' THEN
        IF NEW.assigned_by_user_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM users u
            WHERE u.user_id = NEW.assigned_by_user_id
              AND u.role IN ('faculty_staff','admin')
              AND u.is_active
        ) THEN
            RAISE EXCEPTION 'admin_override requires an active faculty_staff/admin actor';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_student_curriculum_assignments_validate
BEFORE INSERT OR UPDATE ON student_curriculum_assignments
FOR EACH ROW EXECUTE FUNCTION validate_student_curriculum_assignment();


CREATE OR REPLACE FUNCTION sync_curriculum_assignment_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.is_current AND NOT NEW.is_current THEN
        UPDATE degree_plans
        SET status = 'archived'
        WHERE student_curriculum_assignment_id = NEW.student_curriculum_assignment_id
          AND status <> 'archived';

        UPDATE timetables
        SET is_active = false
        WHERE student_curriculum_assignment_id = NEW.student_curriculum_assignment_id
          AND is_active;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_student_curriculum_assignments_sync_lifecycle
AFTER UPDATE OF is_current ON student_curriculum_assignments
FOR EACH ROW
WHEN (OLD.is_current AND NOT NEW.is_current)
EXECUTE FUNCTION sync_curriculum_assignment_lifecycle();

CREATE OR REPLACE FUNCTION validate_choice_group_membership()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_group_curriculum uuid;
    v_course_curriculum uuid;
BEGIN
    SELECT curriculum_id INTO v_group_curriculum
    FROM curriculum_choice_groups WHERE curriculum_choice_group_id = NEW.curriculum_choice_group_id;

    SELECT curriculum_id INTO v_course_curriculum
    FROM curriculum_courses WHERE curriculum_course_id = NEW.curriculum_course_id;

    IF v_group_curriculum IS NULL OR v_course_curriculum IS NULL OR v_group_curriculum <> v_course_curriculum THEN
        RAISE EXCEPTION 'choice-group course must belong to the same curriculum as its group';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_curriculum_choice_group_courses_validate
BEFORE INSERT OR UPDATE ON curriculum_choice_group_courses
FOR EACH ROW EXECUTE FUNCTION validate_choice_group_membership();

CREATE OR REPLACE FUNCTION validate_curriculum_course_relation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_curriculum uuid;
    v_to_curriculum uuid;
BEGIN
    SELECT curriculum_id INTO v_from_curriculum
    FROM curriculum_courses WHERE curriculum_course_id = NEW.from_curriculum_course_id;

    SELECT curriculum_id INTO v_to_curriculum
    FROM curriculum_courses WHERE curriculum_course_id = NEW.to_curriculum_course_id;

    IF v_from_curriculum IS NULL OR v_to_curriculum IS NULL
       OR v_from_curriculum <> v_to_curriculum THEN
        RAISE EXCEPTION 'curriculum-course relations must stay within one curriculum';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_curriculum_course_relations_validate
BEFORE INSERT OR UPDATE ON curriculum_course_relations
FOR EACH ROW EXECUTE FUNCTION validate_curriculum_course_relation();



CREATE OR REPLACE FUNCTION guard_verified_requirement_rule_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.verification_status = 'verified'
       AND NEW.verification_status = 'verified'
       AND (
            NEW.curriculum_course_id IS DISTINCT FROM OLD.curriculum_course_id
            OR NEW.catalog_source_record_id IS DISTINCT FROM OLD.catalog_source_record_id
            OR NEW.raw_expression IS DISTINCT FROM OLD.raw_expression
       ) THEN
        RAISE EXCEPTION
            'verified requirement rule metadata is immutable; set the rule back to unresolved before changing authoritative fields';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_course_requirement_rules_guard_verified
BEFORE UPDATE ON course_requirement_rules
FOR EACH ROW EXECUTE FUNCTION guard_verified_requirement_rule_mutation();

CREATE OR REPLACE FUNCTION guard_verified_requirement_node_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_rule_id uuid;
    v_status varchar(30);
BEGIN
    v_rule_id := CASE
        WHEN TG_OP = 'DELETE' THEN OLD.course_requirement_rule_id
        ELSE NEW.course_requirement_rule_id
    END;

    SELECT verification_status INTO v_status
    FROM course_requirement_rules
    WHERE course_requirement_rule_id = v_rule_id;

    IF v_status = 'verified' THEN
        RAISE EXCEPTION
            'verified requirement nodes are immutable; set the rule back to unresolved before editing its tree';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_course_requirement_nodes_guard_verified
BEFORE INSERT OR UPDATE OR DELETE ON course_requirement_nodes
FOR EACH ROW EXECUTE FUNCTION guard_verified_requirement_node_mutation();

CREATE OR REPLACE FUNCTION validate_requirement_node()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_target_curriculum uuid;
    v_ref_curriculum uuid;
    v_group_curriculum uuid;
    v_parent_rule uuid;
    v_cycle boolean;
BEGIN
    SELECT cc.curriculum_id
    INTO v_target_curriculum
    FROM course_requirement_rules crr
    JOIN curriculum_courses cc
      ON cc.curriculum_course_id = crr.curriculum_course_id
    WHERE crr.course_requirement_rule_id = NEW.course_requirement_rule_id;

    IF NEW.parent_node_id IS NOT NULL THEN
        IF NEW.parent_node_id = NEW.course_requirement_node_id THEN
            RAISE EXCEPTION 'requirement node cannot be its own parent';
        END IF;

        SELECT course_requirement_rule_id INTO v_parent_rule
        FROM course_requirement_nodes
        WHERE course_requirement_node_id = NEW.parent_node_id;

        IF v_parent_rule IS NULL OR v_parent_rule <> NEW.course_requirement_rule_id THEN
            RAISE EXCEPTION 'requirement parent node must belong to the same rule';
        END IF;

        WITH RECURSIVE parents(node_id) AS (
            SELECT parent_node_id
            FROM course_requirement_nodes
            WHERE course_requirement_node_id = NEW.parent_node_id
            UNION ALL
            SELECT n.parent_node_id
            FROM course_requirement_nodes n
            JOIN parents p ON n.course_requirement_node_id = p.node_id
            WHERE p.node_id IS NOT NULL
        )
        SELECT EXISTS (
            SELECT 1 FROM parents
            WHERE node_id = NEW.course_requirement_node_id
        ) INTO v_cycle;

        IF v_cycle THEN
            RAISE EXCEPTION 'requirement-node hierarchy would create a cycle';
        END IF;
    END IF;

    IF NEW.referenced_curriculum_course_id IS NOT NULL THEN
        SELECT curriculum_id INTO v_ref_curriculum
        FROM curriculum_courses
        WHERE curriculum_course_id = NEW.referenced_curriculum_course_id;

        IF v_ref_curriculum IS NULL OR v_ref_curriculum <> v_target_curriculum THEN
            RAISE EXCEPTION 'course requirement reference must stay within the target curriculum';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM course_requirement_rules r
            WHERE r.course_requirement_rule_id = NEW.course_requirement_rule_id
              AND r.curriculum_course_id = NEW.referenced_curriculum_course_id
        ) THEN
            RAISE EXCEPTION 'a course cannot require itself';
        END IF;
    END IF;

    IF NEW.referenced_choice_group_id IS NOT NULL THEN
        SELECT curriculum_id INTO v_group_curriculum
        FROM curriculum_choice_groups
        WHERE curriculum_choice_group_id = NEW.referenced_choice_group_id;

        IF v_group_curriculum IS NULL OR v_group_curriculum <> v_target_curriculum THEN
            RAISE EXCEPTION 'choice-group requirement must stay within the target curriculum';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_course_requirement_nodes_validate
BEFORE INSERT OR UPDATE ON course_requirement_nodes
FOR EACH ROW EXECUTE FUNCTION validate_requirement_node();

CREATE OR REPLACE FUNCTION validate_requirement_rule_verification()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_root_count integer;
    v_cycle_exists boolean;
BEGIN
    IF NEW.verification_status = 'verified' THEN
        SELECT count(*) INTO v_root_count
        FROM course_requirement_nodes
        WHERE course_requirement_rule_id = NEW.course_requirement_rule_id
          AND parent_node_id IS NULL;

        IF v_root_count <> 1 THEN
            RAISE EXCEPTION 'verified requirement rule must have exactly one root node';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM course_requirement_nodes n
            WHERE n.course_requirement_rule_id = NEW.course_requirement_rule_id
              AND n.node_type IN ('all','any')
              AND NOT EXISTS (
                  SELECT 1
                  FROM course_requirement_nodes child
                  WHERE child.parent_node_id = n.course_requirement_node_id
              )
        ) THEN
            RAISE EXCEPTION 'verified requirement rule cannot contain an empty all/any operator';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM course_requirement_nodes n
            WHERE n.course_requirement_rule_id = NEW.course_requirement_rule_id
              AND n.node_type NOT IN ('all','any')
              AND EXISTS (
                  SELECT 1
                  FROM course_requirement_nodes child
                  WHERE child.parent_node_id = n.course_requirement_node_id
              )
        ) THEN
            RAISE EXCEPTION 'leaf requirement nodes cannot have child nodes';
        END IF;

        -- Check strict passed-before course cycles across verified rules, treating the rule
        -- currently being verified as part of the edge set.
        WITH RECURSIVE edges AS (
            SELECT r.curriculum_course_id AS from_course,
                   n.referenced_curriculum_course_id AS to_course
            FROM course_requirement_rules r
            JOIN course_requirement_nodes n
              ON n.course_requirement_rule_id = r.course_requirement_rule_id
            WHERE n.node_type = 'course_passed'
              AND n.referenced_curriculum_course_id IS NOT NULL
              AND (
                    r.verification_status = 'verified'
                    OR r.course_requirement_rule_id = NEW.course_requirement_rule_id
                  )
        ),
        reachable(course_id) AS (
            SELECT e.to_course
            FROM edges e
            WHERE e.from_course = NEW.curriculum_course_id
            UNION
            SELECT e.to_course
            FROM edges e
            JOIN reachable r ON e.from_course = r.course_id
        )
        SELECT EXISTS (
            SELECT 1 FROM reachable
            WHERE course_id = NEW.curriculum_course_id
        ) INTO v_cycle_exists;

        IF v_cycle_exists THEN
            RAISE EXCEPTION 'verified course requirements would create a prerequisite cycle';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_course_requirement_rules_validate
BEFORE INSERT OR UPDATE ON course_requirement_rules
FOR EACH ROW EXECUTE FUNCTION validate_requirement_rule_verification();

CREATE OR REPLACE FUNCTION validate_course_equivalency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_program uuid;
    v_to_program uuid;
BEGIN
    SELECT c.study_program_id INTO v_from_program
    FROM curriculum_courses cc
    JOIN curricula c ON c.curriculum_id = cc.curriculum_id
    WHERE cc.curriculum_course_id = NEW.from_curriculum_course_id;

    SELECT c.study_program_id INTO v_to_program
    FROM curriculum_courses cc
    JOIN curricula c ON c.curriculum_id = cc.curriculum_id
    WHERE cc.curriculum_course_id = NEW.to_curriculum_course_id;

    IF v_from_program IS NULL OR v_to_program IS NULL OR v_from_program <> v_to_program THEN
        RAISE EXCEPTION 'course equivalency must stay within the same study program';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_course_equivalencies_validate
BEFORE INSERT OR UPDATE ON course_equivalencies
FOR EACH ROW EXECUTE FUNCTION validate_course_equivalency();

CREATE OR REPLACE FUNCTION validate_academic_load_band()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_overlap boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM academic_load_bands alb
        WHERE alb.academic_load_policy_id = NEW.academic_load_policy_id
          AND alb.academic_load_band_id <> NEW.academic_load_band_id
          AND (
            NEW.min_ips < alb.max_ips
            OR (NEW.min_ips = alb.max_ips AND NEW.min_inclusive AND alb.max_inclusive)
          )
          AND (
            alb.min_ips < NEW.max_ips
            OR (alb.min_ips = NEW.max_ips AND alb.min_inclusive AND NEW.max_inclusive)
          )
    ) INTO v_overlap;

    IF v_overlap THEN
        RAISE EXCEPTION 'academic load IPS bands may not overlap within one policy';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_academic_load_bands_validate
BEFORE INSERT OR UPDATE ON academic_load_bands
FOR EACH ROW EXECUTE FUNCTION validate_academic_load_band();

CREATE OR REPLACE FUNCTION validate_degree_plan()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_assignment_user uuid;
    v_assignment_current boolean;
    v_current_semester smallint;
BEGIN
    SELECT user_id, is_current
    INTO v_assignment_user, v_assignment_current
    FROM student_curriculum_assignments
    WHERE student_curriculum_assignment_id = NEW.student_curriculum_assignment_id;

    IF v_assignment_user IS NULL OR v_assignment_user <> NEW.user_id THEN
        RAISE EXCEPTION 'degree plan curriculum assignment must belong to the plan user';
    END IF;

    IF NEW.status = 'active' AND NOT v_assignment_current THEN
        RAISE EXCEPTION 'an active degree plan must use the current curriculum assignment';
    END IF;

    IF NEW.status = 'active' AND NEW.target_graduation_semester IS NOT NULL THEN
        SELECT current_semester INTO v_current_semester
        FROM student_profiles
        WHERE user_id = NEW.user_id;

        IF v_current_semester IS NOT NULL
           AND NEW.target_graduation_semester < v_current_semester THEN
            RAISE EXCEPTION
                'active degree plan target graduation semester cannot be earlier than the student current semester';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_degree_plans_validate
BEFORE INSERT OR UPDATE ON degree_plans
FOR EACH ROW EXECUTE FUNCTION validate_degree_plan();

CREATE OR REPLACE FUNCTION validate_degree_plan_item()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_plan_curriculum uuid;
    v_course_curriculum uuid;
    v_term varchar(20);
BEGIN
    SELECT sca.curriculum_id
    INTO v_plan_curriculum
    FROM degree_plans dp
    JOIN student_curriculum_assignments sca
      ON sca.student_curriculum_assignment_id = dp.student_curriculum_assignment_id
    WHERE dp.degree_plan_id = NEW.degree_plan_id;

    SELECT curriculum_id, term
    INTO v_course_curriculum, v_term
    FROM curriculum_courses
    WHERE curriculum_course_id = NEW.curriculum_course_id;

    IF v_plan_curriculum IS NULL OR v_course_curriculum IS NULL OR v_plan_curriculum <> v_course_curriculum THEN
        RAISE EXCEPTION 'degree plan item must belong to the degree plan curriculum';
    END IF;

    IF (v_term = 'ganjil' AND NEW.planned_semester % 2 <> 1)
       OR (v_term = 'genap' AND NEW.planned_semester % 2 <> 0) THEN
        RAISE EXCEPTION 'planned semester does not match the curriculum course term parity';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_degree_plan_items_validate
BEFORE INSERT OR UPDATE ON degree_plan_items
FOR EACH ROW EXECUTE FUNCTION validate_degree_plan_item();

CREATE OR REPLACE FUNCTION validate_student_course_record()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_assignment_user uuid;
    v_assignment_curriculum uuid;
    v_course_curriculum uuid;
    v_grade_passing boolean;
BEGIN
    SELECT user_id, curriculum_id
    INTO v_assignment_user, v_assignment_curriculum
    FROM student_curriculum_assignments
    WHERE student_curriculum_assignment_id = NEW.student_curriculum_assignment_id;

    IF v_assignment_user IS NULL OR v_assignment_user <> NEW.user_id THEN
        RAISE EXCEPTION 'student course record assignment must belong to the record user';
    END IF;

    SELECT curriculum_id INTO v_course_curriculum
    FROM curriculum_courses WHERE curriculum_course_id = NEW.curriculum_course_id;

    IF v_assignment_curriculum <> v_course_curriculum THEN
        RAISE EXCEPTION 'student course record course must belong to the assignment curriculum';
    END IF;

    IF NEW.record_status IN ('taking', 'transferred') THEN
        IF NEW.final_grade IS NOT NULL THEN
            RAISE EXCEPTION '% records must not have final_grade', NEW.record_status;
        END IF;
    ELSE
        IF NEW.final_grade IS NULL THEN
            RAISE EXCEPTION '% records require final_grade', NEW.record_status;
        END IF;
        SELECT is_passing INTO v_grade_passing FROM grade_scale WHERE grade_label = NEW.final_grade;
        IF NEW.record_status = 'passed' AND NOT v_grade_passing THEN
            RAISE EXCEPTION 'passed record requires a passing grade';
        ELSIF NEW.record_status = 'failed' AND v_grade_passing THEN
            RAISE EXCEPTION 'failed record requires a non-passing grade';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_student_course_records_validate
BEFORE INSERT OR UPDATE ON student_course_records
FOR EACH ROW EXECUTE FUNCTION validate_student_course_record();

CREATE OR REPLACE FUNCTION validate_course_offering_eligibility()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_offering_course uuid;
    v_period_term varchar(20);
    v_is_override boolean;
    v_curriculum_course_course uuid;
    v_curriculum_course_term varchar(20);
BEGIN
    SELECT co.course_id, ap.term, co.is_term_override
    INTO v_offering_course, v_period_term, v_is_override
    FROM course_offerings co
    JOIN academic_periods ap ON ap.academic_period_id = co.academic_period_id
    WHERE co.course_offering_id = NEW.course_offering_id;

    SELECT course_id, term
    INTO v_curriculum_course_course, v_curriculum_course_term
    FROM curriculum_courses
    WHERE curriculum_course_id = NEW.curriculum_course_id;

    IF v_offering_course IS NULL OR v_curriculum_course_course IS NULL
       OR v_offering_course <> v_curriculum_course_course THEN
        RAISE EXCEPTION 'offering eligibility must reference the same global course';
    END IF;

    IF NOT v_is_override THEN
        IF v_period_term IN ('ganjil','genap') AND v_period_term <> v_curriculum_course_term THEN
            RAISE EXCEPTION 'offering academic period term does not match curriculum course term';
        ELSIF v_period_term = 'pendek' THEN
            RAISE EXCEPTION 'pendek offering requires explicit term override';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_course_offering_eligibilities_validate
BEFORE INSERT OR UPDATE ON course_offering_eligibilities
FOR EACH ROW EXECUTE FUNCTION validate_course_offering_eligibility();

CREATE OR REPLACE FUNCTION validate_timetable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_assignment_user uuid;
    v_assignment_current boolean;
BEGIN
    SELECT user_id, is_current
    INTO v_assignment_user, v_assignment_current
    FROM student_curriculum_assignments
    WHERE student_curriculum_assignment_id = NEW.student_curriculum_assignment_id;

    IF v_assignment_user IS NULL OR v_assignment_user <> NEW.user_id THEN
        RAISE EXCEPTION 'timetable curriculum assignment must belong to the timetable user';
    END IF;

    IF NEW.is_active AND NOT v_assignment_current THEN
        RAISE EXCEPTION 'an active timetable must use the current curriculum assignment';
    END IF;

    IF NEW.is_active AND NOT EXISTS (
        SELECT 1 FROM timetable_items ti WHERE ti.timetable_id = NEW.timetable_id
    ) THEN
        RAISE EXCEPTION 'cannot activate an empty timetable';
    END IF;

    IF NEW.is_active AND EXISTS (
        SELECT 1
        FROM (
            SELECT DISTINCT oc.course_offering_id
            FROM timetable_items ti
            JOIN class_sections cs ON cs.class_section_id = ti.class_section_id
            JOIN offering_components oc ON oc.offering_component_id = cs.offering_component_id
            WHERE ti.timetable_id = NEW.timetable_id
        ) selected_offering
        JOIN offering_components required_component
          ON required_component.course_offering_id = selected_offering.course_offering_id
         AND required_component.is_required
        WHERE NOT EXISTS (
            SELECT 1
            FROM timetable_items ti2
            JOIN class_sections cs2 ON cs2.class_section_id = ti2.class_section_id
            WHERE ti2.timetable_id = NEW.timetable_id
              AND cs2.offering_component_id = required_component.offering_component_id
        )
    ) THEN
        RAISE EXCEPTION 'active timetable is missing a required offering component';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_timetables_validate
BEFORE INSERT OR UPDATE ON timetables
FOR EACH ROW EXECUTE FUNCTION validate_timetable();

CREATE OR REPLACE FUNCTION guard_active_timetable_item_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_timetable_id uuid;
    v_is_active boolean;
BEGIN
    v_timetable_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.timetable_id ELSE NEW.timetable_id END;
    SELECT is_active INTO v_is_active FROM timetables WHERE timetable_id = v_timetable_id;

    IF v_is_active THEN
        RAISE EXCEPTION 'deactivate timetable before modifying its items';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_timetable_items_guard_active
BEFORE INSERT OR UPDATE OR DELETE ON timetable_items
FOR EACH ROW EXECUTE FUNCTION guard_active_timetable_item_mutation();

CREATE OR REPLACE FUNCTION validate_timetable_item()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_timetable_period uuid;
    v_timetable_assignment uuid;
    v_timetable_curriculum uuid;
    v_section_period uuid;
    v_component uuid;
    v_offering uuid;
    v_eligible boolean;
    v_duplicate_component boolean;
BEGIN
    SELECT t.academic_period_id, t.student_curriculum_assignment_id, sca.curriculum_id
    INTO v_timetable_period, v_timetable_assignment, v_timetable_curriculum
    FROM timetables t
    JOIN student_curriculum_assignments sca
      ON sca.student_curriculum_assignment_id = t.student_curriculum_assignment_id
    WHERE t.timetable_id = NEW.timetable_id;

    SELECT co.academic_period_id, oc.offering_component_id, co.course_offering_id
    INTO v_section_period, v_component, v_offering
    FROM class_sections cs
    JOIN offering_components oc ON oc.offering_component_id = cs.offering_component_id
    JOIN course_offerings co ON co.course_offering_id = oc.course_offering_id
    WHERE cs.class_section_id = NEW.class_section_id;

    IF v_timetable_period IS NULL OR v_section_period IS NULL OR v_timetable_period <> v_section_period THEN
        RAISE EXCEPTION 'timetable item section must belong to the timetable academic period';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM course_offering_eligibilities coe
        JOIN curriculum_courses cc ON cc.curriculum_course_id = coe.curriculum_course_id
        WHERE coe.course_offering_id = v_offering
          AND cc.curriculum_id = v_timetable_curriculum
    ) INTO v_eligible;

    IF NOT v_eligible THEN
        RAISE EXCEPTION 'selected section is not eligible for the timetable curriculum';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM timetable_items ti
        JOIN class_sections cs2 ON cs2.class_section_id = ti.class_section_id
        WHERE ti.timetable_id = NEW.timetable_id
          AND cs2.offering_component_id = v_component
          AND ti.timetable_item_id <> NEW.timetable_item_id
    ) INTO v_duplicate_component;

    IF v_duplicate_component THEN
        RAISE EXCEPTION 'a timetable can select at most one class section per offering component';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_timetable_items_validate
BEFORE INSERT OR UPDATE ON timetable_items
FOR EACH ROW EXECUTE FUNCTION validate_timetable_item();

-- ============================================================
-- 11. CURRICULUM SWITCH HELPERS
-- ============================================================

CREATE OR REPLACE FUNCTION assign_initial_curriculum(
    p_user_id uuid,
    p_actor_user_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_program_id uuid;
    v_admission_year smallint;
    v_curriculum_id uuid;
    v_assignment_id uuid;
BEGIN
    SELECT study_program_id, admission_year
    INTO v_program_id, v_admission_year
    FROM student_profiles
    WHERE user_id = p_user_id;

    IF v_program_id IS NULL THEN
        RAISE EXCEPTION 'student profile not found for user %', p_user_id;
    END IF;

    SELECT ccr.curriculum_id
    INTO v_curriculum_id
    FROM curriculum_cohort_rules ccr
    WHERE ccr.study_program_id = v_program_id
      AND ccr.is_active
      AND v_admission_year >= ccr.admission_year_from
      AND (ccr.admission_year_to IS NULL OR v_admission_year <= ccr.admission_year_to)
    ORDER BY ccr.priority ASC
    LIMIT 1;

    IF v_curriculum_id IS NULL THEN
        RAISE EXCEPTION 'no active cohort curriculum rule matches user %', p_user_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM student_curriculum_assignments
        WHERE user_id = p_user_id AND is_current
    ) THEN
        RAISE EXCEPTION 'user % already has a current curriculum assignment', p_user_id;
    END IF;

    INSERT INTO student_curriculum_assignments (
        user_id, curriculum_id, assigned_by_user_id, assignment_source, change_reason, is_current
    ) VALUES (
        p_user_id, v_curriculum_id, p_actor_user_id, 'cohort_rule', 'Initial assignment from cohort rule', true
    ) RETURNING student_curriculum_assignment_id INTO v_assignment_id;

    RETURN v_assignment_id;
END;
$$;

CREATE OR REPLACE FUNCTION switch_student_curriculum(
    p_user_id uuid,
    p_new_curriculum_id uuid,
    p_actor_user_id uuid,
    p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_assignment_id uuid;
    v_old_curriculum_id uuid;
    v_new_assignment_id uuid;
BEGIN
    IF p_actor_user_id IS NULL THEN
        RAISE EXCEPTION 'curriculum switch requires an actor user';
    END IF;

    IF p_reason IS NULL OR btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'curriculum switch requires a reason';
    END IF;

    SELECT student_curriculum_assignment_id, curriculum_id
    INTO v_old_assignment_id, v_old_curriculum_id
    FROM student_curriculum_assignments
    WHERE user_id = p_user_id AND is_current
    FOR UPDATE;

    IF v_old_assignment_id IS NULL THEN
        RAISE EXCEPTION
            'no current curriculum assignment exists; use assign_initial_curriculum() for initial assignment';
    END IF;

    IF v_old_curriculum_id = p_new_curriculum_id THEN
        RAISE EXCEPTION 'new curriculum is the same as the current curriculum';
    END IF;

    IF v_old_assignment_id IS NOT NULL THEN
        UPDATE degree_plans
        SET status = 'archived'
        WHERE user_id = p_user_id AND status = 'active';

        UPDATE timetables
        SET is_active = false
        WHERE user_id = p_user_id AND is_active;

        UPDATE student_curriculum_assignments
        SET is_current = false,
            effective_until = now()
        WHERE student_curriculum_assignment_id = v_old_assignment_id;
    END IF;

    INSERT INTO student_curriculum_assignments (
        user_id, curriculum_id, assigned_by_user_id, assignment_source,
        change_reason, is_current, effective_from
    ) VALUES (
        p_user_id, p_new_curriculum_id, p_actor_user_id,
        CASE WHEN p_actor_user_id = p_user_id THEN 'student_change' ELSE 'admin_override' END,
        p_reason, true, now()
    ) RETURNING student_curriculum_assignment_id INTO v_new_assignment_id;

    -- Deliberately DO NOT copy degree_plan_items into the new curriculum.
    -- The old planner remains archived and accessible; the new planner starts blank.
    RETURN v_new_assignment_id;
END;
$$;

-- ============================================================
-- 12. READ VIEWS
-- ============================================================

CREATE VIEW v_student_current_curriculum AS
SELECT
    sca.user_id,
    sp.study_program_id,
    sca.student_curriculum_assignment_id,
    sca.curriculum_id,
    c.curriculum_name,
    c.curriculum_year,
    sca.effective_from
FROM student_curriculum_assignments sca
JOIN student_profiles sp ON sp.user_id = sca.user_id
JOIN curricula c ON c.curriculum_id = sca.curriculum_id
WHERE sca.is_current;

-- Dynamic clash detection. We deliberately do NOT persist a class-conflict table,
-- so schedule edits cannot leave stale conflict rows behind.
CREATE VIEW v_timetable_conflicts AS
SELECT
    ti1.timetable_id,
    ti1.timetable_item_id AS timetable_item_a_id,
    ti2.timetable_item_id AS timetable_item_b_id,
    ti1.class_section_id AS class_section_a_id,
    ti2.class_section_id AS class_section_b_id,
    cs1.day_of_week,
    GREATEST(cs1.start_time, cs2.start_time) AS conflict_start,
    LEAST(cs1.end_time, cs2.end_time) AS conflict_end
FROM timetable_items ti1
JOIN timetable_items ti2
  ON ti2.timetable_id = ti1.timetable_id
 AND ti2.timetable_item_id > ti1.timetable_item_id
JOIN class_schedules cs1 ON cs1.class_section_id = ti1.class_section_id
JOIN class_schedules cs2 ON cs2.class_section_id = ti2.class_section_id
 AND cs2.day_of_week = cs1.day_of_week
 AND cs1.start_time < cs2.end_time
 AND cs2.start_time < cs1.end_time;

COMMIT;
