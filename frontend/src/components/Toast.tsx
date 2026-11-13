import React, { createContext, useCallback, useContext, useRef, useState } from "react";
import { StyleSheet, Text } from "react-native";
import Animated, { FadeInUp, FadeOutUp } from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme } from "@/src/theme";

type Kind = "success" | "error" | "info";
const ToastCtx = createContext<(msg: string, kind?: Kind) => void>(() => {});

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const [toast, setToast] = useState<{ msg: string; kind: Kind; id: number } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const show = useCallback((msg: string, kind: Kind = "info") => {
    if (timer.current) clearTimeout(timer.current);
    setToast({ msg, kind, id: Date.now() });
    timer.current = setTimeout(() => setToast(null), 3000);
  }, []);

  const bg = toast?.kind === "success" ? c.success : toast?.kind === "error" ? c.danger : c.ink;
  const fg = toast?.kind === "info" ? c.onInk : "#FFFFFF";
  const icon = toast?.kind === "success" ? "checkmark-circle" : toast?.kind === "error" ? "alert-circle" : "information-circle";

  return (
    <ToastCtx.Provider value={show}>
      {children}
      {toast && (
        <Animated.View
          key={toast.id}
          entering={FadeInUp}
          exiting={FadeOutUp}
          pointerEvents="none"
          testID="app-toast"
          style={[styles.toast, { top: insets.top + 8, backgroundColor: bg }]}
        >
          <Ionicons name={icon as any} size={20} color={fg} />
          <Text style={[styles.text, { color: fg }]} testID="app-toast-text">{toast.msg}</Text>
        </Animated.View>
      )}
    </ToastCtx.Provider>
  );
}

export const useToast = () => useContext(ToastCtx);

const styles = StyleSheet.create({
  toast: {
    position: "absolute", left: 16, right: 16, borderRadius: 14, paddingHorizontal: 16, paddingVertical: 12,
    flexDirection: "row", alignItems: "center", gap: 10, zIndex: 999, elevation: 10,
    shadowColor: "#000", shadowOpacity: 0.2, shadowRadius: 12, shadowOffset: { width: 0, height: 4 },
  },
  text: { flex: 1, fontSize: 14, fontWeight: "600" },
});
