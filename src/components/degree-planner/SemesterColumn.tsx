import React from "react"
import {
  GripVertical,
  CheckCircle2,
  Lock,
  Clock,
  X,
  Plus,
  AlertTriangle,
  BookOpen,
} from "lucide-react"
import { cn } from "../../utils"
import { Course } from "../../data"
import { isOddSemester } from "../../domain/academics"
import { PlacedCourse, SemesterState, isCompleted, isSemLocked } from "./types"

interface PlannerCourseCardProps {
  course: PlacedCourse
  sem: number
  idx: number
  isDropTargetTop: boolean
  onDragStart: (
    e: React.DragEvent,
    course: PlacedCourse,
    sem: number,
    idx: number,
  ) => void
  onDragOver: (e: React.DragEvent, sem: number, idx: number) => void
  onDrop: (e: React.DragEvent, sem: number, idx: number) => void
  onDragEnd: () => void
  onDelete: (courseId: string, sem: number) => void
  onSelect: (course: PlacedCourse) => void
}
export function PlannerCourseCard({
  course,
  sem,
  idx,
  isDropTargetTop,
  onDragStart,
  onDragOver,
  onDrop,
  onDragEnd,
  onDelete,
  onSelect,
}: PlannerCourseCardProps) {
  const completed = isCompleted(course)
  const semLocked = isSemLocked(course)

  return (
    <div
      role="button"
      tabIndex={0}
      aria-label={`${course.name} (${course.code || course.id}), ${course.credits} SKS. Klik untuk melihat detail silabus dan prasyarat.`}
      onClick={() => onSelect(course)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault()
          onSelect(course)
        }
      }}
      onDragOver={(e) => onDragOver(e, sem, idx)}
      onDrop={(e) => onDrop(e, sem, idx)}
      className={cn(
        "p-3 rounded-lg border bg-surface flex flex-col group transition-all select-none relative focus:outline-hidden focus-visible:ring-2 focus-visible:ring-gold/60",
        completed
          ? "cursor-pointer opacity-85 hover:shadow-md"
          : "cursor-pointer hover:shadow-md",
        course.status === "completed" && "border-teal-light/50",
        course.status === "planned" && !semLocked && "border-gold/50",
        course.status === "planned" && semLocked && "border-navy/20",
        isDropTargetTop && "border-t-2 border-t-teal shadow-md",
      )}
    >
      <div className="flex items-center justify-between gap-2 mb-1.5 pb-1 border-b border-border/40">
        <div className="flex items-center gap-1.5 min-w-0">
          <div
            draggable={!completed}
            onDragStart={
              !completed
                ? (e) => {
                    e.stopPropagation()
                    onDragStart(e, course, sem, idx)
                  }
                : undefined
            }
            onDragEnd={(e) => {
              e.stopPropagation()
              onDragEnd()
            }}
            onClick={(e) => e.stopPropagation()}
            className={cn(
              "flex-shrink-0 w-6 h-6 -ml-1 rounded flex items-center justify-center transition-all",
              completed
                ? "cursor-default text-teal"
                : "cursor-grab active:cursor-grabbing hover:bg-navy/10 text-muted/60 hover:text-navy",
            )}
            title={
              completed
                ? "Mata kuliah sudah lulus (terkunci)"
                : "Tarik titik-titik ini untuk memindahkan mata kuliah"
            }
          >
            {completed ? (
              <CheckCircle2 className="w-3.5 h-3.5 text-teal" />
            ) : (
              <GripVertical className="w-4 h-4" />
            )}
          </div>
          <span className="font-mono text-[11px] font-bold text-navy leading-none tracking-tight">
            {course.code || course.id}
          </span>
        </div>

        <div
          className={cn(
            "flex items-center gap-1.5 flex-shrink-0 transition-opacity duration-150",
            !completed && "group-hover:opacity-0 pointer-events-none",
          )}
        >
          <span
            className={cn(
              "text-[8px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded leading-none flex items-center gap-1",
              course.type === "Wajib"
                ? "bg-navy/8 text-navy"
                : "bg-gold/15 text-navy",
            )}
          >
            {course.type === "Wajib" && (
              <Lock className="w-2.5 h-2.5 text-navy/70" />
            )}
            {course.type}
          </span>

          {course.status === "completed" && (
            <span className="text-[8px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded bg-teal/15 text-navy leading-none flex items-center gap-1 font-medium">
              Lulus
            </span>
          )}
          {course.status === "planned" && !completed && (
            <Clock className="w-3.5 h-3.5 text-gold flex-shrink-0" />
          )}
        </div>
      </div>

      <h5 className="font-medium text-xs leading-snug text-foreground mb-1.5 line-clamp-2">
        {course.name}
      </h5>

      <div className="flex items-center justify-between text-[10px] text-muted font-mono">
        <span>{course.credits} SKS</span>
        {course.program && (
          <span className="text-[9px] text-muted/70 truncate max-w-[120px]">
            {course.program}
          </span>
        )}
      </div>

      {/* Delete button — available for all non-completed courses, zero overlap with status icon */}
      {!completed && (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation()
            onDelete(course.id, sem)
          }}
          title="Hapus dari rencana semester"
          className="absolute top-2 right-2 w-5 h-5 flex items-center justify-center rounded-full bg-background border border-border text-muted hover:bg-danger/10 hover:text-danger hover:border-danger/30 opacity-0 group-hover:opacity-100 transition-all z-10 cursor-pointer shadow-2xs"
        >
          <X className="w-3 h-3" />
        </button>
      )}
    </div>
  )
}

interface SemesterColumnProps {
  sem: number
  courses: PlacedCourse[]
  completedCourses?: PlacedCourse[]
  state: SemesterState
  dragging: {
    course: PlacedCourse
    fromSem: number | "bank"
    fromIndex?: number
  } | null
  dropTarget: {
    sem: number
    index: number
  } | null
  onDragOverColumn: (e: React.DragEvent, sem: number) => void
  onDropColumn: (e: React.DragEvent, sem: number) => void
  onDragLeaveColumn: (e: React.DragEvent) => void
  onCardDragStart: (
    e: React.DragEvent,
    course: PlacedCourse,
    sem: number,
    idx: number,
  ) => void
  onCardDragOver: (e: React.DragEvent, sem: number, idx: number) => void
  onCardDrop: (e: React.DragEvent, sem: number, idx: number) => void
  onDragEnd: () => void
  onDeleteCourse: (courseId: string, sem: number) => void
  onOpenManualPicker: (sem: number) => void
  onSelectCourse: (course: PlacedCourse) => void
}

export function SemesterColumn({
  sem,
  courses,
  completedCourses = [],
  state,
  dragging,
  dropTarget,
  onDragOverColumn,
  onDropColumn,
  onDragLeaveColumn,
  onCardDragStart,
  onCardDragOver,
  onCardDrop,
  onDragEnd,
  onDeleteCourse,
  onOpenManualPicker,
  onSelectCourse,
}: SemesterColumnProps) {
  const totalSKS = [...completedCourses, ...courses].reduce(
    (acc, c) => acc + c.credits,
    0,
  )
  const odd = isOddSemester(sem)
  return (
    <div
      className={cn(
        "w-[256px] rounded-xl flex flex-col flex-shrink-0 border transition-all duration-150",
        state === "idle" && "bg-background border-border",
        state === "valid-hover" &&
          "bg-teal/5 border-teal ring-2 ring-teal/25 shadow-lg",
        state === "invalid" && "bg-foreground/3 border-border/70 opacity-55",
        state === "invalid-hover" && "bg-danger/5 border-danger/40",
      )}
      onDragOver={(e) => onDragOverColumn(e, sem)}
      onDrop={(e) => onDropColumn(e, sem)}
      onDragLeave={onDragLeaveColumn}
    >
      <div
        className={cn(
          "p-3 border-b rounded-t-xl flex justify-between items-center transition-colors",
          state === "valid-hover"
            ? "bg-teal/10 border-teal/30"
            : "bg-surface border-border",
        )}
      >
        <div className="flex items-center gap-2">
          <h4 className="font-heading font-bold text-navy text-sm">
            Semester {sem}
          </h4>
          <span
            className={cn(
              "text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full",
              odd ? "bg-teal/10 text-navy" : "bg-gold/10 text-navy",
            )}
          >
            {odd ? "Ganjil" : "Genap"}
          </span>
        </div>
        <span className="text-[10px] font-mono font-bold text-muted bg-background px-2 py-0.5 rounded">
          {totalSKS} SKS
        </span>
      </div>

      {(state === "invalid" || state === "invalid-hover") && dragging && (
        <div
          className={cn(
            "mx-2 mt-2 p-2 rounded-lg flex items-center gap-1.5 text-[11px] font-medium",
            state === "invalid-hover"
              ? "bg-danger/10 text-danger border border-danger/25"
              : "bg-muted/8 text-muted",
          )}
        >
          <AlertTriangle className="w-3.5 h-3.5 flex-shrink-0" />
          {isSemLocked(dragging.course)
            ? `Khusus Semester ${dragging.fromSem}`
            : `Hanya semester ${
                dragging.course.parity === "odd" ? "ganjil" : "genap"
              }`}
        </div>
      )}

      <div className="flex-1 p-3 space-y-2 overflow-y-auto min-h-[200px]">
        {completedCourses.map((course) => (
          <PlannerCourseCard
            key={course.id}
            course={course}
            sem={sem}
            idx={0}
            isDropTargetTop={false}
            onDragStart={onCardDragStart}
            onDragOver={onCardDragOver}
            onDrop={onCardDrop}
            onDragEnd={onDragEnd}
            onDelete={onDeleteCourse}
            onSelect={onSelectCourse}
          />
        ))}

        {courses.map((course, idx) => (
          <PlannerCourseCard
            key={course.id}
            course={course}
            sem={sem}
            idx={idx}
            isDropTargetTop={
              dropTarget?.sem === sem && dropTarget?.index === idx
            }
            onDragStart={onCardDragStart}
            onDragOver={onCardDragOver}
            onDrop={onCardDrop}
            onDragEnd={onDragEnd}
            onDelete={onDeleteCourse}
            onSelect={onSelectCourse}
          />
        ))}

        {courses.length === 0 && completedCourses.length === 0 && (
          <div
            className={cn(
              "h-[160px] flex flex-col items-center justify-center border-2 border-dashed rounded-lg p-3 text-center transition-colors",
              state === "valid-hover"
                ? "border-teal/50 bg-teal/5 text-navy"
                : "border-border text-muted",
            )}
          >
            <p className="text-xs">
              {state === "valid-hover"
                ? "Lepaskan di sini"
                : "Tarik matkul ke sini"}
            </p>
          </div>
        )}
      </div>

      <div className="p-3 border-t border-border bg-surface rounded-b-xl flex-shrink-0">
        <button
          type="button"
          onClick={() => onOpenManualPicker(sem)}
          className="w-full py-1.5 text-xs font-semibold text-navy bg-navy/5 hover:bg-navy/10 rounded-lg border border-dashed border-navy/20 transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
        >
          <Plus className="w-3.5 h-3.5" />
          Tambah Manual
        </button>
      </div>
    </div>
  )
}

interface ElectiveCourseBankProps {
  pendingCourses: Course[]
  onDragStartBank: (e: React.DragEvent, course: PlacedCourse) => void
  onDragEnd: () => void
  onSelectCourse?: (course: PlacedCourse) => void
}

export function ElectiveCourseBank({
  pendingCourses,
  onDragStartBank,
  onDragEnd,
  onSelectCourse,
}: ElectiveCourseBankProps) {
  const pilihanPending = pendingCourses.filter((c) => c.type === "Pilihan")
  if (pilihanPending.length === 0) return null

  return (
    <div className="border-t border-border pt-4 mt-3 flex-shrink-0">
      <div className="flex items-center gap-3 mb-3">
        <BookOpen className="w-4 h-4 text-navy" />
        <h4 className="font-heading font-bold text-sm text-navy">
          Bank Matkul Pilihan
        </h4>
        <span className="text-xs font-mono text-muted bg-background border border-border px-2 py-0.5 rounded">
          {pilihanPending.length} matkul
        </span>
        <p className="text-xs text-muted">(Tarik ke semester yang sesuai)</p>
      </div>
      <div className="flex gap-3 overflow-x-auto pb-2">
        {pilihanPending.map((course) => (
          <div
            key={course.id}
            onClick={() =>
              onSelectCourse?.({
                ...course,
                status: "planned",
              } as PlacedCourse)
            }
            className="bg-surface rounded-xl border border-gold/40 p-3 cursor-pointer flex-shrink-0 w-[196px] group hover:shadow-md hover:border-gold transition-all select-none focus:outline-hidden focus-visible:ring-2 focus-visible:ring-gold"
          >
            <div className="flex items-start justify-between mb-1">
              <span className="font-mono text-[10px] font-bold text-teal">
                {course.code || course.id}
              </span>
              <div
                draggable
                onDragStart={(e) => {
                  e.stopPropagation()
                  onDragStartBank(e, {
                    ...course,
                    status: "planned",
                  } as PlacedCourse)
                }}
                onDragEnd={(e) => {
                  e.stopPropagation()
                  onDragEnd()
                }}
                onClick={(e) => e.stopPropagation()}
                className="cursor-grab active:cursor-grabbing p-1 -m-1 rounded hover:bg-navy/10 text-muted hover:text-navy transition-all"
                title="Tarik untuk memindahkan ke semester"
              >
                <GripVertical className="w-3.5 h-3.5" />
              </div>
            </div>
            <h5 className="font-medium text-xs text-navy leading-tight">
              {course.name}
            </h5>
            <div className="flex items-center gap-2 mt-2">
              <span className="text-[10px] text-muted">
                {course.credits} SKS
              </span>
              <span
                className={cn(
                  "text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ml-auto",
                  course.parity === "odd"
                    ? "bg-teal/10 text-navy"
                    : "bg-gold/10 text-navy",
                )}
              >
                {course.parity === "odd" ? "Ganjil" : "Genap"}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
