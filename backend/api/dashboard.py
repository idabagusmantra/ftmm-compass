"""Dashboard telemetry per peran. Semua angka berasal dari database."""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from academics import TOTAL_SKS_FOR_GRADUATION, grade_points
from auth import get_current_user
from database import get_db
from models import (
    ClassSchedule,
    ClassSection,
    Course,
    CourseOffering,
    CurriculumCourse,
    DegreePlan,
    DegreePlanItem,
    OfferingComponent,
    StudentCourseRecord,
    StudentProfile as StudentProfileModel,
    StudyProgram,
    Timetable,
    TimetableItem,
    User,
)
from schemas import (
    AdminDashboardStats,
    DashboardMeResponse,
    DashboardScheduleItem,
    LecturerDashboardStats,
    StudentDashboardStats,
)

router = APIRouter()

DAY_NAMES = {1: "Senin", 2: "Selasa", 3: "Rabu", 4: "Kamis", 5: "Jumat"}
COLOR_PALETTE = ["teal", "navy", "gold", "orange"]


def _schedule_item(
    index: int,
    schedule: ClassSchedule,
    section: ClassSection,
    course: Course,
    *,
    lecturer: str | None = None,
    enrolled: int | None = None,
) -> DashboardScheduleItem:
    start = schedule.start_time.strftime("%H:%M")
    end = schedule.end_time.strftime("%H:%M")
    return DashboardScheduleItem(
        id=f"sch-{schedule.class_schedule_id}",
        course_id=str(course.course_id),
        course_code=course.course_code,
        course_name=course.course_name,
        credits=0,
        day=DAY_NAMES.get(schedule.day_of_week, ""),
        start_time=start,
        end_time=end,
        time=f"{start} - {end}",
        room=schedule.room_name or "",
        lecturer=lecturer,
        class_name=section.section_code,
        enrolled_students=enrolled,
        color=COLOR_PALETTE[index % len(COLOR_PALETTE)],
    )


async def _student_schedule(db: AsyncSession, user_id) -> list[DashboardScheduleItem]:
    timetable = (
        await db.execute(
            select(Timetable).where(
                Timetable.user_id == user_id, Timetable.is_active.is_(True)
            )
        )
    ).scalars().first()
    if timetable is None:
        return []

    rows = (
        await db.execute(
            select(ClassSchedule, ClassSection, OfferingComponent, CourseOffering, Course)
            .join(ClassSection, ClassSection.class_section_id == ClassSchedule.class_section_id)
            .join(TimetableItem, TimetableItem.class_section_id == ClassSection.class_section_id)
            .join(OfferingComponent, OfferingComponent.offering_component_id == ClassSection.offering_component_id)
            .join(CourseOffering, CourseOffering.course_offering_id == OfferingComponent.course_offering_id)
            .join(Course, Course.course_id == CourseOffering.course_id)
            .where(TimetableItem.timetable_id == timetable.timetable_id)
            .order_by(ClassSchedule.day_of_week, ClassSchedule.start_time)
        )
    ).all()
    return [
        _schedule_item(index, schedule, section, course)
        for index, (schedule, section, _component, _offering, course) in enumerate(rows)
    ]


@router.get("/dashboard/me", response_model=DashboardMeResponse)
async def get_dashboard_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role == "student":
        profile = (
            await db.execute(
                select(StudentProfileModel)
                .options(selectinload(StudentProfileModel.study_program))
                .where(StudentProfileModel.user_id == current_user.user_id)
            )
        ).scalars().first()

        records = (
            await db.execute(
                select(StudentCourseRecord)
                .options(
                    selectinload(StudentCourseRecord.curriculum_course).selectinload(
                        CurriculumCourse.course
                    )
                )
                .where(StudentCourseRecord.user_id == current_user.user_id)
            )
        ).scalars().all()

        sks_completed = 0
        quality_points = 0.0
        for record in records:
            credits = (
                record.curriculum_course.credits_total
                if record.curriculum_course
                else 0
            )
            if record.record_status == "passed":
                sks_completed += credits
                quality_points += grade_points(record.final_grade) * credits

        # "Direncanakan" = item rencana studi aktif yang belum lulus, bukan
        # `student_course_records.record_status='taking'` (lihat plan §9.2).
        passed_course_ids = {
            record.curriculum_course_id
            for record in records
            if record.record_status == "passed"
        }
        plan_items = (
            await db.execute(
                select(DegreePlanItem)
                .join(
                    DegreePlan,
                    DegreePlan.degree_plan_id == DegreePlanItem.degree_plan_id,
                )
                .options(selectinload(DegreePlanItem.curriculum_course))
                .where(
                    DegreePlan.user_id == current_user.user_id,
                    DegreePlan.status == "active",
                    DegreePlanItem.planning_status == "planned",
                )
            )
        ).scalars().all()
        planned = [
            item
            for item in plan_items
            if item.curriculum_course_id not in passed_course_ids
        ]
        courses_planned = len(planned)
        sks_planned = sum(
            item.curriculum_course.credits_total if item.curriculum_course else 0
            for item in planned
        )

        gpa = round(quality_points / sks_completed, 2) if sks_completed else 0.0
        stats = StudentDashboardStats(
            type="student",
            sks_completed=sks_completed,
            sks_target=TOTAL_SKS_FOR_GRADUATION,
            completion_percentage=round(
                sks_completed / TOTAL_SKS_FOR_GRADUATION * 100, 2
            )
            if sks_completed
            else 0.0,
            current_semester=profile.current_semester if profile else 1,
            courses_planned=courses_planned,
            sks_planned=sks_planned,
            gpa=gpa,
            predicate=(
                "Dengan Pujian (Cumlaude)"
                if gpa >= 3.5
                else "Sangat Memuaskan"
                if sks_completed
                else "Belum ada nilai"
            ),
        )

        return DashboardMeResponse(
            user_id=str(current_user.user_id),
            full_name=current_user.full_name,
            role=current_user.role,
            email=current_user.email,
            student_number=profile.student_number if profile else None,
            study_program=(
                profile.study_program.program_name
                if (profile and profile.study_program)
                else ""
            ),
            stats=stats,
            schedule=await _student_schedule(db, current_user.user_id),
        )

    if current_user.role == "lecturer":
        stats = LecturerDashboardStats(
            type="lecturer",
            courses_taught=0,
            sks_taught=0,
            total_students=0,
            advisee_students=0,
            status="Belum ada penugasan mengajar tercatat",
        )
        return DashboardMeResponse(
            user_id=str(current_user.user_id),
            full_name=current_user.full_name,
            role=current_user.role,
            email=current_user.email,
            stats=stats,
            schedule=[],
        )

    total_students = (
        await db.execute(select(func.count(User.user_id)).where(User.role == "student"))
    ).scalar() or 0
    total_lecturers = (
        await db.execute(select(func.count(User.user_id)).where(User.role == "lecturer"))
    ).scalar() or 0
    total_courses = (
        await db.execute(select(func.count(Course.course_id)).where(Course.is_active.is_(True)))
    ).scalar() or 0
    total_programs = (
        await db.execute(select(func.count(StudyProgram.study_program_id)))
    ).scalar() or 0

    stats = AdminDashboardStats(
        type="admin",
        total_active_students=total_students,
        total_lecturers=total_lecturers,
        total_courses=total_courses,
        total_study_programs=total_programs,
        system_status="Database & API aktif",
    )
    return DashboardMeResponse(
        user_id=str(current_user.user_id),
        full_name=current_user.full_name,
        role=current_user.role,
        email=current_user.email,
        stats=stats,
        schedule=[],
    )
