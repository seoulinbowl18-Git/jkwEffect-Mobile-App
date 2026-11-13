import React, { useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { Image } from "expo-image";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { authApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import { useAuth } from "@/src/context/AuthContext";
import { TabHeader } from "@/src/components/ScreenHeader";
import { Button, Card, Field } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

export default function Profile() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const { user, setUser, logout } = useAuth();
  const p = user?.profile || {};
  const [f, setF] = useState({
    name: user?.name || "", tiktok: p.tiktok || "", instagram: p.instagram || "", brand_name: p.brand_name || "",
    bank_method: p.bank_method || "", bank_account: p.bank_account || "", bank_holder: p.bank_holder || "",
  });
  const [loading, setLoading] = useState(false);
  const set = (k: keyof typeof f) => (v: string) => setF((s) => ({ ...s, [k]: v }));
  const isBrand = user?.role === "brand";
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  const roleLabel = isBrand ? "Brand" : user?.role === "admin" ? "Admin" : "Kreator";

  const save = async () => {
    setLoading(true);
    try {
      setUser(await authApi.updateProfile(f));
      toast("Profil disimpan", "success");
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="profile-screen">
      <TabHeader title="Profil" />
      <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: 16, paddingTop: 4, gap: 16, paddingBottom: bottomChrome + 24 }}>
        <Card style={styles.user}>
          {user?.picture ? (
            <Image source={{ uri: user.picture }} style={styles.avatar} />
          ) : (
            <View style={[styles.avatar, { backgroundColor: c.primary, alignItems: "center", justifyContent: "center" }]}>
              <Text style={{ color: c.onPrimary, fontWeight: "900", fontSize: 22 }}>{user?.name?.[0]}</Text>
            </View>
          )}
          <View style={{ flex: 1 }}>
            <Text style={{ color: c.textPrimary, fontWeight: "900", fontSize: 18 }} testID="profile-name">{user?.name}</Text>
            <Text style={{ color: c.textSecondary, fontSize: 13 }} testID="profile-email">{user?.email}</Text>
            <View style={[styles.role, { backgroundColor: c.primarySoft }]}>
              <Text style={{ color: c.primary, fontWeight: "800", fontSize: 12 }} testID="profile-role">{roleLabel}</Text>
            </View>
          </View>
        </Card>
        <Field testID="profile-name-input" label="Nama" value={f.name} onChangeText={set("name")} />
        {isBrand ? (
          <Field testID="profile-brand-name-input" label="Nama brand" value={f.brand_name} onChangeText={set("brand_name")} />
        ) : (
          <>
            <Field testID="profile-tiktok-input" label="Username TikTok" value={f.tiktok} onChangeText={set("tiktok")} autoCapitalize="none" placeholder="@kamu" />
            <Field testID="profile-instagram-input" label="Username Instagram" value={f.instagram} onChangeText={set("instagram")} autoCapitalize="none" placeholder="@kamu" />
            <Text style={{ color: c.textPrimary, fontWeight: "800", fontSize: 16, marginTop: 4 }}>Rekening penarikan</Text>
            <Field testID="profile-bank-method-input" label="Bank / e-wallet" value={f.bank_method} onChangeText={set("bank_method")} placeholder="BCA / DANA" />
            <Field testID="profile-bank-account-input" label="Nomor rekening" value={f.bank_account} onChangeText={set("bank_account")} keyboardType="number-pad" />
            <Field testID="profile-bank-holder-input" label="Nama pemilik" value={f.bank_holder} onChangeText={set("bank_holder")} />
          </>
        )}
        <Button testID="profile-save-button" title="Simpan profil" onPress={save} loading={loading} disabled={!f.name.trim()} />
        <Button testID="profile-logout-button" title="Keluar" icon="log-out-outline" variant="outline" onPress={logout} />
      </KeyboardAwareScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  user: { flexDirection: "row", alignItems: "center", gap: 14 },
  avatar: { width: 60, height: 60, borderRadius: 30 },
  role: { alignSelf: "flex-start", paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6, marginTop: 6 },
});
