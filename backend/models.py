import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Text,
    Time,
    func,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    role: Mapped[str] = mapped_column(String(30), nullable=False, default="student")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    phone_number: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    career_interests: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)

    student_profile: Mapped[Optional["StudentProfile"]] = relationship(
        "StudentProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    elective_votes: Mapped[list["ElectiveCourseVote"]] = relationship(
        "ElectiveCourseVote",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    chat_logs: Mapped[list["ChatLog"]] = relationship(
        "ChatLog",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    @property
    def id(self) -> uuid.UUID:
        return self.user_id

class StudyProgram(Base):
    __tablename__ = "study_programs"

    study_program_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    program_code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    program_name: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    degree_level: Mapped[str] = mapped_column(String(30), nullable=False, default="sarjana")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    student_profiles: Mapped[list["StudentProfile"]] = relationship(
        "StudentProfile",
        back_populates="study_program",
    )


class StudentProfile(Base):
    __tablename__ = "student_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        primary_key=True,
    )
    study_program_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("study_programs.study_program_id", ondelete="RESTRICT"),
        nullable=False,
    )
    student_number: Mapped[Optional[str]] = mapped_column(String(30), unique=True, nullable=True)
    admission_year: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    current_semester: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="student_profile")
    study_program: Mapped["StudyProgram"] = relationship("StudyProgram", back_populates="student_profiles")


class ElectivePollingPeriod(Base):
    __tablename__ = "elective_polling_periods"

    polling_period_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    academic_year: Mapped[str] = mapped_column(String(20), nullable=False)
    target_term: Mapped[str] = mapped_column(String(10), nullable=False)
    target_semester: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="upcoming")
    min_quota_threshold: Mapped[int] = mapped_column(Integer, nullable=False, default=15)
    max_votes_per_student: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    description: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    votes: Mapped[list["ElectiveCourseVote"]] = relationship(
        "ElectiveCourseVote",
        back_populates="polling_period",
        cascade="all, delete-orphan",
    )


class ElectiveCourseVote(Base):
    __tablename__ = "elective_course_votes"

    vote_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    polling_period_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("elective_polling_periods.polling_period_id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )
    course_id: Mapped[str] = mapped_column(String(100), nullable=False)
    course_code: Mapped[str] = mapped_column(String(30), nullable=False)
    course_name: Mapped[str] = mapped_column(String(200), nullable=False)
    credits: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=3)
    priority: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship("User", back_populates="elective_votes")
    polling_period: Mapped["ElectivePollingPeriod"] = relationship(
        "ElectivePollingPeriod",
        back_populates="votes",
    )


class AcademicPeriod(Base):
    __tablename__ = "academic_periods"

    academic_period_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    academic_year_start: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    term: Mapped[str] = mapped_column(String(20), nullable=False)
    start_date: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    end_date: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


class Course(Base):
    __tablename__ = "courses"

    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    course_code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)
    course_name: Mapped[str] = mapped_column(String(200), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class Curriculum(Base):
    __tablename__ = "curricula"

    curriculum_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    study_program_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("study_programs.study_program_id", ondelete="RESTRICT"),
        nullable=False,
    )
    curriculum_name: Mapped[str] = mapped_column(String(150), nullable=False)
    curriculum_year: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    minimum_graduation_credits: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=144)
    standard_duration_semesters: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=8)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class CurriculumCourse(Base):
    __tablename__ = "curriculum_courses"

    curriculum_course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    curriculum_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("curricula.curriculum_id", ondelete="RESTRICT"),
        nullable=False,
    )
    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("courses.course_id", ondelete="RESTRICT"),
        nullable=False,
    )
    credits_total: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    # NULL hanya untuk MK pilihan tanpa semester tetap (migrasi b3f1c2d4e5a6).
    recommended_semester: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    term: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    course_type: Mapped[str] = mapped_column(String(30), nullable=False)
    course_scope: Mapped[str] = mapped_column(String(30), nullable=False, default="program_studi")
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    course: Mapped["Course"] = relationship("Course")
    curriculum: Mapped["Curriculum"] = relationship("Curriculum")


class StudentCurriculumAssignment(Base):
    __tablename__ = "student_curriculum_assignments"

    student_curriculum_assignment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        nullable=False,
    )
    curriculum_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("curricula.curriculum_id", ondelete="RESTRICT"),
        nullable=False,
    )
    is_current: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    assignment_source: Mapped[str] = mapped_column(
        String(30), nullable=False, default="cohort_rule"
    )
    change_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    effective_from: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    effective_until: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class StudentCourseRecord(Base):
    __tablename__ = "student_course_records"

    student_course_record_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        nullable=False,
    )
    student_curriculum_assignment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("student_curriculum_assignments.student_curriculum_assignment_id", ondelete="RESTRICT"),
        nullable=False,
    )
    curriculum_course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("curriculum_courses.curriculum_course_id", ondelete="RESTRICT"),
        nullable=False,
    )
    academic_period_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("academic_periods.academic_period_id", ondelete="RESTRICT"),
        nullable=False,
    )
    record_status: Mapped[str] = mapped_column(String(30), nullable=False)
    final_grade: Mapped[Optional[str]] = mapped_column(String(2), nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    curriculum_course: Mapped["CurriculumCourse"] = relationship("CurriculumCourse")
    academic_period: Mapped["AcademicPeriod"] = relationship("AcademicPeriod")


class CourseOffering(Base):
    __tablename__ = "course_offerings"

    course_offering_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    academic_period_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("academic_periods.academic_period_id", ondelete="RESTRICT"),
        nullable=False,
    )
    course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("courses.course_id", ondelete="RESTRICT"),
        nullable=False,
    )
    offering_code: Mapped[str] = mapped_column(String(40), nullable=False)
    course: Mapped["Course"] = relationship("Course")


class CourseOfferingEligibility(Base):
    __tablename__ = "course_offering_eligibilities"

    course_offering_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("course_offerings.course_offering_id", ondelete="RESTRICT"),
        primary_key=True,
    )
    curriculum_course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("curriculum_courses.curriculum_course_id", ondelete="RESTRICT"),
        primary_key=True,
    )


class OfferingComponent(Base):
    __tablename__ = "offering_components"

    offering_component_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    course_offering_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("course_offerings.course_offering_id", ondelete="RESTRICT"),
        nullable=False,
    )
    component_code: Mapped[str] = mapped_column(String(30), nullable=False)
    component_type: Mapped[str] = mapped_column(String(30), nullable=False, default="lecture")
    course_offering: Mapped["CourseOffering"] = relationship("CourseOffering")


class ClassSection(Base):
    __tablename__ = "class_sections"

    class_section_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    offering_component_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("offering_components.offering_component_id", ondelete="RESTRICT"),
        nullable=False,
    )
    section_code: Mapped[str] = mapped_column(String(30), nullable=False)
    capacity: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    enrollment_status: Mapped[str] = mapped_column(String(30), nullable=False, default="open")

    offering_component: Mapped["OfferingComponent"] = relationship("OfferingComponent")


class ClassSchedule(Base):
    __tablename__ = "class_schedules"

    class_schedule_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    class_section_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class_sections.class_section_id", ondelete="RESTRICT"),
        nullable=False,
    )
    day_of_week: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    start_time: Mapped[datetime] = mapped_column(Time, nullable=False)
    end_time: Mapped[datetime] = mapped_column(Time, nullable=False)
    room_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    class_section: Mapped["ClassSection"] = relationship("ClassSection")


class Timetable(Base):
    __tablename__ = "timetables"

    timetable_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        nullable=False,
    )
    student_curriculum_assignment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("student_curriculum_assignments.student_curriculum_assignment_id", ondelete="RESTRICT"),
        nullable=False,
    )
    academic_period_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("academic_periods.academic_period_id", ondelete="RESTRICT"),
        nullable=False,
    )
    timetable_name: Mapped[str] = mapped_column(String(100), nullable=False, default="Jadwal Utama")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class TimetableItem(Base):
    __tablename__ = "timetable_items"

    timetable_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    timetable_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("timetables.timetable_id", ondelete="RESTRICT"),
        nullable=False,
    )
    class_section_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class_sections.class_section_id", ondelete="RESTRICT"),
        nullable=False,
    )

    class_section: Mapped["ClassSection"] = relationship("ClassSection")


class UserNotification(Base):
    __tablename__ = "user_notifications"

    notification_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=True,
    )
    target_role: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False, default="info")
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    action_url: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped[Optional["User"]] = relationship("User")


class ChatLog(Base):
    __tablename__ = "chat_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    session_id: Mapped[str] = mapped_column(String(100), index=True, nullable=False)
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
    )
    user_message: Mapped[str] = mapped_column(Text, nullable=False)
    assistant_reply: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    action_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    routing_mode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    latency_ms: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped[Optional["User"]] = relationship("User", back_populates="chat_logs")


class DegreePlan(Base):
    __tablename__ = "degree_plans"

    degree_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        nullable=False,
    )
    student_curriculum_assignment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "student_curriculum_assignments.student_curriculum_assignment_id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )
    plan_name: Mapped[str] = mapped_column(
        String(100), nullable=False, default="Rencana Utama"
    )
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="draft")
    target_graduation_semester: Mapped[Optional[int]] = mapped_column(
        SmallInteger, nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    assignment: Mapped["StudentCurriculumAssignment"] = relationship(
        "StudentCurriculumAssignment"
    )
    items: Mapped[list["DegreePlanItem"]] = relationship(
        "DegreePlanItem",
        back_populates="plan",
        cascade="all, delete-orphan",
        order_by="DegreePlanItem.planned_semester",
    )


class DegreePlanItem(Base):
    __tablename__ = "degree_plan_items"

    degree_plan_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    degree_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("degree_plans.degree_plan_id", ondelete="RESTRICT"),
        nullable=False,
    )
    curriculum_course_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("curriculum_courses.curriculum_course_id", ondelete="RESTRICT"),
        nullable=False,
    )
    planned_semester: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    planning_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="planned"
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    plan: Mapped["DegreePlan"] = relationship("DegreePlan", back_populates="items")
    curriculum_course: Mapped["CurriculumCourse"] = relationship("CurriculumCourse")
