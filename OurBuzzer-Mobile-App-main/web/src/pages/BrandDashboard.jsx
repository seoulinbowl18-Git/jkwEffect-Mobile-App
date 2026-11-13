import { useCallback, useEffect, useState } from "react";
import { toast } from "sonner";
import { Plus, Wallet, QrCode, Landmark, RefreshCw } from "lucide-react";
import { QRCodeSVG } from "qrcode.react";
import { Navbar } from "@/components/Navbar";
import { StatCard, StatusBadge, Chips, Tabs, Field, inputCls } from "@/components/Shared";
import { ReviewList } from "@/components/ReviewList";
import { PlatformIcon } from "@/components/PlatformIcon";
import { Profile } from "@/pages/CreatorDashboard";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { useAuth } from "@/context/AuthContext";
import { api, rp, num, errMsg, fmtDate, CATEGORIES, PLATFORMS } from "@/lib/api";

export default function BrandDashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [tab, setTab] = useState("campaign");
  const [create, setCreate] = useState(false);
  const [topup, setTopup] = useState(false);
  const [key, setKey] = useState(0);
  const load = useCallback(() => { api.get("/brand/stats").then((r) => setStats(r.data)); setKey((k) => k + 1); }, []);
  useEffect(() => { load(); }, [load]);

  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      <Navbar />
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-6">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight" data-testid="dashboard-greeting">{user.profile?.brand_name || user.name}</h1>
            <p className="text-slate-500">Bayar per performa, bukan per janji.</p>
          </div>
          <div className="flex gap-2">
            <button data-testid="topup-open-button" onClick={() => setTopup(true)} className="h-12 px-4 rounded-xl border bg-white font-bold flex items-center gap-2 hover:bg-slate-50"><Wallet className="h-4 w-4" /> Top up</button>
            <button data-testid="create-campaign-open-button" onClick={() => setCreate(true)} className="h-12 px-5 rounded-xl bg-[#FF5500] text-white font-bold flex items-center gap-2 hover:bg-[#E04B00] active:scale-95 transition-transform"><Plus className="h-4 w-4" /> Buat campaign</button>
          </div>
        </div>
        {stats && (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard testid="brand-stat-balance" big label="Saldo brand" value={rp(stats.brand_balance)} sub="Untuk budget campaign" />
            <StatCard testid="brand-stat-active" label="Campaign aktif" value={stats.active} />
            <StatCard testid="brand-stat-spent" label="Total dibayarkan" value={rp(stats.spent)} sub={`${num(stats.views)} views terverifikasi`} />
            <StatCard testid="brand-stat-pending" label="Perlu direview" value={stats.pending_reviews} sub="Submission & klaim views" />
          </div>
        )}
        <Tabs prefix="brand-tab" value={tab} onChange={setTab} items={[["campaign", "Campaign"], ["review", "Review submission"], ["topup", "Riwayat top up"], ["profil", "Profil"]]} />
        {tab === "campaign" && <BrandCampaigns key={key} onChange={load} />}
        {tab === "review" && <BrandReview onChange={load} />}
        {tab === "topup" && <TopupHistory key={key} onChange={load} />}
        {tab === "profil" && <Profile />}
      </main>
      <CreateCampaign open={create} onClose={() => setCreate(false)} balance={stats?.brand_balance || 0} onDone={load} />
      <TopupDialog open={topup} onClose={() => setTopup(false)} onDone={load} />
    </div>
  );
}

const BrandCampaigns = ({ onChange }) => {
  const [items, setItems] = useState([]);
  const load = () => api.get("/brand/campaigns").then((r) => setItems(r.data));
  useEffect(() => { load(); }, []);
  const setStatus = async (c, status) => {
    if (status === "closed" && !window.confirm("Tutup campaign? Sisa budget dikembalikan ke saldo brand.")) return;
    try { await api.patch(`/campaigns/${c.campaign_id}/status`, { status }); load(); onChange(); } catch (e) { toast.error(errMsg(e)); }
  };
  if (!items.length) return <p className="bg-white rounded-2xl border p-10 text-center text-sm text-slate-500" data-testid="brand-no-campaigns">Belum ada campaign. Top up saldo lalu buat campaign pertamamu.</p>;
  return (
    <div className="grid md:grid-cols-2 gap-4">
      {items.map((c) => (
        <div key={c.campaign_id} className="bg-white rounded-2xl border border-slate-200 p-5" data-testid={`brand-campaign-${c.campaign_id}`}>
          <div className="flex items-start gap-3">
            <div className="flex-1 min-w-0">
              <p className="font-bold truncate">{c.title}</p>
              <p className="text-xs text-slate-500">{c.category} · {rp(c.rate_per_1k)}/1K · tutup {fmtDate(c.deadline)}</p>
            </div>
            <StatusBadge s={c.status} />
          </div>
          <div className="mt-4 grid grid-cols-3 gap-2 text-sm">
            <div><p className="text-slate-500 text-xs">Terpakai</p><p className="font-bold">{rp(c.spent)}</p></div>
            <div><p className="text-slate-500 text-xs">Budget</p><p className="font-bold">{rp(c.budget)}</p></div>
            <div><p className="text-slate-500 text-xs">Video / views</p><p className="font-bold">{c.submission_count} / {num(c.total_views)}</p></div>
          </div>
          <div className="mt-3 h-1.5 bg-slate-100 rounded-full overflow-hidden"><div className="h-full bg-[#FF5500]" style={{ width: `${100 - c.budget_left_pct}%` }} /></div>
          {c.status !== "closed" && (
            <div className="mt-4 flex gap-2">
              <button data-testid={`campaign-toggle-${c.campaign_id}`} onClick={() => setStatus(c, c.status === "active" ? "paused" : "active")} className="h-9 px-3 rounded-lg border text-sm font-semibold">{c.status === "active" ? "Jeda" : "Aktifkan"}</button>
              <button data-testid={`campaign-close-${c.campaign_id}`} onClick={() => setStatus(c, "closed")} className="h-9 px-3 rounded-lg border text-sm font-semibold text-red-600">Tutup & refund</button>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

const BrandReview = ({ onChange }) => {
  const [items, setItems] = useState([]);
  const [f, setF] = useState("direview");
  const load = useCallback(() => api.get("/brand/submissions", { params: { status: f } }).then((r) => setItems(r.data)), [f]);
  useEffect(() => { load(); }, [load]);
  return (
    <div className="space-y-4">
      <Chips prefix="brand-review-filter" value={f} onChange={setF} items={[["direview", "Review konten"], ["diproses", "Verifikasi views"], ["menunggu_views", "Menunggu views"], ["disetujui", "Disetujui"], ["ditolak", "Ditolak"], ["", "Semua"]]} />
      <ReviewList items={items} onChange={() => { load(); onChange(); }} />
    </div>
  );
};

const EMPTY = { title: "", category: "Produk", platforms: ["tiktok"], rate_per_1k: 5000, min_views: 5000, budget: 1000000, thumbnail: "", instructions: "", exclusive: false, deadline_days: 30 };

const CreateCampaign = ({ open, onClose, balance, onDone }) => {
  const [f, setF] = useState(EMPTY);
  const [busy, setBusy] = useState(false);
  const set = (k, n) => (e) => setF({ ...f, [k]: n ? Number(e.target.value) : e.target.value });
  const togglePlat = (p) => setF({ ...f, platforms: f.platforms.includes(p) ? f.platforms.filter((x) => x !== p) : [...f.platforms, p] });
  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    try { await api.post("/campaigns", f); toast.success("Campaign dibuat!"); setF(EMPTY); onClose(); onDone(); }
    catch (err) { toast.error(errMsg(err)); } finally { setBusy(false); }
  };
  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="rounded-2xl max-w-2xl max-h-[90vh] overflow-auto" data-testid="create-campaign-dialog">
        <form onSubmit={submit} className="space-y-4">
          <DialogHeader><DialogTitle>Buat campaign baru</DialogTitle><DialogDescription>Budget dipotong dari saldo brand ({rp(balance)}). Sisa budget dikembalikan saat campaign ditutup.</DialogDescription></DialogHeader>
          <Field label="Judul"><input data-testid="cc-title" required value={f.title} onChange={set("title")} className={inputCls} /></Field>
          <div className="grid sm:grid-cols-2 gap-4">
            <Field label="Kategori"><select data-testid="cc-category" value={f.category} onChange={set("category")} className={inputCls}>{CATEGORIES.map((c) => <option key={c}>{c}</option>)}</select></Field>
            <Field label="Durasi (hari)"><input data-testid="cc-days" type="number" min={1} max={180} value={f.deadline_days} onChange={set("deadline_days", 1)} className={inputCls} /></Field>
          </div>
          <Field label="Platform">
            <div className="flex gap-2 flex-wrap">
              {Object.entries(PLATFORMS).map(([k, l]) => (
                <button type="button" key={k} data-testid={`cc-platform-${k}`} onClick={() => togglePlat(k)} className={`h-10 px-3 rounded-xl border text-sm font-semibold flex items-center gap-1.5 ${f.platforms.includes(k) ? "bg-slate-900 text-white border-slate-900" : ""}`}><PlatformIcon p={k} /> {l}</button>
              ))}
            </div>
          </Field>
          <div className="grid sm:grid-cols-3 gap-4">
            <Field label="Rate per 1K views (Rp)"><input data-testid="cc-rate" type="number" min={500} required value={f.rate_per_1k} onChange={set("rate_per_1k", 1)} className={inputCls} /></Field>
            <Field label="Min. views"><input data-testid="cc-min-views" type="number" min={100} required value={f.min_views} onChange={set("min_views", 1)} className={inputCls} /></Field>
            <Field label="Total budget (Rp)"><input data-testid="cc-budget" type="number" min={100000} required value={f.budget} onChange={set("budget", 1)} className={inputCls} /></Field>
          </div>
          <Field label="URL gambar thumbnail (opsional)"><input data-testid="cc-thumbnail" value={f.thumbnail} onChange={set("thumbnail")} placeholder="https://..." className={inputCls} /></Field>
          <Field label="Brief & aturan"><textarea data-testid="cc-instructions" required minLength={10} rows={5} value={f.instructions} onChange={set("instructions")} className={`${inputCls} h-auto py-3`} /></Field>
          <label className="flex items-center gap-2 text-sm font-semibold"><input data-testid="cc-exclusive" type="checkbox" checked={f.exclusive} onChange={(e) => setF({ ...f, exclusive: e.target.checked })} /> Campaign exclusive</label>
          <button data-testid="cc-submit" disabled={busy || !f.platforms.length} className="w-full h-12 rounded-xl bg-[#FF5500] text-white font-bold disabled:opacity-50">{busy ? "Menyimpan..." : `Buat campaign (${rp(f.budget)})`}</button>
        </form>
      </DialogContent>
    </Dialog>
  );
};

const TopupDialog = ({ open, onClose, onDone }) => {
  const [amount, setAmount] = useState(1000000);
  const [type, setType] = useState("qris");
  const [bank, setBank] = useState("BCA");
  const [result, setResult] = useState(null);
  const [busy, setBusy] = useState(false);
  const create = async () => {
    setBusy(true);
    try { const { data } = await api.post("/brand/topups", { amount: Number(amount), payment_type: type, channel_code: bank }); setResult(data); }
    catch (e) { toast.error(errMsg(e)); } finally { setBusy(false); }
  };
  const check = async () => {
    const { data } = await api.post(`/brand/topups/${result.topup_id}/check`);
    setResult(data);
    if (data.status === "paid") { toast.success("Pembayaran diterima!"); onDone(); }
    else toast("Pembayaran belum diterima");
  };
  const close = () => { setResult(null); onClose(); onDone(); };
  return (
    <Dialog open={open} onOpenChange={(o) => !o && close()}>
      <DialogContent className="rounded-2xl max-w-md" data-testid="topup-dialog">
        <DialogHeader><DialogTitle>Top up saldo brand</DialogTitle><DialogDescription>Pembayaran via Komerce (QRIS / Virtual Account).</DialogDescription></DialogHeader>
        {!result ? (
          <div className="space-y-4">
            <Field label="Jumlah (Rp)"><input data-testid="topup-amount" type="number" min={10000} value={amount} onChange={(e) => setAmount(e.target.value)} className={inputCls} /></Field>
            <div className="grid grid-cols-2 gap-2">
              {[["qris", "QRIS", QrCode], ["bank_transfer", "Virtual Account", Landmark]].map(([k, l, I]) => (
                <button key={k} data-testid={`topup-type-${k}`} onClick={() => setType(k)} className={`h-12 rounded-xl border font-semibold flex items-center justify-center gap-2 ${type === k ? "border-[#FF5500] bg-orange-50" : ""}`}><I className="h-4 w-4" /> {l}</button>
              ))}
            </div>
            {type === "bank_transfer" && (
              <select data-testid="topup-bank" value={bank} onChange={(e) => setBank(e.target.value)} className={inputCls}>{["BCA", "BNI", "BRI", "MANDIRI", "PERMATA"].map((b) => <option key={b}>{b}</option>)}</select>
            )}
            <button data-testid="topup-create-button" disabled={busy} onClick={create} className="w-full h-12 rounded-xl bg-[#FF5500] text-white font-bold disabled:opacity-50">{busy ? "Membuat tagihan..." : `Bayar ${rp(amount)}`}</button>
          </div>
        ) : (
          <div className="space-y-4 text-center" data-testid="topup-result">
            <p className="text-2xl font-extrabold">{rp(result.amount)}</p>
            {result.qr_string && <div className="grid place-items-center"><QRCodeSVG value={result.qr_string} size={200} /></div>}
            {result.va_number && <div><p className="text-sm text-slate-500">VA {result.channel_code}</p><p className="text-2xl font-mono font-bold" data-testid="topup-va">{result.va_number}</p></div>}
            {result.payment_url && <a href={result.payment_url} target="_blank" rel="noreferrer" className="block text-[#FF5500] font-semibold text-sm" data-testid="topup-payment-link">Buka halaman pembayaran</a>}
            <div><StatusBadge s={result.status} /></div>
            <button data-testid="topup-check-button" onClick={check} className="w-full h-11 rounded-xl bg-slate-900 text-white font-bold flex items-center justify-center gap-2"><RefreshCw className="h-4 w-4" /> Cek status pembayaran</button>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
};

const TopupHistory = ({ onChange }) => {
  const [items, setItems] = useState([]);
  const load = () => api.get("/brand/topups").then((r) => setItems(r.data));
  useEffect(() => { load(); }, []);
  const check = async (t) => { await api.post(`/brand/topups/${t.topup_id}/check`).catch(() => {}); load(); onChange(); };
  if (!items.length) return <p className="bg-white rounded-2xl border p-10 text-center text-sm text-slate-500">Belum ada top up</p>;
  return (
    <div className="bg-white rounded-2xl border divide-y">
      {items.map((t) => (
        <div key={t.topup_id} className="px-5 py-4 flex items-center gap-3" data-testid={`topup-row-${t.topup_id}`}>
          <div className="flex-1"><p className="font-bold">{rp(t.amount)}</p><p className="text-xs text-slate-500">{t.topup_id} · {t.payment_type === "qris" ? "QRIS" : `VA ${t.channel_code}`} · {fmtDate(t.created_at)}</p></div>
          <StatusBadge s={t.status} />
          {t.status === "pending" && <button onClick={() => check(t)} className="h-9 px-3 rounded-lg border text-sm font-semibold">Cek</button>}
        </div>
      ))}
    </div>
  );
};
