import React, { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useAuth } from "@/src/context/AuthContext";
import { authApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import { Button, Field } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { useTheme } from "@/src/theme";

export default function Onboarding() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const { user, setUser, logout } = useAuth();
  const toast = useToast();
  const [role, setRole] = useState<"creator" | "brand">("creator");
  const [brandName, setBrandName] = useState("");
  const [loading, setLoading] = useState(false);

  const save = async () => {
    setLoading(true);
    try {
      setUser(await authApi.setRole(role, role === "brand" ? brandName || user?.name : undefined));
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  const Option = ({ k, icon, title, desc }: { k: "creator" | "brand"; icon: string; title: string; desc: string }) => {
    const on = role === k;
    return (
      <Pressable testID={`onboarding-role-${k}`} onPress={() => setRole(k)} style={[styles.opt, { backgroundColor: c.surface, borderColor: on ? c.primary : c.border, borderWidth: on ? 2 : 1 }]}>
        <View style={[styles.optIcon, { backgroundColor: on ? c.primary : c.surfaceMuted }]}>
          <Ionicons name={icon as any} size={24} color={on ? c.onPrimary : c.textSecondary} />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={[styles.optTitle, { color: c.textPrimary }]}>{title}</Text>
          <Text style={{ color: c.textSecondary, fontSize: 13, marginTop: 2 }}>{desc}</Text>
        </View>
        <Ionicons name={on ? "radio-button-on" : "radio-button-off"} size={22} color={on ? c.primary : c.textMuted} />
      </Pressable>
    );
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="onboarding-screen">
      <KeyboardAwareScrollView bottomOffset={24} contentContainerStyle={{ padding: 20, paddingTop: insets.top + 24, paddingBottom: insets.bottom + 24, gap: 16 }}>
        <Text style={[styles.h1, { color: c.textPrimary }]}>Halo, {user?.name?.split(" ")[0]}!</Text>
        <Text style={{ color: c.textSecondary, fontSize: 15 }}>Kamu mau pakai TryBuzzer sebagai apa? Pilihan ini tidak bisa diubah.</Text>
        <Option k="creator" icon="videocam" title="Kreator" desc="Cari campaign, posting video, dapat cuan dari views." />
        <Option k="brand" icon="megaphone" title="Brand" desc="Buat campaign, bayar per views, review konten kreator." />
        {role === "brand" && (
          <Field testID="onboarding-brand-name-input" label="Nama brand" value={brandName} onChangeText={setBrandName} placeholder={user?.name} />
        )}
        <Button testID="onboarding-continue-button" title="Lanjutkan" onPress={save} loading={loading} />
        <Button testID="onboarding-logout-button" title="Keluar" variant="outline" onPress={logout} />
      </KeyboardAwareScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  h1: { fontSize: 30, fontWeight: "900", letterSpacing: -0.8 },
  opt: { flexDirection: "row", alignItems: "center", gap: 14, padding: 16, borderRadius: 18 },
  optIcon: { width: 48, height: 48, borderRadius: 14, alignItems: "center", justifyContent: "center" },
  optTitle: { fontSize: 17, fontWeight: "800" },
});
