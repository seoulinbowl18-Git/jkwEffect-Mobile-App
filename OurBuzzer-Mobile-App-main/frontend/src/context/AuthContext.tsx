import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { Platform } from "react-native";
import * as Linking from "expo-linking";
import * as WebBrowser from "expo-web-browser";
import { storage } from "@/src/utils/storage";
import { ApiError, setToken, setUnauthorizedHandler } from "@/src/api/client";
import { authApi } from "@/src/api/services";
import type { User } from "@/src/api/types";

WebBrowser.maybeCompleteAuthSession();

const TOKEN_KEY = "session_token";
const AUTH_URL = "https://auth.emergentagent.com/?redirect=";

type Ctx = {
  user: User | null | undefined; // undefined = loading
  login: () => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
  setUser: (u: User) => void;
  busy: boolean;
};
const AuthContext = createContext<Ctx>({} as Ctx);

const extractSessionId = (url?: string | null) => {
  if (!url) return null;
  const m = url.match(/[?#&]session_id=([^&#]+)/);
  return m ? decodeURIComponent(m[1]) : null;
};

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUserState] = useState<User | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const sent = useRef(new Set<string>());

  const clear = useCallback(async () => {
    setToken(null);
    await storage.removeItem(TOKEN_KEY);
    setUserState(null);
  }, []);

  useEffect(() => { setUnauthorizedHandler(() => { clear(); }); }, [clear]);

  const exchange = useCallback(async (sid: string) => {
    if (sent.current.has(sid)) return false;
    sent.current.add(sid);
    setBusy(true);
    try {
      const res = await authApi.exchange(sid);
      await storage.setItem(TOKEN_KEY, res.session_token);
      setToken(res.session_token);
      const { session_token: _t, ...u } = res as any;
      delete u.user;
      setUserState(u as User);
      if (Platform.OS === "web") {
        const url = new URL(window.location.href);
        url.searchParams.delete("session_id");
        const hash = url.hash.replace(/^#/, "").split("&").filter((p) => p && !p.startsWith("session_id=")).join("&");
        url.hash = hash ? `#${hash}` : "";
        window.history.replaceState(window.history.state, "", url.toString());
      }
      return true;
    } catch {
      setUserState(null);
      return false;
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => {
    (async () => {
      const initial = Platform.OS === "web" ? window.location.href : await Linking.getInitialURL();
      const sid = extractSessionId(initial);
      if (sid && (await exchange(sid))) return;
      const t = await storage.getItem(TOKEN_KEY);
      if (!t) return setUserState(null);
      setToken(t);
      try { setUserState(await authApi.me()); } catch (e) {
        if (e instanceof ApiError && e.status === 401) await clear();
        else setUserState(null);
      }
    })();
    if (Platform.OS === "web") return;
    const sub = Linking.addEventListener("url", ({ url }) => {
      const sid = extractSessionId(url);
      if (sid) exchange(sid);
    });
    return () => sub.remove();
  }, [exchange, clear]);

  const login = useCallback(async () => {
    if (Platform.OS === "web") {
      window.location.href = AUTH_URL + encodeURIComponent(window.location.origin + "/");
      return;
    }
    const redirect = Linking.createURL("");
    let captured: string | null = null;
    const sub = Linking.addEventListener("url", ({ url }) => { captured = url; });
    try {
      const result = await WebBrowser.openAuthSessionAsync(AUTH_URL + encodeURIComponent(redirect), redirect);
      const url = (result.type === "success" ? result.url : null) || captured || (await Linking.getInitialURL());
      const sid = extractSessionId(url);
      if (sid) await exchange(sid);
    } finally {
      sub.remove();
    }
  }, [exchange]);

  const logout = useCallback(async () => {
    try { await authApi.logout(); } catch {}
    await clear();
  }, [clear]);

  const refresh = useCallback(async () => {
    try { setUserState(await authApi.me()); } catch {}
  }, []);

  return (
    <AuthContext.Provider value={{ user, login, logout, refresh, setUser: setUserState, busy }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
