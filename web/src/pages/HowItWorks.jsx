import { useNavigate } from "react-router-dom";
import { Clapperboard, Upload, BadgeCheck, Wallet, Megaphone, Eye, ArrowRight, Flame } from "lucide-react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { useAuth } from "@/context/AuthContext";

const CREATOR = [[Clapperboard, "Pilih campaign", "Buka Cari Cuan, baca instruksi campaign dan rate per 1.000 views."], [Upload, "Posting & submit link", "Posting video publik di platform yang diminta, lalu submit link-nya. Brand mereview kontenmu."], [Eye, "Klaim views", "Setelah konten disetujui dan views melewati minimum, klik Klaim views."], [BadgeCheck, "Verifikasi", "Brand/admin mengecek views asli. Payout = views ÷ 1.000 × rate."], [Wallet, "Tarik saldo", "Tarik ke bank / e-wallet mulai Rp 50.000. Diproses manual oleh admin."], [Flame, "Jaga streak", "Submit minimal 1 video tiap hari untuk menjaga streak harianmu."]];
const BRAND = [[Wallet, "Top up saldo", "Isi saldo brand via QRIS atau Virtual Account."], [Megaphone, "Buat campaign", "Set rate per 1K views, minimum views, budget, platform dan brief."], [BadgeCheck, "Review & verifikasi", "Setujui konten yang sesuai brief, verifikasi views sebelum kreator dibayar."], [Eye, "Bayar per view", "Budget hanya terpakai untuk views terverifikasi. Sisa budget di-refund saat campaign ditutup."]];

export default function HowItWorks({ brand }) {
  const navigate = useNavigate();
  const { user, login } = useAuth();
  const steps = brand ? BRAND : CREATOR;
  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      <Navbar />
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-[#FF5500]">{brand ? "Untuk brand" : "Gimana caranya?"}</p>
        <h1 className="text-4xl sm:text-5xl font-extrabold tracking-tight mt-3 max-w-2xl" data-testid="how-title">{brand ? "Ribuan kreator, bayar hanya untuk views asli." : "Dari konten ke cuan, tanpa ribet."}</h1>
        <div className="mt-12 grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {steps.map(([I, t, d], i) => (
            <div key={t} className="bg-white rounded-2xl border border-slate-200 p-7 animate-rise" style={{ animationDelay: `${i * 70}ms` }}>
              <div className="flex items-center justify-between"><I className="h-7 w-7 text-[#FF5500]" /><span className="text-sm font-black text-slate-300">0{i + 1}</span></div>
              <h3 className="mt-5 font-bold text-lg">{t}</h3>
              <p className="mt-2 text-slate-600 text-sm leading-relaxed">{d}</p>
            </div>
          ))}
        </div>
        <button data-testid="how-cta" onClick={() => (user ? navigate(user.role ? "/dashboard" : "/onboarding") : login("/onboarding"))} className="mt-12 h-14 px-8 rounded-2xl bg-[#FF5500] text-white font-bold flex items-center gap-2 hover:bg-[#E04B00] active:scale-95 transition-transform">
          {brand ? "Buat campaign" : "Mulai sekarang"} <ArrowRight className="h-4 w-4" />
        </button>
      </main>
      <Footer />
    </div>
  );
}
