import { useState } from "react"
import {
  X,
  BookOpen,
  Clock,
  CheckCircle2,
  AlertTriangle,
  ExternalLink,
  Trash2,
  GraduationCap,
  Layers,
} from "lucide-react"
import { cn } from "../../utils"
import { isOddSemester } from "../../domain/academics"
import { PlacedCourse, isCompleted } from "./types"
import { evaluatePrerequisites } from "../../domain/prerequisites"
import ModalShell from "../course/ModalShell"
import CourseBadges from "../course/CourseBadges"
import WorkloadGrid from "../course/WorkloadGrid"

interface CourseInspectModalProps {
  course: PlacedCourse | null
  currentSem: number
  allPlan: Record<number, PlacedCourse[]>
  onClose: () => void
  onDeleteCourse?: (courseId: string, sem: number) => void
  onOpenInCourseFinder?: (course: PlacedCourse) => void
  onMarkPassed?: (course: PlacedCourse, grade: string) => Promise<boolean>
  onUnmarkPassed?: (recordId: string) => Promise<boolean>
  isMutatingRecord?: boolean
  completedGrade?: string | null
}

const PASSING_GRADES = ["A", "AB", "B", "BC", "C", "D"]

export default function CourseInspectModal({
  course,
  currentSem,
  allPlan,
  onClose,
  onDeleteCourse,
  onOpenInCourseFinder,
  onMarkPassed,
  onUnmarkPassed,
  isMutatingRecord,
  completedGrade,
}: CourseInspectModalProps) {
  const [grade, setGrade] = useState("A")
  const [actionError, setActionError] = useState<string | null>(null)

  if (!course) return null

  const completed = isCompleted(course)

  const evaluatedPrereqs = evaluatePrerequisites(course, allPlan, currentSem)
  const hasPrereqIssues = evaluatedPrereqs.some(
    (item) => item.status === "missing" || item.status === "warning",
  )

  return (
    <ModalShell
      onClose={onClose}
      labelledBy="course-inspect-title"
      overlayClassName="bg-navy-dark/60 animate-in fade-in duration-200"
      panelClassName="bg-surface border border-border rounded-2xl shadow-2xl max-w-xl w-full max-h-[90vh] flex flex-col overflow-hidden animate-in zoom-in-95 duration-200"
    >
      <div className="p-5 border-b border-border bg-background/50 flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="mb-1.5">
            <CourseBadges course={course} />
          </div>

          <h3
            id="course-inspect-title"
            className="font-heading font-bold text-lg text-foreground leading-snug"
          >
            {course.name}
          </h3>

          <p className="text-xs text-muted mt-1 flex items-center gap-2">
            <span>
              {course.program || "Fakultas Teknologi Maju dan Multidisiplin"}
            </span>
            <span>&bull;</span>
            <span className="font-medium text-navy">
              Penempatan: Semester {currentSem} (
              {isOddSemester(currentSem) ? "Ganjil" : "Genap"})
            </span>
          </p>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="p-1.5 rounded-lg text-muted hover:text-navy hover:bg-navy/5 transition-colors cursor-pointer flex-shrink-0"
          aria-label="Tutup jendela informasi mata kuliah"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-5 space-y-5">
        <div className="grid grid-cols-3 gap-3">
          <div className="bg-background rounded-xl p-3 border border-border">
            <span className="text-[10px] font-medium text-muted block mb-1">
              Bobot SKS
            </span>
            <span className="font-heading font-bold text-base text-navy flex items-center gap-1.5">
              <Clock className="w-4 h-4 text-gold" />
              {course.credits} SKS
            </span>
          </div>

          <div className="bg-background rounded-xl p-3 border border-border">
            <span className="text-[10px] font-medium text-muted block mb-1">
              Term Kurikulum
            </span>
            <span className="font-heading font-bold text-base text-navy flex items-center gap-1.5">
              <Layers className="w-4 h-4 text-teal" />
              Sem {course.semester} (
              {course.parity === "odd" ? "Ganjil" : "Genap"})
            </span>
          </div>

          <div className="bg-background rounded-xl p-3 border border-border">
            <span className="text-[10px] font-medium text-muted block mb-1">
              Status Rencana
            </span>
            <span
              className={cn(
                "font-heading font-bold text-xs uppercase px-2 py-1 rounded inline-flex items-center gap-1",
                course.status === "completed"
                  ? "bg-teal/15 text-navy"
                  : "bg-gold/15 text-navy",
              )}
            >
              {course.status === "completed" ? "Lulus" : "Direncanakan"}
            </span>
          </div>
        </div>

        {(onMarkPassed || onUnmarkPassed) && (
          <div className="rounded-xl border border-border bg-background p-3.5">
            {completed ? (
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="text-xs text-navy">
                  Tercatat <strong>lulus</strong>
                  {completedGrade ? (
                    <>
                      {" "}
                      dengan nilai <strong>{completedGrade}</strong>
                    </>
                  ) : null}
                  . Mata kuliah ini terkunci dari perubahan rencana.
                </span>
                {onUnmarkPassed && (
                  <button
                    type="button"
                    disabled={isMutatingRecord}
                    onClick={async () => {
                      setActionError(null)
                      const ok = await onUnmarkPassed(course.id)
                      if (!ok) {
                        setActionError(
                          "Gagal membatalkan status lulus mata kuliah.",
                        )
                      }
                    }}
                    className="px-3 py-1.5 text-xs font-medium rounded-lg text-orange hover:bg-orange/10 border border-border transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Batalkan status lulus
                  </button>
                )}
              </div>
            ) : (
              onMarkPassed && (
                <div className="flex flex-wrap items-center gap-2">
                  <label
                    htmlFor="record-grade"
                    className="text-xs font-medium text-navy"
                  >
                    Nilai akhir
                  </label>
                  <select
                    id="record-grade"
                    value={grade}
                    onChange={(e) => setGrade(e.target.value)}
                    disabled={isMutatingRecord}
                    className="text-xs font-mono font-semibold px-2 py-1.5 rounded-lg bg-surface border border-border text-navy focus:outline-none focus:ring-1 focus:ring-navy cursor-pointer"
                  >
                    {PASSING_GRADES.map((option) => (
                      <option key={option} value={option}>
                        {option}
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    disabled={isMutatingRecord}
                    onClick={async () => {
                      setActionError(null)
                      const ok = await onMarkPassed(course, grade)
                      if (!ok) {
                        setActionError(
                          "Gagal menandai mata kuliah selesai. Pastikan backend aktif lalu coba lagi.",
                        )
                      }
                    }}
                    className="px-3 py-1.5 text-xs font-semibold rounded-lg bg-navy text-white hover:bg-navy-light transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isMutatingRecord ? "Menyimpan..." : "Tandai Selesai"}
                  </button>
                  <span className="text-[11px] text-muted">
                    Mata kuliah yang selesai akan terkunci di semester
                    kurikulumnya.
                  </span>
                </div>
              )
            )}
            {actionError && (
              <p className="mt-2 text-[11px] text-orange">{actionError}</p>
            )}
          </div>
        )}

        <div>
          <h4 className="font-heading font-bold text-xs uppercase tracking-wider text-muted mb-2 flex items-center gap-1.5">
            <BookOpen className="w-3.5 h-3.5 text-navy" />
            Deskripsi Silabus
          </h4>
          <p className="text-xs leading-relaxed text-foreground bg-background rounded-xl p-3.5 border border-border">
            {course.desc ||
              "Mata kuliah ini mencakup kompetensi inti pemahaman teori, analisis metode, dan studi kasus terapan sesuai kurikulum standar FTMM Universitas Airlangga."}
          </p>
        </div>

        {course.workload && (
          <div>
            <h4 className="font-heading font-bold text-xs uppercase tracking-wider text-muted mb-2 flex items-center gap-1.5">
              <GraduationCap className="w-3.5 h-3.5 text-navy" />
              Distribusi Jam & Beban Belajar
            </h4>
            <WorkloadGrid workload={course.workload} />
          </div>
        )}

        <div>
          <div className="flex items-center justify-between mb-2">
            <h4 className="font-heading font-bold text-xs uppercase tracking-wider text-muted flex items-center gap-1.5">
              <CheckCircle2 className="w-3.5 h-3.5 text-navy" />
              Validasi Prasyarat Akademik
            </h4>
            <span className="text-[10px] font-mono text-muted">
              {evaluatedPrereqs.length} Prasyarat
            </span>
          </div>

          {evaluatedPrereqs.length === 0 ? (
            <div className="p-3 rounded-xl bg-teal/5 border border-teal/20 text-navy text-xs flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-teal flex-shrink-0" />
              <span>
                Tidak ada mata kuliah prasyarat wajib untuk mengambil mata
                kuliah ini.
              </span>
            </div>
          ) : (
            <div className="space-y-2">
              {evaluatedPrereqs.map((item, idx) => (
                <div
                  key={`${item.node.id}-${idx}`}
                  className={cn(
                    "p-3 rounded-xl border text-xs flex items-start justify-between gap-3 transition-colors",
                    item.status === "satisfied" &&
                      "bg-teal/5 border-teal/30 text-navy",
                    item.status === "warning" &&
                      "bg-warning/10 border-warning/30 text-navy",
                    item.status === "missing" &&
                      "bg-danger/5 border-danger/30 text-danger",
                    item.status === "administrative" &&
                      "bg-navy/5 border-navy/20 text-navy",
                  )}
                >
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-[11px]">
                        {item.node.id}
                      </span>
                      <span className="font-medium text-foreground">
                        {item.node.name}
                      </span>
                    </div>
                    <p className="text-[11px] opacity-80 mt-0.5">
                      {item.detail}
                    </p>
                  </div>

                  <span className="flex-shrink-0 mt-0.5">
                    {item.status === "satisfied" && (
                      <CheckCircle2 className="w-4 h-4 text-teal" />
                    )}
                    {item.status === "warning" && (
                      <AlertTriangle className="w-4 h-4 text-warning" />
                    )}
                    {item.status === "missing" && (
                      <AlertTriangle className="w-4 h-4 text-danger" />
                    )}
                    {item.status === "administrative" && (
                      <CheckCircle2 className="w-4 h-4 text-navy/60" />
                    )}
                  </span>
                </div>
              ))}

              {hasPrereqIssues && (
                <p className="text-[11px] text-danger/90 italic mt-1">
                  * Perhatian: Mengambil matkul sebelum prasyarat selesai
                  berpotensi melanggar aturan KRS FTMM.
                </p>
              )}
            </div>
          )}
        </div>
      </div>

      <div className="p-4 border-t border-border bg-background/50 flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          {!completed && onDeleteCourse && (
            <button
              type="button"
              onClick={() => {
                onDeleteCourse(course.id, currentSem)
                onClose()
              }}
              className="px-3 py-1.5 text-xs font-medium rounded-lg text-danger hover:bg-danger/10 border border-transparent hover:border-danger/20 transition-colors flex items-center gap-1.5 cursor-pointer"
            >
              <Trash2 className="w-3.5 h-3.5" />
              Hapus
            </button>
          )}
        </div>

        <div className="flex items-center gap-2 ml-auto">
          {onOpenInCourseFinder && (
            <button
              type="button"
              onClick={() => {
                onOpenInCourseFinder(course)
                onClose()
              }}
              className="px-3 py-1.5 text-xs font-semibold rounded-lg bg-navy text-white hover:bg-navy-light shadow-2xs transition-colors flex items-center gap-1.5 cursor-pointer"
            >
              <span>Buka di Course Finder</span>
              <ExternalLink className="w-3.5 h-3.5 text-gold" />
            </button>
          )}

          <button
            type="button"
            onClick={onClose}
            className="px-3 py-1.5 text-xs font-medium rounded-lg text-muted hover:text-navy hover:bg-navy/5 transition-colors cursor-pointer"
          >
            Tutup
          </button>
        </div>
      </div>
    </ModalShell>
  )
}
