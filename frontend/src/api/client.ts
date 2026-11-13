// Thin REST client. All screens go through src/api/services.ts, so swapping the
// data source (e.g. to Supabase later) only touches the service layer.
const BASE = `${process.env.EXPO_PUBLIC_BACKEND_URL}/api`;

let token: string | null = null;
let onUnauthorized: () => void = () => {};

export const setToken = (t: string | null) => { token = t; };
export const setUnauthorizedHandler = (fn: () => void) => { onUnauthorized = fn; };

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

type Opts = { method?: string; body?: unknown; params?: Record<string, string | number | boolean | undefined> };

export async function request<T>(path: string, opts: Opts = {}): Promise<T> {
  const qs = opts.params
    ? "?" + Object.entries(opts.params)
        .filter(([, v]) => v !== undefined && v !== "")
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
        .join("&")
    : "";
  const headers: Record<string, string> = { Accept: "application/json" };
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";
  if (token) headers.Authorization = `Bearer ${token}`;
  let res: Response;
  try {
    res = await fetch(BASE + path + qs, {
      method: opts.method || "GET",
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    });
  } catch {
    throw new ApiError(0, "Tidak ada koneksi internet");
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    if (res.status === 401 && token) onUnauthorized();
    const d = (data as any)?.detail;
    const msg = Array.isArray(d) ? d.map((x: any) => x.msg).join(", ") : d || "Terjadi kesalahan";
    throw new ApiError(res.status, msg);
  }
  return data as T;
}

export const errMsg = (e: unknown) => (e instanceof Error ? e.message : "Terjadi kesalahan");
