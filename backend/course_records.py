"""Riwayat mata kuliah mahasiswa (`student_course_records`).

Satu jalur baca/tulis untuk transkrip; router HTTP hanya memetakan exception
domain ke status code. Rencana studi tetap disimpan terpisah di `degree_plans`.
"""

import uuid
from datetime import date
from typing import Optional, Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from academics import GRADE_POINTS, TERM_TITLES, current_period, parity_of
from catalog import normalize_course_type
from models import (
    AcademicPeriod,
    Course,
    CurriculumCourse,
    StudentCourseRecord,
    User,
)
from plan_storage import (
    CurriculumMismatch,
    UnknownCourse,
    ensure_assignment,
)
from schemas import (
    CourseRecordCreateRequest,
    CourseRecordPeriod,
    CourseRecordResponse,
)


class NoActivePeriod(Exception):
    pass


class UnknownGrade(Exception):
    def __init__(self, grade: str):
        self.grade = grade


class NonPassingGrade(Exception):
    def __init__(self, grade: str):
        self.grade = grade


class AlreadyCompleted(Exception):
    def __init__(self, code: str):
        self.code = code


def _record_query():
    return select(StudentCourseRecord).options(
        selectinload(StudentCourseRecord.curriculum_course).selectinload(
            CurriculumCourse.course
        ),
        selectinload(StudentCourseRecord.academic_period),
    )


async def list_records(
    db: AsyncSession, user: User
) -> Sequence[StudentCourseRecord]:
    stmt = (
        _record_query()
        .where(StudentCourseRecord.user_id == user.user_id)
        .order_by(
            AcademicPeriod.academic_year_start.desc(),
            AcademicPeriod.term,
            StudentCourseRecord.created_at,
        )
        .join(
            AcademicPeriod,
            AcademicPeriod.academic_period_id
            == StudentCourseRecord.academic_period_id,
        )
    )
    return (await db.execute(stmt)).scalars().all()


async def _active_period(db: AsyncSession) -> AcademicPeriod:
    period = (
        await db.execute(
            select(AcademicPeriod).where(AcademicPeriod.is_active.is_(True))
        )
    ).scalars().first()
    if period is not None:
        return period

    year, term = current_period(date.today())
    period = (
        await db.execute(
            select(AcademicPeriod).where(
                AcademicPeriod.academic_year_start == year,
                AcademicPeriod.term == term,
            )
        )
    ).scalars().first()
    if period is None:
        raise NoActivePeriod()
    return period


async def _curriculum_course(
    db: AsyncSession, curriculum_id: uuid.UUID, code: str
) -> CurriculumCourse:
    row = (
        await db.execute(
            select(CurriculumCourse)
            .join(Course, Course.course_id == CurriculumCourse.course_id)
            .options(selectinload(CurriculumCourse.course))
            .where(
                CurriculumCourse.curriculum_id == curriculum_id,
                Course.course_code == code,
            )
        )
    ).scalars().first()
    if row is not None:
        return row

    exists = (
        await db.execute(select(Course.course_id).where(Course.course_code == code))
    ).first()
    if exists:
        raise CurriculumMismatch(code)
    raise UnknownCourse(code)


async def mark_passed(
    db: AsyncSession, user: User, payload: CourseRecordCreateRequest
) -> StudentCourseRecord:
    code = payload.course_code.strip().upper()
    grade = payload.final_grade.strip().upper()
    if grade not in GRADE_POINTS:
        raise UnknownGrade(grade)
    if GRADE_POINTS[grade] < 1.0:
        raise NonPassingGrade(grade)

    assignment = await ensure_assignment(db, user)
    course = await _curriculum_course(db, assignment.curriculum_id, code)

    passed = (
        await db.execute(
            select(StudentCourseRecord.student_course_record_id).where(
                StudentCourseRecord.user_id == user.user_id,
                StudentCourseRecord.curriculum_course_id
                == course.curriculum_course_id,
                StudentCourseRecord.record_status == "passed",
            )
        )
    ).first()
    if passed:
        raise AlreadyCompleted(code)

    period = await _active_period(db)
    record = (
        await db.execute(
            _record_query().where(
                StudentCourseRecord.user_id == user.user_id,
                StudentCourseRecord.curriculum_course_id
                == course.curriculum_course_id,
                StudentCourseRecord.academic_period_id
                == period.academic_period_id,
            )
        )
    ).scalars().first()

    if record is None:
        record = StudentCourseRecord(
            user_id=user.user_id,
            student_curriculum_assignment_id=(
                assignment.student_curriculum_assignment_id
            ),
            curriculum_course_id=course.curriculum_course_id,
            academic_period_id=period.academic_period_id,
            record_status="passed",
            final_grade=grade,
            completed_at=date.today(),
        )
        db.add(record)
    else:
        record.record_status = "passed"
        record.final_grade = grade
        record.completed_at = date.today()

    await db.flush()
    loaded = (
        await db.execute(
            _record_query().where(
                StudentCourseRecord.student_course_record_id
                == record.student_course_record_id
            )
        )
    ).scalars().first()
    assert loaded is not None
    return loaded


async def delete_record(
    db: AsyncSession, user: User, record_id: uuid.UUID
) -> Optional[StudentCourseRecord]:
    record = (
        await db.execute(
            _record_query().where(
                StudentCourseRecord.student_course_record_id == record_id,
                StudentCourseRecord.user_id == user.user_id,
            )
        )
    ).scalars().first()
    if record is None:
        return None
    await db.delete(record)
    await db.flush()
    return record


def to_response(record: StudentCourseRecord) -> CourseRecordResponse:
    course = record.curriculum_course
    period = record.academic_period
    term_label = TERM_TITLES.get(period.term, period.term)
    return CourseRecordResponse(
        id=str(record.student_course_record_id),
        course_id=str(course.course_id),
        code=course.course.course_code,
        name=course.course.course_name,
        credits=course.credits_total,
        semester=course.recommended_semester,
        type=normalize_course_type(course.course_type),
        parity=(
            "odd"
            if course.term == "ganjil"
            else "even"
            if course.term == "genap"
            else parity_of(course.recommended_semester)
        ),
        desc=course.description or "",
        record_status=record.record_status,
        final_grade=record.final_grade,
        completed_at=record.completed_at,
        period=CourseRecordPeriod(
            academic_year_start=period.academic_year_start,
            term=period.term,
            label=(
                f"{term_label} "
                f"{period.academic_year_start}/{period.academic_year_start + 1}"
            ),
        ),
    )
