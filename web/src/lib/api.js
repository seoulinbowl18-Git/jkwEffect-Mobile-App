import axios from "axios";

export const API = `${process.env.REACT_APP_BACKEND_URL}/api`;
export const api = axios.create({ baseURL: API, withCredentials: true });

export const rp = (n) => "Rp " + Number(n || 0).toLocaleString("id-ID");
export const num = (n) => Number(n || 0).toLocaleString("id-ID");
export const errMsg = (e) => {
  const d = e?.response?.data?.detail;
  if (Array.isArray(d)) return d.map((x) => x.msg).join(", ");
  return d || "Terjadi kesalahan";
};
export const fmtDate = (s) =>
  new Date(s).toLocaleDateString("id-ID", { day: "numeric", month: "short", year: "numeric" });

export const PLATFORMS = {
  tiktok: "TikTok",
  instagram: "Instagram",
  threads: "Threads",
  youtube: "YouTube",
};
export const CATEGORIES = ["Produk", "Beauty", "Lifestyle", "F&B", "Edukasi", "Hiburan", "Fashion", "Tech"];

export const STATUS = {
  direview: { label: "Direview", cls: "bg-amber-100 text-amber-800" },
  menunggu_views: { label: "Menunggu views", cls: "bg-sky-100 text-sky-800" },
  diproses: { label: "Diproses", cls: "bg-orange-100 text-orange-800" },
  verifying: { label: "Diproses", cls: "bg-orange-100 text-orange-800" },
  disetujui: { label: "Disetujui", cls: "bg-emerald-100 text-emerald-800" },
  ditolak: { label: "Ditolak", cls: "bg-red-100 text-red-700" },
  pending: { label: "Menunggu bayar", cls: "bg-amber-100 text-amber-800" },
  paid: { label: "Lunas", cls: "bg-emerald-100 text-emerald-800" },
  expired: { label: "Kadaluarsa", cls: "bg-slate-100 text-slate-600" },
  active: { label: "Aktif", cls: "bg-emerald-100 text-emerald-800" },
  paused: { label: "Dijeda", cls: "bg-slate-100 text-slate-700" },
  closed: { label: "Ditutup", cls: "bg-slate-200 text-slate-700" },
};
