import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Search, Sparkles, Lock, ChevronLeft, ChevronRight } from "lucide-react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { CampaignCard } from "@/components/CampaignCard";
import { InstructionDialog, SubmitDialog } from "@/components/CampaignDialogs";
import { StreakBanner } from "@/components/StreakBanner";
import { useAuth } from "@/context/AuthContext";
import { api, CATEGORIES } from "@/lib/api";
import { toast } from "sonner";

const Row = ({ title, desc, items, ranked, onInfo, onSubmit, id }) => {
  const ref = useRef(null);
  const scroll = (d) => ref.current?.scrollBy({ left: d * 600, behavior: "smooth" });
  if (!items?.length) return null;
  return (
    <section className="mt-12" data-testid={`row-${id}`}>
      <div className="flex items-end justify-between">
        <div><h2 className="text-2xl font-extrabold tracking-tight">{title}</h2><p className="text-sm text-slate-500">{desc}</p></div>
        <div className="flex gap-2">
          <button data-testid={`row-${id}-prev`} onClick={() => scroll(-1)} className="h-10 w-10 grid place-items-center rounded-xl border bg-white hover:bg-slate-50"><ChevronLeft className="h-4 w-4" /></button>
          <button data-testid={`row-${id}-next`} onClick={() => scroll(1)} className="h-10 w-10 grid place-items-center rounded-xl border bg-white hover:bg-slate-50"><ChevronRight className="h-4 w-4" /></button>
        </div>
      </div>
      <div ref={ref} className={`mt-5 flex ${ranked ? "gap-10 pl-8" : "gap-4"} overflow-x-auto pb-3 snap-x no-scrollbar`}>
        {items.map((c, i) => <CampaignCard key={c.campaign_id} c={c} rank={ranked ? i + 1 : null} onInfo={onInfo} onSubmit={onSubmit} />)}
      </div>
    </section>
  );
};

export default function Bounty() {
  const { user, login } = useAuth();
  const navigate = useNavigate();
  const [sections, setSections] = useState(null);
  const [tab, setTab] = useState("public");
  const [q, setQ] = useState("");
  const [cat, setCat] = useState("Semua");
  const [all, setAll] = useState([]);
  const [info, setInfo] = useState(null);
  const [sub, setSub] = useState(null);

  useEffect(() => { api.get("/campaigns/sections").then((r) => setSections(r.data)); }, []);
  useEffect(() => {
    const t = setTimeout(() => {
      api.get("/campaigns", { params: { q, category: cat, exclusive: tab === "exclusive" } }).then((r) => setAll(r.data));
    }, 250);
    return () => clearTimeout(t);
  }, [q, cat, tab]);

  const onSubmit = (c) => {
    if (!user) return login("/bounty");
    if (user.role !== "creator") return toast.error("Hanya akun kreator yang bisa submit video");
    setSub(c);
  };
  const browsing = q || tab === "exclusive";

  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="sticky top-[76px] z-30 bg-white/85 backdrop-blur-xl rounded-2xl border border-slate-200 p-2 flex flex-col sm:flex-row gap-2">
          <div className="flex gap-1 p-1 bg-slate-100 rounded-xl">
            <button data-testid="bounty-tab-public" onClick={() => setTab("public")} className={`h-10 px-4 rounded-lg flex items-center gap-2 font-semibold ${tab === "public" ? "bg-white shadow-sm" : "text-slate-600"}`}>
              <Sparkles className="h-4 w-4" /> Public <span className="text-xs text-[#FF5500] font-bold">{sections?.total ?? ""}</span>
            </button>
            <button data-testid="bounty-tab-exclusive" onClick={() => setTab("exclusive")} className={`h-10 px-4 rounded-lg flex items-center gap-2 font-semibold ${tab === "exclusive" ? "bg-white shadow-sm" : "text-slate-600"}`}>
              <Lock className="h-4 w-4" /> Exclusive
            </button>
          </div>
          <div className="flex-1 relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input data-testid="bounty-search-input" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari campaign..." className="w-full h-12 pl-10 pr-4 rounded-xl bg-slate-100 focus:outline-none focus:ring-2 focus:ring-[#FF5500]" />
          </div>
        </div>

        {user?.role === "creator" && <div className="mt-8"><StreakBanner /></div>}

        {!browsing && sections && (
          <>
            <Row id="trending" title="Lagi rame minggu ini" desc="Paling banyak kreator yang submit dalam 7 hari terakhir." items={sections.trending} ranked onInfo={setInfo} onSubmit={onSubmit} />
            <Row id="closing" title="Segera ditutup" desc="Daftarkan videomu sebelum campaign ini tutup." items={sections.closing} onInfo={setInfo} onSubmit={onSubmit} />
            <Row id="toprate" title="Rate tertinggi" desc="Bayaran per 1.000 views paling tinggi." items={sections.top_rate} onInfo={setInfo} onSubmit={onSubmit} />
            <Row id="newest" title="Campaign baru" desc="Campaign yang baru dibuka." items={sections.newest} onInfo={setInfo} onSubmit={onSubmit} />
          </>
        )}

        <section className="mt-14">
          <h2 className="text-2xl font-extrabold tracking-tight flex items-center gap-3">
            {tab === "exclusive" ? "Campaign exclusive" : "Semua campaign"} <span className="text-sm font-semibold px-2 py-0.5 rounded-md bg-slate-100" data-testid="all-count">{all.length}</span>
          </h2>
          <div className="mt-4 flex gap-1 overflow-x-auto no-scrollbar">
            {["Semua", ...CATEGORIES].map((c) => (
              <button key={c} data-testid={`category-${c}`} onClick={() => setCat(c)} className={`h-9 px-4 rounded-lg text-sm font-semibold whitespace-nowrap transition-colors ${cat === c ? "bg-[#FF5500] text-white" : "text-slate-600 hover:bg-white"}`}>{c}</button>
            ))}
          </div>
          {all.length === 0 ? (
            <p className="mt-10 text-center text-slate-500" data-testid="no-campaigns">Belum ada campaign di sini.</p>
          ) : (
            <div className="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-4 [&>div]:w-auto">
              {all.map((c) => <CampaignCard key={c.campaign_id} c={c} onInfo={setInfo} onSubmit={onSubmit} />)}
            </div>
          )}
        </section>
      </main>
      <InstructionDialog c={info} onClose={() => setInfo(null)} onSubmit={onSubmit} />
      <SubmitDialog c={sub} onClose={() => setSub(null)} onDone={() => navigate("/dashboard")} />
      <Footer />
    </div>
  );
}
