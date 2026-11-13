export const rp = (n: number) => "Rp " + Number(n || 0).toLocaleString("id-ID");
export const num = (n: number) => Number(n || 0).toLocaleString("id-ID");
export const fmtDate = (s: string) =>
  new Date(s).toLocaleDateString("id-ID", { day: "numeric", month: "short", year: "numeric" });
export const daysLeft = (s: string) => Math.max(0, Math.ceil((new Date(s).getTime() - Date.now()) / 86400000));

export const PLATFORMS = { tiktok: "TikTok", instagram: "Instagram", threads: "Threads", youtube: "YouTube" } as const;
export const CATEGORIES = ["Produk", "Beauty", "Lifestyle", "F&B", "Edukasi", "Hiburan", "Fashion", "Tech"];
export const MIN_WITHDRAW = 50000;

export type Tone = "warning" | "info" | "primary" | "success" | "danger" | "muted";
export const STATUS: Record<string, { label: string; tone: Tone }> = {
  direview: { label: "Direview", tone: "warning" },
  menunggu_views: { label: "Disetujui · Klaim views", tone: "info" },
  diproses: { label: "Dicek views", tone: "primary" },
  verifying: { label: "Dicek views", tone: "primary" },
  disetujui: { label: "Selesai", tone: "success" },
  ditolak: { label: "Ditolak", tone: "danger" },
  pending: { label: "Menunggu bayar", tone: "warning" },
  paid: { label: "Lunas", tone: "success" },
  expired: { label: "Kadaluarsa", tone: "muted" },
  canceled: { label: "Dibatalkan", tone: "muted" },
  failed: { label: "Gagal", tone: "danger" },
  active: { label: "Aktif", tone: "success" },
  paused: { label: "Dijeda", tone: "muted" },
  closed: { label: "Ditutup", tone: "muted" },
  wd_diproses: { label: "Diproses", tone: "warning" },
  wd_disetujui: { label: "Berhasil", tone: "success" },
  wd_ditolak: { label: "Ditolak", tone: "danger" },
};
