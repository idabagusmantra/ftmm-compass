import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react"
import type { Course, ScheduleItem } from "../data"
import type { DegreePlanPayload } from "../domain/plan"
import { useDegreeDrafts, type DegreeDraftsReturn } from "./degreeDrafts"
import { useCourseRecords, type CourseRecordsReturn } from "./courseRecords"
import type { PlacedCourse } from "../components/degree-planner/types"
import { parityOfSemester } from "../domain/academics"
import { normalizeCourseType } from "../domain/course"

interface PlannerContextValue
  extends DegreeDraftsReturn,
    CourseRecordsReturn {
    /** Jadwal yang sedang ditampilkan planner; dashboard merender ini bila terisi. */
    /** Menulis rencana AI ke draft aktif, menyimpan rencana sebelumnya untuk reset. */
  pendingCourses: Course[]
  addPendingCourse: (course: Course) => void
  removePendingCourse: (courseId: string) => void
  appliedSummary: DegreePlanPayload["summary"] | null
  schedule: ScheduleItem[]
  setSchedule: (schedule: ScheduleItem[]) => void
  applyPlan: (payload: DegreePlanPayload) => void
  resetPlan: () => void
}

const PlannerContext = createContext<PlannerContextValue | null>(null)

function planFromPayload(
  payload: DegreePlanPayload,
): Record<number, PlacedCourse[]> {
  const plan: Record<number, PlacedCourse[]> = {}
  for (const [key, items] of Object.entries(payload.plan)) {
    const semester = Number(key)
    plan[semester] = (items || []).map((item) => {
      const placement = item.semester ?? semester
      return {
        id: item.id || item.code || `${item.name}-${semester}`,
        code: item.code,
        name: item.name,
        credits: item.credits ?? 3,
        semester: placement,
        type: normalizeCourseType(item.type),
        parity:
          item.parity === "odd" || item.parity === "even"
            ? item.parity
            : parityOfSemester(placement),
        desc: "",
        prerequisites: [],
        status: "planned",
      }
    })
  }
  return plan
}

export function PlannerProvider({ children }: { children: ReactNode }) {
  const storage = useDegreeDrafts()
  const courseRecords = useCourseRecords()
  const [pendingCourses, setPendingCourses] = useState<Course[]>([])
  const [appliedSummary, setAppliedSummary] =
    useState<DegreePlanPayload["summary"] | null>(null)
  const [schedule, setSchedule] = useState<ScheduleItem[]>([])
  const planRef = useRef(storage.plan)
  planRef.current = storage.plan
  const preApplyRef = useRef<Record<number, PlacedCourse[]> | null>(null)
  const { setPlan, resetCurrentDraft } = storage

  const addPendingCourse = useCallback((course: Course) => {
    setPendingCourses((prev) =>
      prev.some((item) => item.id === course.id) ? prev : [...prev, course],
    )
  }, [])

  const removePendingCourse = useCallback((courseId: string) => {
    setPendingCourses((prev) => prev.filter((item) => item.id !== courseId))
  }, [])

  const applyPlan = useCallback(
    (payload: DegreePlanPayload) => {
      preApplyRef.current = planRef.current
      setAppliedSummary(payload.summary)
      setPlan(planFromPayload(payload))
    },
    [setPlan],
  )

  const resetPlan = useCallback(() => {
    if (preApplyRef.current) {
      setPlan(preApplyRef.current)
      preApplyRef.current = null
    } else {
      resetCurrentDraft()
    }
    setAppliedSummary(null)
  }, [resetCurrentDraft, setPlan])

  const value = useMemo(
    () => ({
      ...storage,
      ...courseRecords,
      pendingCourses,
      addPendingCourse,
      removePendingCourse,
      appliedSummary,
      applyPlan,
      resetPlan,
      schedule,
      setSchedule,
    }),
    [
      storage,
      courseRecords,
      pendingCourses,
      addPendingCourse,
      removePendingCourse,
      appliedSummary,
      applyPlan,
      resetPlan,
      schedule,
    ],
  )

  return (
    <PlannerContext.Provider value={value}>{children}</PlannerContext.Provider>
  )
}

export function usePlanner(): PlannerContextValue {
  const context = useContext(PlannerContext)
  if (!context) {
    throw new Error("usePlanner harus dipakai di dalam PlannerProvider")
  }
  return context
}
