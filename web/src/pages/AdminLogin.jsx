import { useEffect, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { ArrowLeft, Loader2, MessageCircle, ShieldCheck } from "lucide-react";
import { InputOTP, InputOTPGroup, InputOTPSlot } from "@/components/ui/input-otp";
import { useAuth } from "@/context/AuthContext";
import { api, errMsg } from "@/lib/api";
import { inputCls } from "@/components/Shared";

// Login Admin Pusat (Owner): nomor WhatsApp → OTP 6 digit via Fonnte.
// Kreator & Brand tetap masuk dengan Google Sign-In.
export default function AdminLogin() {
  const { user, loading, setUser } = useAuth();
  const navigate = useNavigate();
  const [step, setStep] = useState("phone");
  const [phone, setPhone] = useState("");
  const [masked, setMasked] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [resendIn, setResendIn] = useState(0);

  useEffect(() => {
    if (resendIn <= 0) return undefined;
    const t = setTimeout(() => setResendIn((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [resendIn]);

  if (!loading && user?.role === "admin") return <Navigate to="/admin" replace />;

  const requestOtp = async (e) => {
    e?.preventDefault();
    if (!phone.trim()) return toast.error("Masukkan nomor WhatsApp");
    setBusy(true);
    try {
      const { data } = await api.post("/admin/request-otp", { phone });
      setMasked(data.phone);
      setResendIn(data.resend_in || 60);
      setCode("");
      setStep("otp");
      toast.success("Kode OTP dikirim lewat WhatsApp");
    } catch (err) {
      toast.error(errMsg(err));
    } finally {
      setBusy(false);
    }
  };

  const verify = async (value = code) => {
    if (value.length !== 6) return;
    setBusy(true);
    try {
      const { data } = await api.post("/admin/verify-otp", { phone, code: value });
      setUser(data.user || data);
      toast.success("Berhasil masuk sebagai Admin Pusat");
      navigate("/admin", { replace: true });
    } catch (err) {
      toast.error(errMsg(err));
      setCode("");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F8F9FC] grid place-items-center px-4 py-10">
      <div className="w-full max-w-md">
        <div className="rounded-[28px] bg-gradient-to-br from-[#A50021] via-[#C8102E] to-[#F21D43] p-7 text-white shadow-xl shadow-red-200">
          <ShieldCheck className="h-9 w-9" />
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight">Admin Pusat</h1>
          <p className="mt-1 text-white/85">Masuk khusus Owner GIBRAN2029 dengan kode OTP WhatsApp.</p>
        </div>

        <div className="-mt-4 rounded-3xl bg-white p-6 shadow-lg shadow-slate-200/60">
          {step === "phone" ? (
            <form onSubmit={requestOtp} data-testid="admin-login-phone-step">
              <label htmlFor="admin-phone" className="text-sm font-semibold text-slate-700">Nomor WhatsApp</label>
              <input
                id="admin-phone"
                data-testid="admin-login-phone"
                className={`${inputCls} mt-2 h-12 text-base focus:ring-[#C8102E]`}
                inputMode="tel"
                autoComplete="tel"
                placeholder="081234567890"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                autoFocus
              />
              <button
                type="submit"
                data-testid="admin-login-send"
                disabled={busy}
                className="mt-5 h-12 w-full rounded-2xl bg-gradient-to-r from-[#F21D43] via-[#C8102E] to-[#A50021] font-bold text-white flex items-center justify-center gap-2 shadow-lg shadow-red-200 disabled:opacity-60"
              >
                {busy ? <Loader2 className="h-5 w-5 animate-spin" /> : <MessageCircle className="h-5 w-5" />}
                Kirim kode OTP via WhatsApp
              </button>
            </form>
          ) : (
            <div data-testid="admin-login-otp-step">
              <button onClick={() => setStep("phone")} className="text-sm font-semibold text-[#C8102E] flex items-center gap-1">
                <ArrowLeft className="h-4 w-4" /> Ganti nomor
              </button>
              <p className="mt-4 text-slate-700">
                Masukkan 6 digit kode yang dikirim ke WhatsApp <span className="font-bold">{masked}</span>.
              </p>
              <div className="mt-5 flex justify-center">
                <InputOTP
                  maxLength={6}
                  value={code}
                  onChange={setCode}
                  onComplete={verify}
                  disabled={busy}
                  autoFocus
                  inputMode="numeric"
                  pattern="^[0-9]*$"
                  data-testid="admin-login-otp"
                >
                  <InputOTPGroup className="gap-2">
                    {[0, 1, 2, 3, 4, 5].map((i) => (
                      <InputOTPSlot key={i} index={i} className="h-12 w-11 rounded-xl border text-lg font-bold first:rounded-xl last:rounded-xl" />
                    ))}
                  </InputOTPGroup>
                </InputOTP>
              </div>
              <button
                data-testid="admin-login-verify"
                onClick={() => verify()}
                disabled={busy || code.length !== 6}
                className="mt-6 h-12 w-full rounded-2xl bg-gradient-to-r from-[#F21D43] via-[#C8102E] to-[#A50021] font-bold text-white flex items-center justify-center gap-2 disabled:opacity-60"
              >
                {busy && <Loader2 className="h-5 w-5 animate-spin" />} Verifikasi & Masuk
              </button>
              <button
                data-testid="admin-login-resend"
                onClick={requestOtp}
                disabled={busy || resendIn > 0}
                className="mt-3 w-full text-sm font-semibold text-[#C8102E] disabled:text-slate-400"
              >
                {resendIn > 0 ? `Kirim ulang kode dalam ${resendIn} detik` : "Kirim ulang kode"}
              </button>
            </div>
          )}
        </div>
        <p className="mt-6 text-center text-xs text-slate-500">
          Kreator & Brand? Masuk dengan Google di halaman utama.
        </p>
      </div>
    </div>
  );
}
