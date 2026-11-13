import { Info, ChevronRight } from "lucide-react";
import { PlatformIcon } from "@/components/PlatformIcon";
import { rp, num } from "@/lib/api";

export const CampaignCard = ({ c, onInfo, onSubmit, rank }) => {
  const pct = c.budget_left_pct;
  const bar = pct > 50 ? "bg-emerald-500" : pct > 20 ? "bg-amber-500" : "bg-red-500";
  return (
    <div className="relative shrink-0 w-[280px] snap-start" data-testid={`campaign-card-${c.campaign_id}`}>
      {rank && (
        <span className="absolute -left-11 bottom-16 text-[120px] leading-none font-black text-transparent [-webkit-text-stroke:2px_#E2E8F0] select-none">{rank}</span>
      )}
      <div className="relative bg-white rounded-2xl border border-slate-200 p-2 hover:-translate-y-1 hover:shadow-xl hover:shadow-orange-100 transition-[transform,box-shadow] duration-300">
        <div className="relative h-36 rounded-xl overflow-hidden bg-slate-100">
          {c.thumbnail && <img src={c.thumbnail} alt={c.title} className="h-full w-full object-cover" loading="lazy" />}
          <span className="absolute top-2 left-2 px-2.5 py-1 rounded-lg bg-white text-xs font-semibold">{c.category}</span>
        </div>
        <div className="px-2 pt-3 pb-2">
          <div className="flex items-center justify-between">
            <div className="flex gap-1.5 text-slate-700">{c.platforms.map((p) => <PlatformIcon key={p} p={p} />)}</div>
            <span className="px-2 py-0.5 rounded-md bg-orange-50 text-[#FF5500] font-bold text-sm" data-testid="campaign-rate">
              {rp(c.rate_per_1k)} <span className="text-[10px] font-semibold">/1K</span>
            </span>
          </div>
          <h3 className="mt-2 font-bold text-[15px] leading-snug line-clamp-2 min-h-[42px]">{c.title}</h3>
          <div className="mt-3 flex justify-between text-xs text-slate-500">
            <span>Min. <b className="text-slate-800">{num(c.min_views)}</b> views</span>
            <span>Budget <b className="text-slate-800">{pct}%</b></span>
          </div>
          <div className="mt-1.5 h-1.5 rounded-full bg-slate-100 overflow-hidden">
            <div className={`h-full ${bar}`} style={{ width: `${pct}%` }} />
          </div>
          <div className="mt-3 grid grid-cols-[auto_1fr] gap-2">
            <button data-testid={`campaign-info-${c.campaign_id}`} onClick={() => onInfo(c)} className="h-10 px-3 rounded-xl border border-slate-200 text-sm font-semibold flex items-center gap-1.5 hover:bg-slate-50">
              <Info className="h-4 w-4" /> Instruksi
            </button>
            <button data-testid={`campaign-submit-${c.campaign_id}`} onClick={() => onSubmit(c)} className="h-10 rounded-xl bg-slate-900 text-white text-sm font-bold flex items-center justify-center gap-1 hover:bg-black active:scale-95 transition-transform">
              Submit <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
