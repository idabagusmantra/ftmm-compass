import { type AuthUser } from "../../services/authService"
import {
  Sparkles,
  RotateCcw,
  CheckCircle2,
  Lock,
  Clock,
  GripVertical,
  FolderGit2,
  Copy,
  Plus,
  Trash2,
} from "lucide-react"
import { PlacedCourse, isSemLocked } from "./types"
import type { DegreePlanDraft } from "../../domain/plan"

interface PlannerHeaderProps {
  appliedSummary?: {
    program_studi: string
    total_credits: number
    target_semester: number
    focus_tracks: string[]
    note?: string
  } | null
  onResetPlan?: () => void
  dragging: {
    course: PlacedCourse
    fromSem: number | "bank"
    fromIndex?: number
  } | null
  currentUser?: AuthUser | null
  drafts?: DegreePlanDraft[]
  activeDraftId?: string
  onSwitchDraft?: (draftId: string) => void
  onCreateDraft?: (name: string) => void
  onDuplicateDraft?: () => void
  onDeleteDraft?: (draftId: string) => void
  saveError?: string | null
  onRetrySave?: () => void
  onResetDraft?: () => void
  isSaving?: boolean
  lastSaved?: Date | null
}

const LEGEND_ITEMS = [
  {
    icon: <CheckCircle2 className="w-3.5 h-3.5 text-teal" />,
    label: "Selesai",
    badge: "Lulus (Terkunci)",
    badgeStyle: "bg-teal/10 text-navy border-teal/30",
  },
  {
    icon: <Lock className="w-3.5 h-3.5 text-muted/70" />,
    label: "Wajib",
    badge: "Urutan Atas/Bawah (Tetap di Sem)",
    badgeStyle: "bg-navy/8 text-navy border-navy/20",
  },
  {
    icon: <Clock className="w-3.5 h-3.5 text-gold" />,
    label: "Direncanakan",
    badge: "Geser Sem & Atas/Bawah ⋮⋮",
    badgeStyle: "bg-gold/15 text-navy border-gold/40",
  },
] as const

export default function PlannerHeader({
  appliedSummary,
  onResetPlan,
  dragging,
  currentUser,
  drafts,
  activeDraftId,
  onSwitchDraft,
  onCreateDraft,
  onDuplicateDraft,
  onDeleteDraft,
  onResetDraft,
  isSaving,
  lastSaved,
  saveError,
  onRetrySave,
}: PlannerHeaderProps) {
  const activeDraft = drafts?.find((d) => d.id === activeDraftId)

  return (
    <>
      {appliedSummary && (
        <div className="mb-4 p-4 bg-teal/15 border border-teal/40 rounded-xl flex items-center justify-between gap-4 animate-in fade-in duration-300">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-navy text-gold rounded-lg shadow-sm">
              <Sparkles className="w-5 h-5 text-gold" />
            </div>
            <div>
              <h4 className="font-heading font-bold text-sm text-navy flex items-center gap-2">
                Rencana Studi Personalisasi Compass AI
                <span className="text-[10px] font-mono px-2 py-0.5 bg-navy text-white rounded-full">
                  {appliedSummary.program_studi}
                </span>
              </h4>
              <p className="text-xs text-muted">
                Target Lulus:{" "}
                <strong>Semester {appliedSummary.target_semester}</strong> •
                Total Beban: <strong>{appliedSummary.total_credits} SKS</strong>{" "}
                • Fokus:{" "}
                <strong>{appliedSummary.focus_tracks.join(", ")}</strong>
              </p>
            </div>
          </div>
          {onResetPlan && (
            <button
              onClick={onResetPlan}
              className="px-3 py-1.5 text-xs font-medium text-navy hover:bg-navy/10 rounded-lg transition-colors flex items-center gap-1.5 border border-navy/20 cursor-pointer"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              Reset Default
            </button>
          )}
        </div>
      )}

      {currentUser?.role === "admin" && (
        <div className="mb-3 px-3.5 py-2 rounded-xl bg-gold/15 border border-gold/40 text-navy text-xs flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-gold flex-shrink-0" />
            <span>
              <strong>Mode Administrator FTMM:</strong> Anda memiliki kewenangan
              inspeksi master kurikulum &amp; simulasi alur prasyarat 8 semester
              untuk seluruh program studi.
            </span>
          </div>
          <span className="font-mono text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-surface border border-border">
            Super Admin Access
          </span>
        </div>
      )}
      {currentUser?.role === "lecturer" && (
        <div className="mb-3 px-3.5 py-2 rounded-xl bg-navy/10 border border-navy/20 text-navy text-xs flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-teal flex-shrink-0" />
            <span>
              <strong>Mode Dosen Wali / Pembina Akademik:</strong> Anda dapat
              meninjau alur rencana studi mahasiswa, memeriksa kepatuhan
              prasyarat, dan mengevaluasi distribusi beban SKS.
            </span>
          </div>
          <span className="font-mono text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-surface border border-border">
            Advising Mode
          </span>
        </div>
      )}

      {drafts && drafts.length > 0 && (
        <div className="mb-4 p-3.5 bg-surface border border-border rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-3 shadow-2xs">
          <div className="flex flex-col sm:flex-row sm:items-center gap-3">
            <div className="flex items-center gap-2">
              <div className="p-1.5 rounded-lg bg-navy/10 text-navy">
                <FolderGit2 className="w-4 h-4" />
              </div>
              <div>
                <label
                  htmlFor="draft-selector"
                  className="text-xs font-semibold text-navy block"
                >
                  Skenario Rencana Studi
                </label>
                <span className="text-[11px] text-muted">
                  {activeDraft?.status === "active"
                    ? "Skenario aktif, tersimpan di server"
                    : "Tersimpan di server"}
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <select
                id="draft-selector"
                value={activeDraftId}
                onChange={(e) => onSwitchDraft?.(e.target.value)}
                className="text-xs font-medium px-3 py-1.5 rounded-lg bg-background border border-border text-navy focus:outline-none focus:ring-1 focus:ring-navy cursor-pointer"
              >
                {drafts.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-1.5 text-[11px] font-mono mr-1">
              {isSaving ? (
                <span className="text-warning flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-warning animate-pulse" />
                  Menyimpan...
                </span>
              ) : (
                <span className="text-muted flex items-center gap-1">
                  <CheckCircle2 className="w-3.5 h-3.5 text-teal-dark" />
                  {lastSaved
                    ? `Tersimpan ${lastSaved.toLocaleTimeString("id-ID", { hour: "2-digit", minute: "2-digit" })}`
                    : "Tersimpan di server"}
                </span>
              )}
            </div>

            {onResetDraft && (
              <button
                type="button"
                onClick={onResetDraft}
                title="Muat ulang skenario ini dari server"
                className="px-2.5 py-1 text-xs font-medium text-navy hover:bg-navy/5 rounded-lg border border-border flex items-center gap-1 cursor-pointer transition-colors"
              >
                <RotateCcw className="w-3 h-3 text-muted" />
                Reset
              </button>
            )}

            {onDeleteDraft && activeDraftId && (
              <button
                type="button"
                onClick={() => onDeleteDraft(activeDraftId)}
                disabled={(drafts?.length ?? 0) <= 1}
                title={
                  (drafts?.length ?? 0) <= 1
                    ? "Minimal satu skenario harus tersimpan"
                    : "Hapus skenario aktif"
                }
                className="px-2.5 py-1 text-xs font-medium text-orange hover:bg-orange/10 rounded-lg border border-border flex items-center gap-1 cursor-pointer transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
              >
                <Trash2 className="w-3 h-3" />
                Hapus
              </button>
            )}

            {onDuplicateDraft && (
              <button
                type="button"
                onClick={onDuplicateDraft}
                title="Salin skenario aktif sebagai draft baru"
                className="px-2.5 py-1 text-xs font-medium text-navy hover:bg-navy/5 rounded-lg border border-border flex items-center gap-1 cursor-pointer transition-colors"
              >
                <Copy className="w-3.5 h-3.5" />
                Salin Skenario
              </button>
            )}

            {onCreateDraft && (
              <button
                type="button"
                onClick={() => {
                  const name = window.prompt(
                    "Nama skenario / draft baru:",
                    `Draft ${(drafts?.length || 0) + 1}`,
                  )
                  if (name && name.trim()) {
                    onCreateDraft(name.trim())
                  }
                }}
                title="Buat skenario rencana studi baru"
                className="px-2.5 py-1 text-xs font-semibold text-white bg-navy hover:bg-navy-light rounded-lg flex items-center gap-1 cursor-pointer transition-colors shadow-2xs"
              >
                <Plus className="w-3.5 h-3.5" />
                Skenario Baru
              </button>
            )}
          </div>
        </div>
      )}

      {saveError && (
        <div className="mb-4 flex flex-col sm:flex-row sm:items-center justify-between gap-2 rounded-xl border border-orange/40 bg-orange/10 px-3.5 py-2.5">
          <span className="text-xs font-medium text-orange">{saveError}</span>
          {onRetrySave && (
            <button
              type="button"
              onClick={onRetrySave}
              className="self-start sm:self-auto px-2.5 py-1 text-xs font-semibold text-navy bg-surface border border-border rounded-lg hover:bg-navy/5 cursor-pointer transition-colors"
            >
              Coba lagi
            </button>
          )}
        </div>
      )}

      <div className="mb-4 flex flex-col md:flex-row md:items-end justify-between gap-3 flex-shrink-0">
        <div>
          <h3 className="font-heading font-bold text-lg text-navy mb-1">
            Rencana Studi (Roadmap)
          </h3>
          <p className="text-sm text-muted">
            Matkul <span className="font-medium text-navy">Wajib</span> otomatis
            terkunci di semesternya. Matkul{" "}
            <span className="font-medium text-navy">Pilihan</span> dapat
            dipindah-pindah. Matkul yang sudah lulus di transkrip tampil{" "}
            <span className="font-medium text-navy">terkunci</span> dan tidak
            ikut disimpan ulang ke skenario.
          </p>
        </div>
        <div className="flex flex-wrap gap-2.5 items-center">
          {LEGEND_ITEMS.map((item) => (
            <div
              key={item.label}
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-surface border border-border text-xs shadow-2xs"
            >
              {item.icon}
              <span className="font-semibold text-navy">{item.label}</span>
              <span
                className={`text-[9px] font-mono px-1.5 py-0.5 rounded border leading-none font-medium ${item.badgeStyle}`}
              >
                {item.badge}
              </span>
            </div>
          ))}
        </div>
      </div>

      {dragging && (
        <div className="mb-3 p-3 bg-navy/5 border border-navy/15 rounded-lg flex items-center gap-3 text-sm flex-shrink-0 animate-in fade-in duration-150">
          <GripVertical className="w-4 h-4 text-navy/40" />
          <span className="text-navy">
            <strong>{dragging.course.name}</strong>
            {isSemLocked(dragging.course) ? (
              <>
                {" "}
                — matkul <strong>Wajib</strong>: hanya dapat diatur urutan
                (atas/bawah) di <strong>Semester {dragging.fromSem}</strong>.
              </>
            ) : (
              <>
                {" "}
                — matkul <strong>Pilihan</strong>: dapat dipindah ke semester{" "}
                <strong>
                  {dragging.course.parity === "odd"
                    ? "ganjil (1, 3, 5, 7)"
                    : "genap (2, 4, 6, 8)"}
                </strong>{" "}
                dan diatur urutan atas/bawah.
              </>
            )}
          </span>
        </div>
      )}
    </>
  )
}
