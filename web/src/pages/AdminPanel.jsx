import { useCallback, useEffect, useState } from "react";
import { toast } from "sonner";
import { Navbar } from "@/components/Navbar";
import { StatCard, StatusBadge, Chips, Tabs } from "@/components/Shared";
import { ReviewList } from "@/components/ReviewList";
import { api, rp, num, errMsg, fmtDate } from "@/lib/api";

export default function AdminPanel() {
  const [stats, setStats] = useState(null);
  const [tab, setTab] = useState("submissions");
  const load = useCallback(() => api.get("/admin/stats").then((r) => setStats(r.data)), []);
  useEffect(() => { load(); }, [load]);
  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      <Navbar />
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-6">
        <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight" data-testid="admin-title">Admin Panel</h1>
        {stats && (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard testid="admin-stat-users" label="Kreator / Brand" value={`${stats.creators} / ${stats.brands}`} />
            <StatCard testid="admin-stat-campaigns" label="Campaign aktif" value={stats.active_campaigns} sub={`${num(stats.total_views)} views terverifikasi`} />
            <StatCard testid="admin-stat-pending" label="Perlu tindakan" value={stats.pending_submissions + stats.pending_withdrawals} sub={`${stats.pending_submissions} submission · ${stats.pending_withdrawals} penarikan`} />
            <StatCard testid="admin-stat-paid" label="Total ditransfer" value={rp(stats.total_paid)} />
          </div>
        )}
        <Tabs prefix="admin-tab" value={tab} onChange={setTab} items={[["submissions", "Verifikasi submission"], ["withdrawals", "Persetujuan withdraw"], ["campaigns", "Kelola campaign"], ["users", "Kelola user"]]} />
        {tab === "submissions" && <AdminSubs onChange={load} />}
        {tab === "withdrawals" && <AdminWithdrawals onChange={load} />}
        {tab === "campaigns" && <AdminCampaigns onChange={load} />}
        {tab === "users" && <AdminUsers />}
      </main>
    </div>
  );
}

const AdminSubs = ({ onChange }) => {
  const [f, setF] = useState("diproses");
  const [items, setItems] = useState([]);
  const load = useCallback(() => api.get("/admin/submissions", { params: { status: f } }).then((r) => setItems(r.data)), [f]);
  useEffect(() => { load(); }, [load]);
  return (
    <div className="space-y-4">
      <Chips prefix="admin-sub-filter" value={f} onChange={setF} items={[["diproses", "Verifikasi views"], ["direview", "Review konten"], ["menunggu_views", "Menunggu views"], ["disetujui", "Disetujui"], ["ditolak", "Ditolak"], ["", "Semua"]]} />
      <ReviewList items={items} onChange={() => { load(); onChange(); }} />
    </div>
  );
};

const AdminWithdrawals = ({ onChange }) => {
  const [items, setItems] = useState([]);
  const load = () => api.get("/admin/withdrawals").then((r) => setItems(r.data));
  useEffect(() => { load(); }, []);
  const act = async (w, action) => {
    const reference = window.prompt(action === "approve" ? "ID / bukti transfer" : "Alasan penolakan") ?? null;
    if (reference === null) return;
    try { await api.post(`/admin/withdrawals/${w.withdrawal_id}`, { action, reference }); toast.success("Diproses"); load(); onChange(); }
    catch (e) { toast.error(errMsg(e)); }
  };
  if (!items.length) return <p className="bg-white rounded-2xl border p-10 text-center text-sm text-slate-500">Belum ada penarikan</p>;
  return (
    <div className="bg-white rounded-2xl border divide-y">
      {items.map((w) => (
        <div key={w.withdrawal_id} className="px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-3" data-testid={`admin-wd-row-${w.withdrawal_id}`}>
          <div className="flex-1">
            <p className="font-bold">{rp(w.amount)} <span className="font-normal text-slate-500">· {w.creator_name}</span></p>
            <p className="text-xs text-slate-500">{w.method} {w.account_number} a.n. {w.account_holder} · {fmtDate(w.created_at)} {w.reference && `· Ref ${w.reference}`}</p>
          </div>
          <StatusBadge s={w.status} />
          {w.status === "diproses" && (
            <div className="flex gap-2">
              <button data-testid={`admin-wd-approve-${w.withdrawal_id}`} onClick={() => act(w, "approve")} className="h-9 px-3 rounded-lg bg-emerald-600 text-white text-sm font-bold">Sudah ditransfer</button>
              <button data-testid={`admin-wd-reject-${w.withdrawal_id}`} onClick={() => act(w, "reject")} className="h-9 px-3 rounded-lg border text-sm font-bold">Tolak</button>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

const AdminCampaigns = ({ onChange }) => {
  const [items, setItems] = useState([]);
  const load = () => api.get("/admin/campaigns").then((r) => setItems(r.data));
  useEffect(() => { load(); }, []);
  const setStatus = async (c, status) => {
    if (status === "closed" && !window.confirm("Tutup campaign & refund sisa budget ke brand?")) return;
    try { await api.patch(`/campaigns/${c.campaign_id}/status`, { status }); load(); onChange(); } catch (e) { toast.error(errMsg(e)); }
  };
  return (
    <div className="bg-white rounded-2xl border divide-y">
      {items.map((c) => (
        <div key={c.campaign_id} className="px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-3" data-testid={`admin-campaign-${c.campaign_id}`}>
          <div className="flex-1 min-w-0"><p className="font-bold truncate">{c.title}</p><p className="text-xs text-slate-500">{c.brand_name} · {rp(c.rate_per_1k)}/1K · {rp(c.spent)} / {rp(c.budget)} · {c.submission_count} video</p></div>
          <StatusBadge s={c.status} />
          {c.status !== "closed" && (
            <div className="flex gap-2">
              <button data-testid={`admin-campaign-toggle-${c.campaign_id}`} onClick={() => setStatus(c, c.status === "active" ? "paused" : "active")} className="h-9 px-3 rounded-lg border text-sm font-semibold">{c.status === "active" ? "Jeda" : "Aktifkan"}</button>
              <button data-testid={`admin-campaign-close-${c.campaign_id}`} onClick={() => setStatus(c, "closed")} className="h-9 px-3 rounded-lg border text-sm font-semibold text-red-600">Tutup</button>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

const AdminUsers = () => {
  const [items, setItems] = useState([]);
  const load = () => api.get("/admin/users").then((r) => setItems(r.data));
  useEffect(() => { load(); }, []);
  const credit = async (u) => {
    const v = window.prompt(`Tambah saldo brand untuk ${u.name} (Rp)`);
    if (!v) return;
    try { await api.post(`/admin/users/${u.user_id}/brand-credit`, { amount: Number(v) }); toast.success("Saldo ditambahkan"); load(); }
    catch (e) { toast.error(errMsg(e)); }
  };
  return (
    <div className="bg-white rounded-2xl border divide-y">
      {items.map((u) => (
        <div key={u.user_id} className="px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-3" data-testid={`admin-user-${u.user_id}`}>
          <div className="flex-1 min-w-0"><p className="font-bold truncate">{u.name}</p><p className="text-xs text-slate-500 truncate">{u.email} · bergabung {fmtDate(u.created_at)}</p></div>
          <span className="text-xs font-semibold px-2 py-1 rounded-full bg-slate-100">{u.role || "belum pilih"}</span>
          <p className="text-sm font-semibold w-40 sm:text-right">{u.role === "brand" ? rp(u.brand_balance) : u.role === "creator" ? rp(u.balance) : "-"}</p>
          {u.role === "brand" && <button data-testid={`admin-credit-${u.user_id}`} onClick={() => credit(u)} className="h-9 px-3 rounded-lg border text-sm font-semibold">+ Saldo</button>}
        </div>
      ))}
    </div>
  );
};
