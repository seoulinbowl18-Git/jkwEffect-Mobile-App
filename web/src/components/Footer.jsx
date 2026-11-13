import { Logo } from "@/components/Logo";

export const Footer = () => (
  <footer className="bg-[#0B0F1A] text-slate-400 mt-10">
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14 flex flex-col md:flex-row gap-8 justify-between">
      <div>
        <Logo light />
        <p className="mt-3 text-sm max-w-xs">Platform creator marketing berbasis performa. Brand bayar per view, kreator dibayar per view.</p>
      </div>
      <p className="text-sm self-end">© {new Date().getFullYear()} trybuzzer</p>
    </div>
  </footer>
);
