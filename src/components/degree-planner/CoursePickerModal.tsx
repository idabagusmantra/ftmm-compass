import { Search, X, BookOpen, Check, Plus } from "lucide-react"
import { cn } from "../../utils"
import { Course } from "../../data"
import { isOddSemester, MAX_SKS_PER_SEMESTER } from "../../domain/academics"
import { courseReligion } from "../../domain/course"
import { PlacedCourse, courseKey } from "./types"
import ModalShell from "../course/ModalShell"
import CourseBadges from "../course/CourseBadges"

interface CoursePickerModalProps {
  pickerSem: number | null
  pickerSearch: string
  setPickerSearch: (q: string) => void
  currentProgram: string | null
  pickerType: "all" | "Pilihan" | "Wajib"
  setPickerType: (t: "all" | "Pilihan" | "Wajib") => void
  catalog: Course[]
  placedMap: Map<string, number>
  completedKeys?: Set<string>
  onClose: () => void
  onAddCourse: (course: Course) => void
  currentSemesterCourses?: PlacedCourse[]
  activeReligion?: string | null
}

export default function CoursePickerModal({
  pickerSem,
  pickerSearch,
  setPickerSearch,
  currentProgram,
  pickerType,
  setPickerType,
  catalog,
  placedMap,
  completedKeys,
  onClose,
  onAddCourse,
  currentSemesterCourses,
  activeReligion,
}: CoursePickerModalProps) {
  if (pickerSem === null) return null

  const q = pickerSearch.toLowerCase().trim()
  const plannedSKS = (currentSemesterCourses || [])
    .filter((c) => c.status === "planned" || c.status === "completed")
    .reduce((sum, c) => sum + c.credits, 0)

  const basePool = catalog.filter((c) => {
    if (c.semester !== pickerSem) return false
    if (currentProgram && c.program !== currentProgram) return false
    if (q) {
      const matchName = c.name.toLowerCase().includes(q)
      const matchId = c.id.toLowerCase().includes(q)
      const matchCode = c.code ? c.code.toLowerCase().includes(q) : false
      if (!matchName && !matchId && !matchCode) return false
    }
    return true
  })

  const pilihanCount = basePool.filter((c) => c.type === "Pilihan").length
  const wajibCount = basePool.filter((c) => c.type === "Wajib").length

  const filtered = basePool
    .filter((c) => (pickerType === "all" ? true : c.type === pickerType))
    .sort((a, b) => a.name.localeCompare(b.name))

  return (
    <ModalShell
      onClose={onClose}
      labelledBy="course-picker-title"
      overlayClassName="bg-navy-dark/60 animate-in fade-in duration-200"
      panelClassName="bg-surface border border-border rounded-2xl shadow-2xl max-w-2xl w-full max-h-[85vh] flex flex-col overflow-hidden animate-in zoom-in-95 duration-200"
    >
      <div className="p-5 border-b border-border flex items-start justify-between bg-background/50">
        <div>
          <div className="flex items-center gap-2">
            <h3
              id="course-picker-title"
              className="font-heading font-bold text-lg text-navy"
            >
              Tambah Matkul ke Semester {pickerSem}
            </h3>
            <span
              className={cn(
                "text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full",
                isOddSemester(pickerSem)
                  ? "bg-teal/15 text-navy border border-teal/30"
                  : "bg-gold/15 text-navy border border-gold/40",
              )}
            >
              {isOddSemester(pickerSem) ? "Semester Ganjil" : "Semester Genap"}
            </span>
          </div>
          <p className="text-xs text-muted mt-1">
            Menampilkan katalog matkul dengan periode{" "}
            <strong>{isOddSemester(pickerSem) ? "ganjil" : "genap"}</strong>{" "}
            sesuai aturan kurikulum FTMM.
          </p>
          <div className="flex flex-wrap items-center gap-2 mt-2 pt-1 border-t border-border/40">
            <span className="text-xs text-muted font-medium">
              Beban SKS Sem {pickerSem}:
            </span>
            <span
              className={cn(
                "font-mono font-bold text-xs px-2 py-0.5 rounded-md",
                plannedSKS > MAX_SKS_PER_SEMESTER
                  ? "bg-danger/15 text-danger border border-danger/30"
                  : plannedSKS >= 20
                    ? "bg-gold/15 text-navy border border-gold/30"
                    : "bg-teal/15 text-navy border border-teal/30",
              )}
            >
              {plannedSKS} / {MAX_SKS_PER_SEMESTER} SKS Direncanakan
            </span>
            {activeReligion && (
              <span className="text-[10px] font-medium text-navy/80 bg-navy/8 border border-navy/15 px-2 py-0.5 rounded-md">
                Agama Terpilih: <strong>{activeReligion}</strong>
              </span>
            )}
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="p-1.5 rounded-lg text-muted hover:text-navy hover:bg-navy/5 transition-colors cursor-pointer"
          aria-label="Tutup modal"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      <div className="p-4 border-b border-border bg-surface space-y-3">
        <div className="flex flex-col sm:flex-row gap-2">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-muted absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={pickerSearch}
              onChange={(e) => setPickerSearch(e.target.value)}
              placeholder="Cari nama matkul atau kode (misal: Data, II40, Fisika)..."
              className="w-full pl-9 pr-8 py-2 text-xs rounded-lg border border-border bg-background focus:outline-hidden focus:ring-2 focus:ring-teal/30 focus:border-teal text-foreground"
              autoFocus
            />
            {pickerSearch && (
              <button
                type="button"
                onClick={() => setPickerSearch("")}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted hover:text-navy cursor-pointer"
                aria-label="Hapus pencarian"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
          <div
            role="group"
            aria-label="Filter tipe mata kuliah"
            className="flex items-center gap-1 bg-background p-1 rounded-lg border border-border"
          >
            {([
              {
                key: "all",
                label: "Semua Tipe",
                count: basePool.length,
              },
              {
                key: "Pilihan",
                label: "Pilihan",
                count: pilihanCount,
              },
              {
                key: "Wajib",
                label: `Wajib Sem ${pickerSem}`,
                count: wajibCount,
              },
            ] as const).map((t) => (
              <button
                key={t.key}
                type="button"
                onClick={() => setPickerType(t.key)}
                className={cn(
                  "px-2.5 py-1 rounded-md text-[11px] font-medium transition-all flex items-center gap-1.5 cursor-pointer",
                  pickerType === t.key
                    ? "bg-navy text-white shadow-2xs font-semibold"
                    : "text-muted hover:text-navy",
                )}
              >
                <span>{t.label}</span>
                <span
                  className={cn(
                    "text-[9px] font-mono px-1.5 py-0.2 rounded-full",
                    pickerType === t.key
                      ? "bg-white/20 text-white"
                      : "bg-surface text-muted border border-border",
                  )}
                >
                  {t.count}
                </span>
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-2.5 min-h-[220px]">
        {filtered.length === 0 ? (
          <div className="h-44 flex flex-col items-center justify-center text-center p-6 border-2 border-dashed border-border rounded-xl">
            <BookOpen className="w-8 h-8 text-muted/40 mb-2" />
            <p className="text-sm font-medium text-navy">
              Tidak ada mata kuliah yang cocok
            </p>
            <p className="text-xs text-muted mt-1">
              Coba ubah kata kunci pencarian atau filter tipe matkul.
            </p>
          </div>
        ) : (
          filtered.map((course) => {
            const placedInSem = placedMap.get(courseKey(course))
            const isCompleted = completedKeys?.has(courseKey(course)) ?? false
            const isAlreadyPlaced = placedInSem !== undefined
            const religion = courseReligion(course)
            const isReligionBlocked = Boolean(
              activeReligion &&
                religion &&
                religion !== "Umum" &&
                religion !== activeReligion,
            )
            return (
              <div
                key={course.id}
                className={cn(
                  "p-3 rounded-xl border flex items-center justify-between gap-3 transition-all",
                  isAlreadyPlaced
                    ? "bg-background/40 border-border/60 opacity-60"
                    : isReligionBlocked
                      ? "bg-background/40 border-border/60 opacity-55"
                      : "bg-surface border-border hover:border-gold/60 hover:shadow-2xs",
                )}
              >
                <div className="min-w-0 flex-1">
                  <div className="mb-1">
                    <CourseBadges course={course}>
                      {isCompleted && (
                        <span className="text-[9px] font-bold bg-teal/15 text-navy border border-teal/30 px-1.5 py-0.5 rounded">
                          Lulus (Terkunci)
                        </span>
                      )}
                      {isReligionBlocked && (
                        <span className="text-[9px] font-bold bg-amber-100 text-amber-900 border border-amber-300 px-1.5 py-0.5 rounded">
                          Terkunci: Agama {activeReligion}
                        </span>
                      )}
                    </CourseBadges>
                  </div>
                  <h4 className="font-medium text-sm text-foreground leading-tight truncate">
                    {course.name}
                  </h4>
                </div>

                <div className="flex-shrink-0">
                  {isAlreadyPlaced ? (
                    <span className="px-2.5 py-1.5 rounded-lg text-xs font-mono font-medium text-muted bg-background border border-border flex items-center gap-1.5">
                      <Check className="w-3.5 h-3.5 text-teal" />
                      {isCompleted ? "Sudah lulus" : `Di Sem ${placedInSem}`}
                    </span>
                  ) : isReligionBlocked ? (
                    <span
                      className="px-2.5 py-1.5 rounded-lg text-xs font-medium text-muted bg-background border border-border flex items-center gap-1"
                      title={`Sudah mengambil mata kuliah Agama ${activeReligion}. Maksimal 1 jenis agama per mahasiswa.`}
                    >
                      Agama Lain
                    </span>
                  ) : (
                    <button
                      type="button"
                      onClick={() => onAddCourse(course)}
                      className="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-colors shadow-2xs cursor-pointer bg-navy text-white hover:bg-navy-light"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      Tambah
                    </button>
                  )}
                </div>
              </div>
            )
          })
        )}
      </div>

      <div className="p-3 px-5 border-t border-border bg-background flex justify-between items-center text-xs text-muted">
        <span>
          Tekan <strong>Esc</strong> atau klik di luar untuk menutup
        </span>
        <button
          type="button"
          onClick={onClose}
          className="px-3 py-1.5 rounded-lg border border-border hover:bg-surface font-medium text-navy transition-colors cursor-pointer"
        >
          Selesai
        </button>
      </div>
    </ModalShell>
  )
}
