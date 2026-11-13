import React from "react";
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { campaignApi } from "@/src/api/services";
import { useAuth } from "@/src/context/AuthContext";
import { ScreenHeader } from "@/src/components/ScreenHeader";
import { PlatformIcon } from "@/src/components/PlatformIcon";
import { Button, Card, StatusChip } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { PLATFORMS, daysLeft, num, rp } from "@/src/lib/format";
import { useTheme } from "@/src/theme";

export default function CampaignDetail() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const { user } = useAuth();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data: cp, isLoading } = useQuery({ queryKey: ["campaign", id], queryFn: () => campaignApi.get(id) });

  const Stat = ({ label, value, testID }: { label: string; value: string; testID: string }) => (
    <View style={[styles.stat, { backgroundColor: c.surfaceMuted }]}>
      <Text style={[styles.statLbl, { color: c.textSecondary }]}>{label}</Text>
      <Text style={[styles.statVal, { color: c.textPrimary }]} testID={testID}>{value}</Text>
    </View>
  );

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="campaign-detail-screen">
      <ScreenHeader title="Detail campaign" />
      {isLoading || !cp ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={c.primary} />
      ) : (
        <>
          <ScrollView contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: 120 }}>
            <View style={[styles.hero, { backgroundColor: c.surfaceMuted }]}>
              {cp.thumbnail ? <Image source={{ uri: cp.thumbnail }} style={StyleSheet.absoluteFill} contentFit="cover" /> : null}
            </View>
            <View style={{ gap: 6 }}>
              <View style={{ flexDirection: "row", gap: 8, alignItems: "center" }}>
                <StatusChip status={cp.status} testID="campaign-detail-status" />
                <Text style={{ color: c.textSecondary, fontSize: 13 }}>{cp.category} · {cp.brand_name}</Text>
              </View>
              <Text style={[styles.title, { color: c.textPrimary }]} testID="campaign-detail-title">{cp.title}</Text>
            </View>
            <View style={styles.grid}>
              <Stat label="Rate / 1K views" value={rp(cp.rate_per_1k)} testID="campaign-detail-rate" />
              <Stat label="Min. views" value={num(cp.min_views)} testID="campaign-detail-min-views" />
              <Stat label="Sisa budget" value={`${cp.budget_left_pct}%`} testID="campaign-detail-budget" />
              <Stat label="Sisa waktu" value={`${daysLeft(cp.deadline)} hari`} testID="campaign-detail-deadline" />
            </View>
            <Card>
              <Text style={[styles.h2, { color: c.textPrimary }]}>Platform diterima</Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 10 }}>
                {cp.platforms.map((p) => (
                  <View key={p} style={[styles.plat, { backgroundColor: c.surfaceMuted }]}>
                    <PlatformIcon p={p} color={c.textPrimary} />
                    <Text style={{ fontWeight: "700", color: c.textPrimary }}>{PLATFORMS[p]}</Text>
                  </View>
                ))}
              </View>
            </Card>
            <Card>
              <Text style={[styles.h2, { color: c.textPrimary }]}>Instruksi konten</Text>
              <Text style={{ color: c.textSecondary, marginTop: 8, lineHeight: 22, fontSize: 14 }} testID="campaign-detail-instructions">{cp.instructions}</Text>
            </Card>
            <Card style={{ backgroundColor: c.primarySoft, borderColor: c.primarySoft }}>
              <Text style={{ color: c.primaryText, fontWeight: "700", fontSize: 13, lineHeight: 20 }}>
                Contoh: video kamu dapat 50.000 views → kamu dapat {rp(Math.floor((50000 / 1000) * cp.rate_per_1k))}
              </Text>
            </Card>
          </ScrollView>
          <View style={[styles.bar, { paddingBottom: insets.bottom + 12, backgroundColor: c.surface, borderTopColor: c.border }]}>
            <Button
              testID="campaign-detail-submit-button"
              title={cp.status === "active" ? "Submit video" : "Campaign tidak aktif"}
              icon="paper-plane"
              disabled={cp.status !== "active"}
              onPress={() => {
                if (user?.role !== "creator") return toast("Hanya akun kreator yang bisa submit video", "error");
                router.push(`/submit/${cp.campaign_id}`);
              }}
            />
          </View>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { height: 200, borderRadius: 20, overflow: "hidden" },
  title: { fontSize: 24, fontWeight: "900", letterSpacing: -0.6, lineHeight: 30 },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  stat: { width: "48%", flexGrow: 1, padding: 14, borderRadius: 14, gap: 4 },
  statLbl: { fontSize: 12, fontWeight: "600" },
  statVal: { fontSize: 18, fontWeight: "900" },
  h2: { fontSize: 16, fontWeight: "800" },
  plat: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 12, height: 36, borderRadius: 10 },
  bar: { position: "absolute", left: 0, right: 0, bottom: 0, paddingHorizontal: 16, paddingTop: 12, borderTopWidth: StyleSheet.hairlineWidth },
});
