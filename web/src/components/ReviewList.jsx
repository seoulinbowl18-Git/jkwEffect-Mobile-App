import { useState } from "react";
import { toast } from "sonner";
import { ExternalLink, Check, X } from "lucide-react";
import { StatusBadge, inputCls } from "@/components/Shared";
import { PlatformIcon } from "@/components/PlatformIcon";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { api, rp, num, errMsg, fmtDate } from "@/lib/api";

export const ReviewList = ({ items, onChange }) => {
  const [verify, setVerify] = useState(null);
  const review = async (s, action) => {
    const note = action === "reject" ? window.prompt("Alasan penolakan (opsional)") ?? "" : "";
    try { await api.post(`/submissions/${s.submission_id}/review`, { action, note }); toast.success(action === "approve" ? "Konten disetujui" : "Konten ditolak"); onChange(); }
    catch (e) { toast.error(errMsg(e)); }
  };
  if (!items.length) return <p className="bg-white rounded-2xl border p-10 text-center text-sm text-slate-500" data-testid="review-empty">Tidak ada submission</p>;
  return (
    <div className="bg-white rounded-2xl border border-slate-200 divide-y">
      {items.map((s) => (
        <div key={s.submission_id} className="p-4 sm:p-5 flex flex-col md:flex-row md:items-center gap-3" data-testid={`review-row-${s.submission_id}`}>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2"><PlatformIcon p={s.platform} /><p className="font-bold truncate">{s.creator_name}</p><span className="text-sm text-slate-500 truncate">· {s.campaign_title}</span></div>
            <a href={s.video_url} target="_blank" rel="noreferrer" className="text-sm text-[#FF5500] flex items-center gap-1 truncate">{s.video_url} <ExternalLink className="h-3 w-3 shrink-0" /></a>
            <p className="text-xs text-slate-500">{fmtDate(s.created_at)} {s.claimed_views > 0 && `· klaim ${num(s.claimed_views)} views`} {s.status === "disetujui" && `· verified ${num(s.verified_views)} · dibayar ${rp(s.payout)}`}</p>
          </div>
          <StatusBadge s={s.status} />
          {s.status === "direview" && (
            <div className="flex gap-2">
              <button data-testid={`review-approve-${s.submission_id}`} onClick={() => review(s, "approve")} className="h-9 px-3 rounded-lg bg-emerald-600 text-white text-sm font-bold flex items-center gap-1"><Check className="h-4 w-4" /> Setujui konten</button>
              <button data-testid={`review-reject-${s.submission_id}`} onClick={() => review(s, "reject")} className="h-9 px-3 rounded-lg border text-sm font-bold flex items-center gap-1"><X className="h-4 w-4" /> Tolak</button>
            </div>
          )}
          {s.status === "diproses" && (
            <button data-testid={`verify-open-${s.submission_id}`} onClick={() => setVerify(s)} className="h-9 px-4 rounded-lg bg-slate-900 text-white text-sm font-bold">Verifikasi views</button>
          )}
        </div>
      ))}
      <VerifyDialog s={verify} onClose={() => setVerify(null)} onDone={onChange} />
    </div>
  );
};

const VerifyDialog = ({ s, onClose, onDone }) => {
  const [views, setViews] = useState("");
  const [note, setNote] = useState("");
  const send = async (action) => {
    try {
      const { data } = await api.post(`/submissions/${s.submission_id}/verify`, { action, verified_views: Number(views || 0), note });
      toast.success(action === "approve" && data.payout ? `Disetujui, kreator dibayar ${rp(data.payout)}` : "Klaim diproses");
      onClose(); onDone(); setViews(""); setNote("");
    } catch (e) { toast.error(errMsg(e)); }
  };
  return (
    <Dialog open={!!s} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="rounded-2xl max-w-md" data-testid="verify-dialog">
        {s && (
          <div className="space-y-4">
            <DialogHeader><DialogTitle>Verifikasi views</DialogTitle><DialogDescription>Buka video, cek jumlah views asli, lalu masukkan angkanya. Kreator klaim {num(s.claimed_views)} views.</DialogDescription></DialogHeader>
            <a href={s.video_url} target="_blank" rel="noreferrer" className="text-sm text-[#FF5500] flex items-center gap-1 break-all">{s.video_url} <ExternalLink className="h-3 w-3" /></a>
            <input data-testid="verify-views-input" type="number" min={0} value={views} onChange={(e) => setViews(e.target.value)} placeholder="Views terverifikasi" className={inputCls} />
            <input data-testid="verify-note-input" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Catatan (opsional)" className={inputCls} />
            <p className="text-sm">Payout: <b className="text-[#FF5500]" data-testid="verify-payout-preview">{rp(Math.floor((Number(views) || 0) / 1000 * s.rate_per_1k))}</b> <span className="text-slate-500">(min. {num(s.min_views)} views, rate {rp(s.rate_per_1k)}/1K)</span></p>
            <div className="grid grid-cols-2 gap-2">
              <button data-testid="verify-reject-button" onClick={() => send("reject")} className="h-11 rounded-xl border font-bold">Tolak</button>
              <button data-testid="verify-approve-button" disabled={!views} onClick={() => send("approve")} className="h-11 rounded-xl bg-emerald-600 text-white font-bold disabled:opacity-50">Setujui & bayar</button>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
};
