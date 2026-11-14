import { useCallback, useEffect, useRef, useState } from "react"
import { apiErrorMessage } from "../api/client"
import type { PlacedCourse } from "../components/degree-planner/types"
import {
  courseRecordService,
  type CourseRecordDto,
} from "../services/courseRecordService"
import { useSession } from "./session"

export interface CourseRecordsReturn {
  records: CourseRecordDto[]
  completedBySemester: Record<number, PlacedCourse[]>
  completedByKey: Map<string, CourseRecordDto>
  isLoading: boolean
  isMutating: boolean
  error: string | null
  markPassed: (code: string, grade: string) => Promise<boolean>
  unmarkPassed: (recordId: string) => Promise<boolean>
}

const toPlaced = (record: CourseRecordDto): PlacedCourse => ({
  id: record.id,
  code: record.code,
  name: record.name,
  credits: record.credits,
  semester: record.semester,
  type: record.type,
  parity: record.parity,
  desc: record.desc,
  status: "completed",
})

function groupBySemester(
  records: CourseRecordDto[],
): Record<number, PlacedCourse[]> {
  const grouped: Record<number, PlacedCourse[]> = {}
  for (const record of records) {
    if (record.record_status !== "passed") continue
    const semester = record.semester
    grouped[semester] = [...(grouped[semester] ?? []), toPlaced(record)]
  }
  return grouped
}

export function useCourseRecords(): CourseRecordsReturn {
  const { isLoggedIn } = useSession()
  const [records, setRecords] = useState<CourseRecordDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isMutating, setIsMutating] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const loadedRef = useRef(false)

  const load = useCallback(async () => {
    setIsLoading(true)
    try {
      const response = await courseRecordService.list()
      setRecords(response.data)
      setError(null)
    } catch (caught) {
      setError(apiErrorMessage(caught, "Gagal memuat transkrip mata kuliah"))
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    if (!isLoggedIn) {
      loadedRef.current = false
      setRecords([])
      setIsLoading(false)
      return
    }
    if (loadedRef.current) return
    loadedRef.current = true
    void load()
  }, [isLoggedIn, load])

  const markPassed = useCallback(
    async (code: string, grade: string) => {
      setIsMutating(true)
      try {
        await courseRecordService.markPassed({
          course_code: code,
          final_grade: grade,
        })
        await load()
        return true
      } catch (caught) {
        setError(apiErrorMessage(caught, "Gagal menandai mata kuliah selesai"))
        return false
      } finally {
        setIsMutating(false)
      }
    },
    [load],
  )

  const unmarkPassed = useCallback(
    async (recordId: string) => {
      setIsMutating(true)
      try {
        await courseRecordService.remove(recordId)
        await load()
        return true
      } catch (caught) {
        setError(
          apiErrorMessage(caught, "Gagal membatalkan status lulus mata kuliah"),
        )
        return false
      } finally {
        setIsMutating(false)
      }
    },
    [load],
  )

  const completedByKey = new Map(
    records
      .filter((record) => record.record_status === "passed")
      .map((record) => [record.code, record]),
  )

  return {
    records,
    completedBySemester: groupBySemester(records),
    completedByKey,
    isLoading,
    isMutating,
    error,
    markPassed,
    unmarkPassed,
  }
}
