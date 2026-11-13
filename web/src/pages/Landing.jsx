import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ArrowRight, Building2, User, MessageCircle, Clapperboard, Upload, Wallet, Megaphone, BadgeDollarSign, Eye } from "lucide-react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { CampaignCard } from "@/components/CampaignCard";
import { InstructionDialog } from "@/components/CampaignDialogs";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Slider } from "@/components/ui/slider";
import { useAuth } from "@/context/AuthContext";
import { api, rp, num } from "@/lib/api";

const STEPS = {
  creator: [[Clapperboard, "Pilih campaign", "Cari campaign dengan rate terbaik sesuai niche kamu."], [Upload, "Posting & submit", "Upload video di TikTok, IG, Threads atau YouTube, lalu kirim link-nya."], [Wallet, "Tarik cuan", "Views diverifikasi, saldo masuk. Tarik mulai Rp 50.000."]],
  brand: [[Megaphone, "Buat campaign", "Tulis brief, pilih platform & kategori."], [BadgeDollarSign, "Set rate per 1K views", "Bayar hanya untuk views yang benar-benar terjadi."], [Eye, "Dapat ribuan views", "Ratusan kreator posting konten untuk brand kamu."]],
};

export default function Landing() {
  const [role, setRole] = useState("creator");
  const [sections, setSections] = useState(null);
  const [payouts, setPayouts] = useState([]);
  const [views, setViews] = useState([100000]);
  const [info, setInfo] = useState(null);
  const { user, login } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    api.get("/campaigns/sections").then((r) => setSections(r.data));
    api.get("/public/payouts").then((r) => setPayouts(r.data));
  }, []);

  const start = () => (user ? navigate(user.role ? "/dashboard" : "/onboarding") : login(role === "brand" ? "/onboarding" : "/dashboard"));
  const goSubmit = () => (user ? navigate("/bounty") : login("/bounty"));
  const avgRate = 5000;
  const ticker = payouts.length ? payouts.map((p) => [p.name, `+${rp(p.amount)}`]) : (sections?.top_rate || []).map((c) => [c.title, `${rp(c.rate_per_1k)}/1K`]);

  return (
    <div className="bg-[#F8FAFC]">
      <Navbar />
      <section className="px-3 pt-3">
        <div className="relative overflow-hidden rounded-[32px] min-h-[640px] flex items-center hero-gradient grain">
          <div className="relative z-10 max-w-5xl mx-auto px-6 text-center py-24">
            <h1 className="text-5xl sm:text-6xl lg:text-7xl font-extrabold tracking-tighter leading-[0.95] text-slate-900 animate-rise" data-testid="hero-title">
              Digaji bikin konten<br />dari manapun.
            </h1>
            <p className="mt-7 text-base sm:text-lg text-slate-800 max-w-xl mx-auto animate-rise [animation-delay:120ms]">
              <b>100% gratis</b>, platform kreator/clipping paling <b>gampang</b> dan <b>lancar</b>. Tinggal posting, dibayar per view, saldo bisa langsung ditarik.
            </p>
            <div className="mt-9 inline-flex p-1.5 rounded-2xl bg-slate-900 shadow-2xl animate-rise [animation-delay:220ms]">
              {[["brand", "Saya Brand", Building2], ["creator", "Saya Kreator", User]].map(([k, l, I]) => (
                <button key={k} data-testid={`hero-role-${k}`} onClick={() => setRole(k)}
                  className={`h-12 px-3 sm:px-5 whitespace-nowrap rounded-xl flex items-center gap-2 font-bold transition-colors ${role === k ? "bg-white text-slate-900" : "text-white hover:text-orange-200"}`}>
                  <I className={`h-4 w-4 ${role === k ? "text-[#FF5500]" : ""}`} /> {l}
                </button>
              ))}
            </div>
            <div className="mt-6 flex flex-wrap gap-3 justify-center animate-rise [animation-delay:320ms]">
              <button data-testid="hero-start-button" onClick={start} className="h-14 px-8 rounded-2xl bg-white text-[#FF5500] font-bold flex items-center gap-2 shadow-lg hover:scale-[1.03] active:scale-95 transition-transform">
                {role === "brand" ? "Buat Campaign" : "Mulai Sekarang"} <ArrowRight className="h-4 w-4" />
              </button>
              <a data-testid="hero-community-button" href="https://discord.com" target="_blank" rel="noreferrer" className="h-14 px-8 rounded-2xl bg-white/15 border border-white/40 text-white font-bold flex items-center gap-2 backdrop-blur hover:bg-white/25 transition-colors">
                <MessageCircle className="h-4 w-4" /> Gabung Komunitas
              </a>
            </div>
          </div>
        </div>
      </section>

      {ticker.length > 0 && (
        <section className="py-8 overflow-hidden" data-testid="payout-ticker">
          <p className="text-center text-slate-500 mb-5">{payouts.length ? "Hasil bayaran asli di trybuzzer" : "Rate campaign yang lagi buka"}</p>
          <div className="flex w-max animate-marquee gap-4">
            {[...ticker, ...ticker].map(([n, a], i) => (
              <div key={i} className="flex items-center gap-3 bg-white rounded-xl border border-slate-200 px-4 py-2.5 shadow-sm">
                <div className="h-8 w-8 rounded-full bg-orange-100 text-[#FF5500] grid place-items-center font-bold text-sm">{n[0]}</div>
                <div><p className="text-sm font-semibold max-w-[180px] truncate">{n}</p><p className="text-xs font-bold text-[#FF5500]">{a}</p></div>
              </div>
            ))}
          </div>
        </section>
      )}

      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20" id="cara-kerja">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-[#FF5500]">Gimana caranya?</p>
        <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight mt-3 max-w-xl">{role === "brand" ? "Bayar per performa, bukan per janji." : "Tiga langkah dari konten ke cuan."}</h2>
        <div className="grid md:grid-cols-3 gap-5 mt-12">
          {STEPS[role].map(([I, t, d], i) => (
            <div key={t} className="bg-white rounded-2xl border border-slate-200 p-8 relative overflow-hidden group hover:border-orange-300 transition-colors">
              <span className="absolute -right-2 -top-6 text-[120px] font-black text-slate-50 group-hover:text-orange-50 transition-colors">{i + 1}</span>
              <I className="relative h-8 w-8 text-[#FF5500]" />
              <h3 className="relative mt-6 text-xl font-bold">{t}</h3>
              <p className="relative mt-2 text-slate-600">{d}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-20 grid lg:grid-cols-12 gap-6">
        <div className="lg:col-span-5 bg-slate-900 text-white rounded-3xl p-8 sm:p-10" data-testid="earnings-calculator">
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-orange-400">Kalkulator cuan</p>
          <h3 className="text-2xl font-extrabold mt-3">Kalau videomu tembus</h3>
          <p className="text-4xl font-black mt-4" data-testid="calc-views">{num(views[0])} views</p>
          <Slider data-testid="calc-slider" className="mt-6 [&>span:first-child]:bg-white/20 [&>span:first-child>span]:bg-[#FF5500]" min={1000} max={2000000} step={1000} value={views} onValueChange={setViews} />
          <p className="mt-8 text-slate-400 text-sm">Estimasi penghasilan (rate rata-rata {rp(avgRate)}/1K)</p>
          <p className="text-4xl font-black text-orange-400 mt-1" data-testid="calc-result">{rp(Math.floor((views[0] / 1000) * avgRate))}</p>
        </div>
        <div className="lg:col-span-7 bg-white rounded-3xl border border-slate-200 p-8 sm:p-10">
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-[#FF5500]">FAQ</p>
          <Accordion type="single" collapsible className="mt-4">
            {[["Daftarnya bayar?", "Tidak. 100% gratis untuk kreator. Cukup login pakai akun Google."], ["Minimal penarikan berapa?", "Minimal Rp 50.000 ke rekening bank atau e-wallet. Diproses manual oleh tim kami."], ["Berapa lama review video?", "Konten direview brand/admin, lalu setelah views tercapai kamu klaim dan views diverifikasi sebelum saldo masuk."], ["Bagaimana mencegah kecurangan?", "Setiap link video hanya bisa didaftarkan sekali, views diverifikasi manual, dan akun yang memakai bot akan diblokir."]].map(([q, a], i) => (
              <AccordionItem key={q} value={`f${i}`}>
                <AccordionTrigger data-testid={`faq-${i}`} className="text-left font-bold">{q}</AccordionTrigger>
                <AccordionContent className="text-slate-600">{a}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </section>

      {sections?.trending?.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-24">
          <div className="flex items-end justify-between">
            <div>
              <h2 className="text-2xl font-extrabold tracking-tight">Lagi rame minggu ini</h2>
              <p className="text-sm text-slate-500">Campaign paling banyak disubmit.</p>
            </div>
            <button data-testid="landing-see-all" onClick={() => navigate("/bounty")} className="text-sm font-bold text-[#FF5500] flex items-center gap-1">Lihat semua <ArrowRight className="h-4 w-4" /></button>
          </div>
          <div className="mt-6 flex gap-8 overflow-x-auto pb-4 pl-6 snap-x no-scrollbar">
            {sections.trending.slice(0, 6).map((c, i) => <CampaignCard key={c.campaign_id} c={c} rank={i + 1} onInfo={setInfo} onSubmit={goSubmit} />)}
          </div>
        </section>
      )}
      <InstructionDialog c={info} onClose={() => setInfo(null)} onSubmit={goSubmit} />
      <Footer />
    </div>
  );
}
