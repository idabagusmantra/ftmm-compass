from datetime import date, datetime
from typing import List, Optional, Dict, Literal, Any, Union
from pydantic import BaseModel, Field


class OllamaHealthDetail(BaseModel):
    online: bool
    host: str
    default_model: str


class HealthResponse(BaseModel):
    status: str = "healthy"
    service: str = "FTMM Compass AI Planner Gateway"
    chatbot_service_online: bool = False
    chatbot_model: Optional[str] = None
    ollama_online: bool = False
    default_model: Optional[str] = None
    ollama: Optional[OllamaHealthDetail] = None
    database_online: bool = False

class StudentProfile(BaseModel):
    program_studi: Optional[str] = Field(
        None, description="Nama program studi resmi FTMM (e.g. Rekayasa Perangkat Lunak, Teknologi Sains Data)"
    )
    semester_saat_ini: Optional[int] = Field(
        None, ge=1, le=8, description="Semester yang sedang ditempuh mahasiswa (1-8)"
    )
    riwayat_matkul_lulus: List[str] = Field(
        default_factory=list, description="Daftar nama atau kode mata kuliah yang sudah lulus"
    )
    minat_fokus: List[str] = Field(
        default_factory=list, description="Bidang minat/spesialisasi karir (e.g. Data Science, Machine Learning, Web Backend)"
    )
    target_kelulusan_semester: int = Field(
        8, ge=7, le=8, description="Target semester untuk lulus (7 atau 8)"
    )
    maks_sks_per_semester: int = Field(
        24, ge=12, le=24, description="Batas maksimum SKS per semester"
    )
    is_confirmed_by_user: bool = Field(
        False, description="Apakah mahasiswa sudah mengonfirmasi ringkasan data profil"
    )


class CourseModel(BaseModel):
    id: str = ""
    code: Optional[str] = None
    name: str
    credits: int = 3
    semester: int = 1
    type: Literal["Wajib", "Pilihan"] = "Pilihan"
    parity: Literal["odd", "even"] = "odd"
    desc: str = ""
    program: Optional[str] = None
    lecturer: Optional[str] = None
    prerequisites: List[str] = Field(default_factory=list)
class AdminCourseCreateRequest(BaseModel):
    course_code: str
    course_name: str
    program_name: str
    credits: int = 3
    recommended_semester: int = 1
    term: Literal["ganjil", "genap"] = "ganjil"
    course_type: Literal["Wajib", "Pilihan"] = "Pilihan"
    description: Optional[str] = ""
    lecturer: Optional[str] = None
    prerequisites: List[str] = Field(default_factory=list)

class AdminCourseUpdateRequest(BaseModel):
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    program_name: Optional[str] = None
    credits: Optional[int] = None
    recommended_semester: Optional[int] = None
    term: Optional[Literal["ganjil", "genap"]] = None
    course_type: Optional[Literal["Wajib", "Pilihan"]] = None
    description: Optional[str] = None
    lecturer: Optional[str] = None
    is_active: Optional[bool] = None
    prerequisites: Optional[List[str]] = None


class PlacedCourseModel(CourseModel):
    status: Literal["completed", "planned", "wishlist"] = "planned"


class PlanValidationRequest(BaseModel):
    program_studi: str
    semester_saat_ini: int
    riwayat_matkul_lulus: List[str] = Field(default_factory=list)
    maks_sks_per_semester: int = 24
    plan: Dict[int, List[PlacedCourseModel]]


class PlanValidationResponse(BaseModel):
    is_valid: bool
    errors: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)
    total_credits: int = 0
    total_sks_planned: int = 0
    semester_credits: Dict[int, int] = Field(default_factory=dict)
    details_per_semester: Dict[int, Dict[str, Any]] = Field(default_factory=dict)


class CourseSearchItem(CourseModel):
    score: float = 0.0


class CourseSearchResponse(BaseModel):
    source: str = "chatbot_ssot"
    query: str
    program_studi: Optional[str] = None
    total_hits: int = 0
    results: List[CourseSearchItem] = Field(default_factory=list)

class PlanPayloadSummary(BaseModel):
    program_studi: str
    current_semester: int
    target_semester: int
    total_credits: int
    focus_tracks: List[str] = Field(default_factory=list)
    note: Optional[str] = ""


class DegreePlanPayload(BaseModel):
    action: Literal["APPLY_DEGREE_PLAN"] = "APPLY_DEGREE_PLAN"
    summary: PlanPayloadSummary
    plan: Dict[int, List[PlacedCourseModel]] = Field(default_factory=dict)


PlanningStatus = Literal["planned", "wishlist"]


class DegreePlanItemRequest(BaseModel):
    course_code: str = Field(min_length=1, max_length=40)
    planned_semester: int = Field(ge=1, le=14)
    planning_status: PlanningStatus = "planned"


class DegreePlanItemsRequest(BaseModel):
    items: List[DegreePlanItemRequest] = Field(default_factory=list, max_length=200)


class DegreePlanCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    items: List[DegreePlanItemRequest] = Field(default_factory=list, max_length=200)


class DegreePlanUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    status: Optional[Literal["draft", "active"]] = None


class DegreePlanItemResponse(BaseModel):
    id: str
    course_id: str
    code: str
    name: str
    credits: int
    semester: int
    type: Literal["Wajib", "Pilihan"]
    parity: Literal["odd", "even"]
    desc: str = ""
    planning_status: PlanningStatus = "planned"


class DegreePlanResponse(BaseModel):
    id: str
    name: str
    status: Literal["draft", "active", "archived"]
    updated_at: datetime
    items: List[DegreePlanItemResponse] = Field(default_factory=list)


class DegreePlanListResponse(BaseModel):
    data: List[DegreePlanResponse] = Field(default_factory=list)
    meta: Dict[str, int] = Field(default_factory=dict)


class DegreePlanCatalogResponse(BaseModel):
    data: List[CourseModel] = Field(default_factory=list)


RecordStatus = Literal["taking", "passed", "failed", "transferred"]


class CourseRecordPeriod(BaseModel):
    academic_year_start: int
    term: str
    label: str


class CourseRecordResponse(BaseModel):
    id: str
    course_id: str
    code: str
    name: str
    credits: int
    semester: int
    type: Literal["Wajib", "Pilihan"]
    parity: Literal["odd", "even"]
    desc: str = ""
    record_status: RecordStatus
    final_grade: Optional[str] = None
    completed_at: Optional[date] = None
    period: CourseRecordPeriod


class CourseRecordListResponse(BaseModel):
    data: List[CourseRecordResponse] = Field(default_factory=list)
    meta: Dict[str, int] = Field(default_factory=dict)


class CourseRecordCreateRequest(BaseModel):
    course_code: str = Field(min_length=1, max_length=40)
    final_grade: str = Field(min_length=1, max_length=2)


class ChatMessage(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str
    plan_payload: Optional[DegreePlanPayload] = None


class ChatRequest(BaseModel):
    message: str
    history: List[ChatMessage] = Field(default_factory=list)
    student_profile: Optional[StudentProfile] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    updated_profile: StudentProfile
    plan_payload: Optional[DegreePlanPayload] = None
    action_type: Optional[str] = None
    missing_slots: List[str] = Field(default_factory=list)
    routing_mode: Optional[str] = None
    latency_ms: Optional[float] = None


class LoginRequest(BaseModel):
    identifier: str
    password: str


class UserStudentProfileResponse(BaseModel):
    student_number: Optional[str] = None
    study_program: Optional[str] = None
    program_code: Optional[str] = None
    admission_year: Optional[int] = None
    current_semester: Optional[int] = None

class UserProfileUpdateRequest(BaseModel):
    phone_number: Optional[str] = Field(None, max_length=30, description="Nomor telepon atau WhatsApp aktif")
    bio: Optional[str] = Field(None, max_length=500, description="Bio atau deskripsi singkat akademik")
    career_interests: Optional[List[str]] = Field(default_factory=list, description="Minat atau fokus bidang karir")



class UserResponse(BaseModel):
    user_id: str
    email: str
    full_name: str
    role: str
    auth_provider: str = "Cybercampus SSO UNAIR"
    academic_identifier: Optional[str] = None
    unit_name: Optional[str] = None
    phone_number: Optional[str] = None
    bio: Optional[str] = None
    career_interests: List[str] = Field(default_factory=list)
    permissions: List[str] = Field(default_factory=list)
    student_profile: Optional[UserStudentProfileResponse] = None

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 86400
    user: UserResponse
class PollingPeriodResponse(BaseModel):
    period_id: str
    academic_year: str
    term: Literal["ganjil", "genap"]
    target_semester_type: Literal["ganjil", "genap"]
    start_date: str
    end_date: str
    is_active: bool
    min_quorum: int
    max_votes_per_student: int
    description: Optional[str] = None


class CreatePollingPeriodRequest(BaseModel):
    title: str
    academic_year: str
    target_term: Literal["ganjil", "genap"]
    target_semester: int = Field(..., ge=1, le=8)
    start_date: str
    end_date: str
    status: Literal["upcoming", "open", "closed"] = "upcoming"
    min_quota_threshold: int = 15
    max_votes_per_student: int = 3
    description: Optional[str] = None


class ElectiveVoteRequest(BaseModel):
    course_id: str
    priority: int = Field(..., ge=1, le=3)


class ElectiveVoteResponse(BaseModel):
    vote_id: str
    course_id: str
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    priority: int
    created_at: str


class CourseDemandItem(BaseModel):
    course_id: str
    course_code: str
    course_name: str
    study_program: str
    program_code: Optional[str] = None
    credits: int = 3
    total_votes: int = 0
    priority_1_votes: int = 0
    priority_2_votes: int = 0
    priority_3_votes: int = 0
    min_quorum: int = 15
    status: Literal["QUALIFIED", "BORDERLINE", "UNQUALIFIED"]
    projected_classes: int = 0


class DemandAnalyticsResponse(BaseModel):
    period: PollingPeriodResponse
    total_students_voted: int
    items: List[CourseDemandItem] = Field(default_factory=list)


class DashboardScheduleItem(BaseModel):
    id: str
    course_id: str
    course_code: str
    course_name: str
    credits: int
    day: str
    start_time: str
    end_time: str
    time: str
    room: str
    lecturer: Optional[str] = None
    class_name: Optional[str] = None
    enrolled_students: Optional[int] = None
    color: Optional[str] = "teal"


class AcademicPeriodResponse(BaseModel):
    academic_year: str
    term: Literal["ganjil", "genap", "pendek"]
    label: str
    term_label: str
    week_label: str
    start_date: date
    end_date: date
    first_week_monday: date
    semester_weeks: int


class StudentDashboardStats(BaseModel):
    type: Literal["student"] = "student"
    sks_completed: int
    sks_target: int = 144
    completion_percentage: float
    current_semester: int
    courses_planned: int
    sks_planned: int
    gpa: float
    predicate: str


class LecturerDashboardStats(BaseModel):
    type: Literal["lecturer"] = "lecturer"
    courses_taught: int
    sks_taught: int
    total_students: int
    advisee_students: int
    status: str


class AdminDashboardStats(BaseModel):
    type: Literal["admin"] = "admin"
    total_active_students: int
    total_lecturers: int
    total_courses: int
    total_study_programs: int
    system_status: str


class DashboardMeResponse(BaseModel):
    user_id: str
    full_name: str
    role: str
    email: str
    student_number: Optional[str] = None
    study_program: Optional[str] = None
    stats: Union[StudentDashboardStats, LecturerDashboardStats, AdminDashboardStats]
    schedule: List[DashboardScheduleItem] = Field(default_factory=list)


class NotificationItemResponse(BaseModel):
    id: str
    title: str
    message: str
    type: Literal["warning", "deadline", "info", "success"] = "info"
    is_read: bool = False
    action_url: Optional[str] = None
    timestamp: str
    created_at: str


class NotificationListResponse(BaseModel):
    unread_count: int
    items: List[NotificationItemResponse]
