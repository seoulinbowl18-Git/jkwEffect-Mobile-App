import { NavLink, useNavigate } from "react-router-dom";
import { Logo } from "@/components/Logo";
import { NotificationBell } from "@/components/NotificationBell";
import { useAuth } from "@/context/AuthContext";

const linkCls = ({ isActive }) =>
  `px-3 py-2 rounded-lg text-[15px] font-medium transition-colors ${isActive ? "bg-slate-100 text-slate-900" : "text-slate-600 hover:text-slate-900"}`;

export const Navbar = () => {
  const { user, login, logout } = useAuth();
  const navigate = useNavigate();
  return (
    <header className="sticky top-0 z-40 bg-white/80 backdrop-blur-xl border-b border-slate-100">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-[72px] flex items-center gap-6">
        <Logo />
        <nav className="hidden md:flex items-center gap-1 ml-4">
          <NavLink to="/cara-kerja" className={linkCls} data-testid="nav-how">Gimana Caranya?</NavLink>
          <NavLink to="/bounty" className={linkCls} data-testid="nav-bounty">Cari Cuan</NavLink>
          {user?.role && <NavLink to="/dashboard" className={linkCls} data-testid="nav-dashboard">Dashboard</NavLink>}
          {user?.role === "admin" && <NavLink to="/admin" className={linkCls} data-testid="nav-admin">Admin</NavLink>}
        </nav>
        <div className="ml-auto flex items-center gap-2">
          {user ? (
            <>
              <NotificationBell />
              <button data-testid="logout-button" onClick={logout} className="h-11 px-4 rounded-xl border border-slate-200 bg-white font-semibold hover:bg-slate-50 active:scale-95 transition-transform">
                Keluar
              </button>
            </>
          ) : (
            <>
              <button data-testid="nav-login-button" onClick={() => login()} className="h-11 px-5 rounded-xl bg-[#FF5500] text-white font-semibold hover:bg-[#E04B00] active:scale-95 transition-[background-color,transform]">
                Masuk
              </button>
              <button data-testid="nav-brand-button" onClick={() => navigate("/untuk-brand")} className="hidden sm:block h-11 px-4 rounded-xl border border-slate-200 bg-white font-semibold hover:bg-slate-50">
                Untuk Brand
              </button>
            </>
          )}
        </div>
      </div>
      <nav className="md:hidden flex gap-1 px-4 pb-2 overflow-x-auto">
        <NavLink to="/bounty" className={linkCls}>Cari Cuan</NavLink>
        {user?.role && <NavLink to="/dashboard" className={linkCls}>Dashboard</NavLink>}
        {user?.role === "admin" && <NavLink to="/admin" className={linkCls}>Admin</NavLink>}
        <NavLink to="/cara-kerja" className={linkCls}>Caranya</NavLink>
      </nav>
    </header>
  );
};
