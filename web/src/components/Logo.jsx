import { Link } from "react-router-dom";

export const Logo = ({ light = false }) => (
  <Link to="/" data-testid="nav-logo" className="flex items-center gap-2 select-none">
    <svg width="34" height="24" viewBox="0 0 34 24" fill="none" aria-hidden>
      <path d="M2 14 L9 4 L11 13 L18 3 L20 12 L27 2" stroke="#FF5500" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M8 21 L15 11 L17 20 L24 10 L26 19 L32 10" stroke="#FF8A3D" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
    <span className={`font-extrabold text-2xl tracking-tight ${light ? "text-white" : "text-slate-900"}`}>trybuzzer</span>
  </Link>
);
