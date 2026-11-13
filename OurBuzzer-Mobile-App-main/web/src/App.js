import "@/App.css";
import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";
import { Toaster } from "@/components/ui/sonner";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import AuthCallback from "@/components/AuthCallback";
import Landing from "@/pages/Landing";
import Bounty from "@/pages/Bounty";
import Onboarding from "@/pages/Onboarding";
import CreatorDashboard from "@/pages/CreatorDashboard";
import BrandDashboard from "@/pages/BrandDashboard";
import AdminPanel from "@/pages/AdminPanel";
import HowItWorks from "@/pages/HowItWorks";

const Guard = ({ children, roles, needRole = true }) => {
  const { user, loading, login } = useAuth();
  if (loading) return <div className="min-h-screen grid place-items-center"><div className="h-8 w-8 rounded-full border-4 border-orange-200 border-t-[#FF5500] animate-spin" /></div>;
  if (!user) { login(window.location.pathname); return null; }
  if (needRole && !user.role) return <Navigate to="/onboarding" replace />;
  if (!needRole && user.role) return <Navigate to="/dashboard" replace />;
  if (roles && !roles.includes(user.role)) return <Navigate to="/dashboard" replace />;
  return children;
};

const Dashboard = () => {
  const { user } = useAuth();
  if (user.role === "admin") return <Navigate to="/admin" replace />;
  return user.role === "brand" ? <BrandDashboard /> : <CreatorDashboard />;
};

function AppRouter() {
  const location = useLocation();
  if (location.hash?.includes("session_id=")) return <AuthCallback />;
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/bounty" element={<Bounty />} />
      <Route path="/cara-kerja" element={<HowItWorks />} />
      <Route path="/untuk-brand" element={<HowItWorks brand />} />
      <Route path="/onboarding" element={<Guard needRole={false}><Onboarding /></Guard>} />
      <Route path="/dashboard" element={<Guard><Dashboard /></Guard>} />
      <Route path="/admin" element={<Guard roles={["admin"]}><AdminPanel /></Guard>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRouter />
        <Toaster position="top-center" richColors />
      </AuthProvider>
    </BrowserRouter>
  );
}
