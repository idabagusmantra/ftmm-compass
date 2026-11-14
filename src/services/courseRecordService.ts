import { apiFetch } from "../api/client"

export interface CourseRecordPeriodDto {
  academic_year_start: number
  term: string
  label: string
}

export interface CourseRecordDto {
  id: string
  course_id: string
  code: string
  name: string
  credits: number
  semester: number
  type: "Wajib" | "Pilihan"
  parity: "odd" | "even"
  desc: string
  record_status: "taking" | "passed" | "failed" | "transferred"
  final_grade: string | null
  completed_at: string | null
  period: CourseRecordPeriodDto
}

interface CourseRecordListDto {
  data: CourseRecordDto[]
  meta: { total: number }
}

const PATH = "/api/v1/me/course-records"

export const courseRecordService = {
  list(): Promise<CourseRecordListDto> {
    return apiFetch<CourseRecordListDto>(PATH, { auth: true })
  },

  markPassed(input: {
    course_code: string
    final_grade: string
  }): Promise<CourseRecordDto> {
    return apiFetch<CourseRecordDto>(PATH, {
      method: "POST",
      body: input,
      auth: true,
    })
  },

  remove(recordId: string): Promise<void> {
    return apiFetch<void>(`${PATH}/${recordId}`, {
      method: "DELETE",
      auth: true,
    })
  },
}
