import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { PlatformIcon } from "@/components/PlatformIcon";
import { api, rp, num, errMsg, fmtDate, PLATFORMS } from "@/lib/api";

export const InstructionDialog = ({ c, onClose, onSubmit }) => (
  <Dialog open={!!c} onOpenChange={(o) => !o && onClose()}>
    <DialogContent className="rounded-2xl max-w-lg" data-testid="instruction-dialog">
      {c && (
        <>
          <DialogHeader>
            <DialogTitle className="text-xl">{c.title}</DialogTitle>
            <DialogDescription>oleh {c.brand_name} · tutup {fmtDate(c.deadline)}</DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-3 gap-2 text-center">
            <Stat label="Rate" value={`${rp(c.rate_per_1k)}/1K`} />
            <Stat label="Min. views" value={num(c.min_views)} />
            <Stat label="Sisa budget" value={`${c.budget_left_pct}%`} />
          </div>
          <div className="flex gap-2 flex-wrap">
            {c.platforms.map((p) => (
              <span key={p} className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-100 text-sm"><PlatformIcon p={p} /> {PLATFORMS[p]}</span>
            ))}
          </div>
          <pre className="whitespace-pre-wrap font-sans text-sm bg-slate-50 rounded-xl p-4 max-h-64 overflow-auto" data-testid="instruction-text">{c.instructions}</pre>
          <button data-testid="instruction-submit-button" onClick={() => { onClose(); onSubmit(c); }} className="h-11 rounded-xl bg-[#FF5500] text-white font-bold hover:bg-[#E04B00]">
            Submit video
          </button>
        </>
      )}
    </DialogContent>
  </Dialog>
);

const Stat = ({ label, value }) => (
  <div className="rounded-xl bg-orange-50 p-3">
    <p className="text-[11px] uppercase tracking-wider text-slate-500 font-semibold">{label}</p>
    <p className="font-bold text-sm mt-1">{value}</p>
  </div>
);

export const SubmitDialog = ({ c, onClose, onDone }) => {
  const [platform, setPlatform] = useState("");
  const [url, setUrl] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => { if (c) { setPlatform(c.platforms[0]); setUrl(""); } }, [c]);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      await api.post("/submissions", { campaign_id: c.campaign_id, platform, video_url: url });
      toast.success("Video berhasil disubmit! Tunggu review brand.");
      onClose();
      onDone?.();
    } catch (err) {
      toast.error(errMsg(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={!!c} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="rounded-2xl max-w-md" data-testid="submit-dialog">
        {c && (
          <form onSubmit={submit} className="space-y-4">
            <DialogHeader>
              <DialogTitle>Submit video</DialogTitle>
              <DialogDescription>{c.title}</DialogDescription>
            </DialogHeader>
            <div className="flex gap-2 flex-wrap">
              {c.platforms.map((p) => (
                <button type="button" key={p} data-testid={`submit-platform-${p}`} onClick={() => setPlatform(p)}
                  className={`flex items-center gap-1.5 px-3 h-10 rounded-xl border text-sm font-semibold transition-colors ${platform === p ? "bg-slate-900 text-white border-slate-900" : "border-slate-200 hover:bg-slate-50"}`}>
                  <PlatformIcon p={p} /> {PLATFORMS[p]}
                </button>
              ))}
            </div>
            <input data-testid="submit-video-url-input" required value={url} onChange={(e) => setUrl(e.target.value)}
              placeholder={`https://www.${platform === "youtube" ? "youtube.com/shorts" : platform === "threads" ? "threads.net/@kamu/post" : platform + ".com/@kamu/video"}/...`}
              className="w-full h-12 px-4 rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-[#FF5500]" />
            <p className="text-xs text-slate-500">Video harus publik. Setelah konten disetujui, kamu bisa klaim views saat sudah mencapai minimal {num(c.min_views)} views.</p>
            <button data-testid="submit-video-confirm-button" disabled={busy} className="w-full h-12 rounded-xl bg-[#FF5500] text-white font-bold hover:bg-[#E04B00] disabled:opacity-60 active:scale-95 transition-transform">
              {busy ? "Mengirim..." : "Kirim submission"}
            </button>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
};
