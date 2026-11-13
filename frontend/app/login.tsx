import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeInDown } from "react-native-reanimated";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useAuth } from "@/src/context/AuthContext";
import { Button } from "@/src/components/ui";
import { useTheme } from "@/src/theme";

const HERO = "https://images.unsplash.com/photo-1758273239210-59fea02475eb?w=900&q=80";

export default function Login() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const { login, busy } = useAuth();
  return (
    <View style={styles.root} testID="login-screen">
      <Image source={{ uri: HERO }} style={StyleSheet.absoluteFill} contentFit="cover" />
      <LinearGradient colors={["rgba(15,23,42,0.2)", "rgba(15,23,42,0.85)", "#0F172A"]} style={StyleSheet.absoluteFill} />
      <View style={[styles.top, { paddingTop: insets.top + 16 }]}>
        <View style={[styles.logo, { backgroundColor: c.primary }]}><Text style={styles.logoB}>B</Text></View>
        <Text style={styles.brand}>TryBuzzer</Text>
      </View>
      <Animated.View entering={FadeInDown.duration(500)} style={[styles.bottom, { paddingBottom: insets.bottom + 24 }]}>
        <View style={[styles.pill, { backgroundColor: "rgba(255,85,0,0.18)" }]}>
          <Ionicons name="flash" size={14} color={c.primary} />
          <Text style={[styles.pillText, { color: "#FDBA74" }]}>Dibayar per views</Text>
        </View>
        <Text style={styles.h1}>Posting video,{"\n"}<Text style={{ color: c.primary }}>cairkan cuan.</Text></Text>
        <Text style={styles.p}>Cari campaign brand, submit link TikTok / Instagram / YouTube kamu, dan dapat bayaran dari setiap 1.000 views.</Text>
        <View style={styles.points}>
          {["Ratusan campaign aktif", "Tarik saldo mulai Rp 50.000", "Satu akun dengan versi web"].map((t) => (
            <View key={t} style={styles.point}>
              <Ionicons name="checkmark-circle" size={18} color={c.success} />
              <Text style={styles.pointText}>{t}</Text>
            </View>
          ))}
        </View>
        <Button testID="login-google-button" title="Masuk dengan Google" icon="logo-google" onPress={login} loading={busy} />
        <Text style={styles.terms}>Dengan masuk, kamu menyetujui Syarat & Ketentuan TryBuzzer.</Text>
      </Animated.View>
    </View>
  );
}

// Login hero is always dark over a photo, so text colors are fixed.
const styles = StyleSheet.create({
  root: { flex: 1, justifyContent: "space-between", backgroundColor: "#0F172A" },
  top: { flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: 24 },
  logo: { width: 36, height: 36, borderRadius: 10, alignItems: "center", justifyContent: "center" },
  logoB: { color: "#FFFFFF", fontWeight: "900", fontSize: 20 },
  brand: { color: "#FFFFFF", fontWeight: "900", fontSize: 20, letterSpacing: -0.5 },
  bottom: { paddingHorizontal: 24, gap: 16 },
  pill: { flexDirection: "row", alignItems: "center", gap: 6, alignSelf: "flex-start", paddingHorizontal: 10, paddingVertical: 6, borderRadius: 999 },
  pillText: { fontSize: 12, fontWeight: "800" },
  h1: { color: "#FFFFFF", fontSize: 38, fontWeight: "900", letterSpacing: -1.2, lineHeight: 42 },
  p: { color: "#CBD5E1", fontSize: 15, lineHeight: 22 },
  points: { gap: 8, marginBottom: 8 },
  point: { flexDirection: "row", alignItems: "center", gap: 8 },
  pointText: { color: "#F8FAFC", fontSize: 14, fontWeight: "600" },
  terms: { color: "#94A3B8", fontSize: 12, textAlign: "center" },
});
