import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { ArrowRight, Search, ExternalLink } from "lucide-react";
import { Navbar } from "@/components/Navbar";
import { StreakBanner } from "@/components/StreakBanner";
import { StatCard, StatusBadge, Chips, Tabs, Empty, Field, inputCls } from "@/components/Shared";
import { PlatformIcon } from "@/components/PlatformIcon";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { useAuth } from "@/context/AuthContext";
import { api, rp, num, errMsg, fmtDate } from "@/lib/api";

const FILTERS = [["", "Semua"], ["direview", "Direview"], ["menunggu_views", "Menunggu views"], ["diproses", "Diproses"], ["disetujui", "Disetujui"], ["ditolak", "Ditolak"]];
const METHODS = ["BCA", "Mandiri", "BRI", "BNI", "DANA", "GoPay", "OVO", "ShopeePay"];

export default function CreatorDashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [tab, setTab] = useState("submission");
  const load = useCallback(() => api.get("/creator/stats").then((r) => setStats(r.data)), []);
  useEffect(() => { load(); }, [load]);
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      <Navbar />
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-6">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight" data-testid="dashboard-greeting">Halo, {user.name.split(" ")[0]}</h1>
            <p className="text-slate-500">bikin viral, dapet cuan</p>
          </div>
          <button data-testid="find-campaign-button" onClick={() => navigate("/bounty")} className="h-12 px-5 rounded-xl bg-slate-900 text-white font-bold flex items-center gap-2 hover:bg-black active:scale-95 transition-transform">
            Cari campaign <ArrowRight className="h-4 w-4" />
          </button>
        </div>
        {stats && (
          <>
            <div className="grid grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_1fr] gap-4">
              <StatCard testid="stat-balance" big label="Saldo tersedia" value={rp(stats.balance)} sub="Min. penarikan Rp 50.000" />
              <StatCard testid="stat-total" label="Total penghasilan" value={rp(stats.total_earned)} sub="Sejak gabung" />
              <StatCard testid="stat-pending" label="Estimasi pending" value={rp(stats.pending)} sub="Dari video yang lagi diproses" />
              <StatCard testid="stat-videos" label="Video terdaftar" value={stats.videos} sub={`Di ${stats.campaigns} campaign`} />
            </div>
            <StreakBanner data={stats.streak} />
          </>
        )}
        <Tabs prefix="creator-tab" value={tab} onChange={setTab} items={[["submission", "Submission"], ["saldo", "Saldo"], ["profil", "Profil"]]} />
        {tab === "submission" && <Submissions onChange={load} />}
        {tab === "saldo" && stats && <Saldo balance={stats.balance} onChange={load} />}
        {tab === "profil" && <Profile />}
      </main>
    </div>
  );
}

const Submissions = ({ onChange }) => {
  const [items, setItems] = useState([]);
  const [f, setF] = useState("");
  const [q, setQ] = useState("");
  const [claim, setClaim] = useState(null);
  const navigate = useNavigate();
  const load = () => api.get("/creator/submissions").then((r) => setItems(r.data));
  useEffect(() => { load(); }, []);
  const shown = items.filter((s) => (!f || s.status === f || (f === "diproses" && s.status === "verifying")) && s.campaign_title.toLowerCase().includes(q.toLowerCase()));

  return (
    <div className="space-y-4">
      <div className="relative">
        <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
        <input data-testid="submission-search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari campaign..." className={`${inputCls} pl-10 h-12`} />
      </div>
      <Chips prefix="submission-filter" items={FILTERS} value={f} onChange={setF} />
      {shown.length === 0 ? (
        <Empty title="Belum ada submission" desc="Video yang kamu daftarkan ke kampanye akan muncul di sini.">
          <button data-testid="start-earning-button" onClick={() => navigate("/bounty")} className="h-11 px-5 rounded-xl bg-[#FF5500] text-white font-bold hover:bg-[#E04B00]">Mulai cari cuan</button>
        </Empty>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-200 divide-y">
          {shown.map((s) => (
            <div key={s.submission_id} className="p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center gap-3" data-testid={`submission-row-${s.submission_id}`}>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2"><PlatformIcon p={s.platform} /><p className="font-bold truncate">{s.campaign_title}</p></div>
                <a href={s.video_url} target="_blank" rel="noreferrer" className="text-sm text-slate-500 hover:text-[#FF5500] flex items-center gap-1 truncate">{s.video_url} <ExternalLink className="h-3 w-3 shrink-0" /></a>
                {s.note && <p className="text-xs text-red-600 mt-1">{s.note}</p>}
              </div>
              <div className="text-sm text-slate-600 sm:text-right">
                {s.status === "disetujui" ? <p className="font-bold text-emerald-600" data-testid="submission-payout">+{rp(s.payout)}</p> : s.claimed_views > 0 && <p>{num(s.claimed_views)} views diklaim</p>}
                <p className="text-xs">{fmtDate(s.created_at)}</p>
              </div>
              <StatusBadge s={s.status} />
              {s.status === "menunggu_views" && (
                <button data-testid={`claim-button-${s.submission_id}`} onClick={() => setClaim(s)} className="h-9 px-4 rounded-lg bg-[#FF5500] text-white text-sm font-bold hover:bg-[#E04B00]">Klaim views</button>
              )}
            </div>
          ))}
        </div>
      )}
      <ClaimDialog s={claim} onClose={() => setClaim(null)} onDone={() => { load(); onChange(); }} />
    </div>
  );
};

const ClaimDialog = ({ s, onClose, onDone }) => {
  const [views, setViews] = useState("");
  const submit = async (e) => {
    e.preventDefault();
    try {
      await api.post(`/submissions/${s.submission_id}/claim`, { views: Number(views) });
      toast.success("Klaim views dikirim, menunggu verifikasi");
      onClose(); onDone(); setViews("");
    } catch (err) { toast.error(errMsg(err)); }
  };
  return (
    <Dialog open={!!s} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="rounded-2xl max-w-md" data-testid="claim-dialog">
        {s && (
          <form onSubmit={submit} className="space-y-4">
            <DialogHeader><DialogTitle>Klaim views</DialogTitle><DialogDescription>Masukkan jumlah views saat ini. Brand/admin akan memverifikasi langsung dari videomu.</DialogDescription></DialogHeader>
            <input data-testid="claim-views-input" type="number" required min={s.min_views} value={views} onChange={(e) => setViews(e.target.value)} placeholder={`Min. ${num(s.min_views)}`} className={inputCls} />
            <p className="text-sm">Estimasi: <b className="text-[#FF5500]">{rp(Math.floor((Number(views) || 0) / 1000 * s.rate_per_1k))}</b></p>
            <button data-testid="claim-submit-button" className="w-full h-11 rounded-xl bg-[#FF5500] text-white font-bold">Kirim klaim</button>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
};

const Saldo = ({ balance, onChange }) => {
  const { user } = useAuth();
  const p = user.profile || {};
  const [form, setForm] = useState({ amount: "", method: p.bank_method || "BCA", account_number: p.bank_account || "", account_holder: p.bank_holder || "" });
  const [list, setList] = useState([]);
  const [busy, setBusy] = useState(false);
  const load = () => api.get("/creator/withdrawals").then((r) => setList(r.data));
  useEffect(() => { load(); }, []);
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      await api.post("/withdrawals", { ...form, amount: Number(form.amount) });
      toast.success(`Permintaan penarikan ${rp(form.amount)} diproses`);
      setForm({ ...form, amount: "" }); load(); onChange();
    } catch (err) { toast.error(errMsg(err)); } finally { setBusy(false); }
  };

  return (
    <div className="grid lg:grid-cols-[380px_1fr] gap-6">
      <form onSubmit={submit} className="bg-white rounded-2xl border border-slate-200 p-6 space-y-4 h-fit" data-testid="withdraw-form">
        <h3 className="font-bold text-lg">Tarik saldo</h3>
        {balance < 50000 && <p className="text-sm bg-amber-50 text-amber-800 rounded-xl p-3" data-testid="withdraw-min-warning">Saldo kamu belum mencapai minimal penarikan Rp 50.000.</p>}
        <Field label="Jumlah (Rp)"><input data-testid="withdraw-amount-input" type="number" min={50000} max={balance} required value={form.amount} onChange={set("amount")} className={inputCls} /></Field>
        <Field label="Tujuan">
          <select data-testid="withdraw-method-select" value={form.method} onChange={set("method")} className={inputCls}>{METHODS.map((m) => <option key={m}>{m}</option>)}</select>
        </Field>
        <Field label="No. rekening / HP"><input data-testid="withdraw-account-input" required value={form.account_number} onChange={set("account_number")} className={inputCls} /></Field>
        <Field label="Nama pemilik"><input data-testid="withdraw-holder-input" required value={form.account_holder} onChange={set("account_holder")} className={inputCls} /></Field>
        <button data-testid="withdraw-submit-button" disabled={busy || balance < 50000} className="w-full h-11 rounded-xl bg-[#FF5500] text-white font-bold hover:bg-[#E04B00] disabled:opacity-50">Ajukan penarikan</button>
      </form>
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
        <div className="px-6 py-4 border-b font-bold">Riwayat penarikan</div>
        {list.length === 0 ? <p className="p-8 text-center text-sm text-slate-500">Belum ada penarikan</p> : (
          <div className="divide-y">
            {list.map((w) => (
              <div key={w.withdrawal_id} className="px-6 py-4 flex items-center gap-4" data-testid={`withdrawal-row-${w.withdrawal_id}`}>
                <div className="flex-1">
                  <p className="font-bold">{rp(w.amount)}</p>
                  <p className="text-xs text-slate-500">{w.method} · {w.account_number} · {fmtDate(w.created_at)}</p>
                  {w.reference && <p className="text-xs text-slate-500">Ref: {w.reference}</p>}
                </div>
                <StatusBadge s={w.status} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export const Profile = () => {
  const { user, setUser } = useAuth();
  const p = user.profile || {};
  const [form, setForm] = useState({ name: user.name, tiktok: p.tiktok || "", instagram: p.instagram || "", brand_name: p.brand_name || "", bank_method: p.bank_method || "", bank_account: p.bank_account || "", bank_holder: p.bank_holder || "" });
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const save = async (e) => {
    e.preventDefault();
    try { const { data } = await api.put("/users/profile", form); setUser(data); toast.success("Profil disimpan"); }
    catch (err) { toast.error(errMsg(err)); }
  };
  const fields = user.role === "brand" ? [["name", "Nama"], ["brand_name", "Nama brand"]] : [["name", "Nama"], ["tiktok", "Username TikTok"], ["instagram", "Username Instagram"], ["bank_method", "Bank / e-wallet"], ["bank_account", "No. rekening / HP"], ["bank_holder", "Nama pemilik rekening"]];
  return (
    <form onSubmit={save} className="bg-white rounded-2xl border border-slate-200 p-6 grid sm:grid-cols-2 gap-4 max-w-3xl" data-testid="profile-form">
      <p className="sm:col-span-2 text-sm text-slate-500">{user.email}</p>
      {fields.map(([k, l]) => <Field key={k} label={l}><input data-testid={`profile-${k}`} value={form[k]} onChange={set(k)} className={inputCls} /></Field>)}
      <button data-testid="profile-save-button" className="sm:col-span-2 h-11 w-fit px-6 rounded-xl bg-slate-900 text-white font-bold">Simpan</button>
    </form>
  );
};
