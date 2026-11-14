"""Router HTTP transkrip mahasiswa. Didaftarkan dua kali oleh app.py (v1 dan legacy)."""

import uuid

from fastapi import APIRouter, Depends, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_user
from course_records import (
    AlreadyCompleted,
    NoActivePeriod,
    NonPassingGrade,
    UnknownGrade,
    delete_record,
    list_records,
    mark_passed,
    to_response,
)
from database import get_db
from models import User
from plan_storage import CurriculumMismatch, NoCurriculumAssignment, UnknownCourse
from schemas import (
    CourseRecordCreateRequest,
    CourseRecordListResponse,
    CourseRecordResponse,
)

router = APIRouter()


def _fail(
    status_code: int,
    code: str,
    message: str,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "detail": message,
            "error": {"code": code, "message": message, "details": []},
        },
    )


def _parse_id(raw: str) -> uuid.UUID:
    try:
        return uuid.UUID(raw)
    except ValueError:
        return uuid.UUID(int=0)


def _student_only(current_user: User) -> JSONResponse | None:
    if current_user.role != "student":
        return _fail(
            403,
            "not_a_student",
            "Transkrip mata kuliah hanya tersedia untuk akun mahasiswa",
        )
    return None


def _domain_error(exc: Exception) -> JSONResponse:
    if isinstance(exc, NoCurriculumAssignment):
        return _fail(
            422,
            "no_curriculum_assignment",
            "Profil prodi mahasiswa belum terdaftar pada kurikulum mana pun",
        )
    if isinstance(exc, UnknownCourse):
        return _fail(
            422, "unknown_course", f"Mata kuliah '{exc.code}' tidak ditemukan"
        )
    if isinstance(exc, CurriculumMismatch):
        return _fail(
            422,
            "curriculum_mismatch",
            f"Mata kuliah '{exc.code}' bukan bagian kurikulum mahasiswa",
        )
    if isinstance(exc, UnknownGrade):
        return _fail(
            422, "unknown_grade", f"Nilai '{exc.grade}' bukan skala nilai FTMM"
        )
    if isinstance(exc, NonPassingGrade):
        return _fail(
            422,
            "non_passing_grade",
            f"Nilai '{exc.grade}' tidak lulus sehingga tidak dapat menandai mata kuliah selesai",
        )
    if isinstance(exc, AlreadyCompleted):
        return _fail(
            409,
            "already_completed",
            f"Mata kuliah '{exc.code}' sudah tercatat lulus",
        )
    assert isinstance(exc, NoActivePeriod)
    return _fail(
        409,
        "no_active_period",
        "Tidak ada periode akademik aktif untuk mencatat nilai",
    )


@router.get("/me/course-records", response_model=CourseRecordListResponse)
async def list_course_records(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    denied = _student_only(current_user)
    if denied is not None:
        return denied
    records = await list_records(db, current_user)
    return CourseRecordListResponse(
        data=[to_response(record) for record in records],
        meta={"total": len(records)},
    )


@router.post(
    "/me/course-records",
    response_model=CourseRecordResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_course_record(
    payload: CourseRecordCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    denied = _student_only(current_user)
    if denied is not None:
        return denied
    try:
        record = await mark_passed(db, current_user, payload)
    except (
        NoCurriculumAssignment,
        UnknownCourse,
        CurriculumMismatch,
        UnknownGrade,
        NonPassingGrade,
        AlreadyCompleted,
        NoActivePeriod,
    ) as exc:
        return _domain_error(exc)
    except DBAPIError as exc:
        await db.rollback()
        return _fail(422, "invalid_record", f"Catatan transkrip ditolak: {exc.orig}")

    response = JSONResponse(
        status_code=status.HTTP_201_CREATED,
        content=to_response(record).model_dump(mode="json"),
    )
    response.headers["Location"] = (
        f"/api/v1/me/course-records/{record.student_course_record_id}"
    )
    return response


@router.delete(
    "/me/course-records/{record_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def delete_course_record(
    record_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    denied = _student_only(current_user)
    if denied is not None:
        return denied
    record = await delete_record(db, current_user, _parse_id(record_id))
    if record is None:
        return _fail(404, "not_found", "Catatan transkrip tidak ditemukan")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
