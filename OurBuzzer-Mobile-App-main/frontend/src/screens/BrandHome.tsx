import React, { useState } from "react";
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { brandApi, campaignApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import type { Campaign } from "@/src/api/types";
import { useAuth } from "@/src/context/AuthContext";
import { Bell } from "@/src/components/Bell";
import { TabHeader } from "@/src/components/ScreenHeader";
import { Sheet } from "@/src/components/Sheet";
import { Button, Card, Empty, SectionTitle, StatusChip } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { num, rp } from "@/src/lib/format";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

export default function BrandHome() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const qc = useQueryClient();
  const { user } = useAuth();
  const stats = useQuery({ queryKey: ["brand-stats"], queryFn: brandApi.stats });
  const camps = useQuery({ queryKey: ["brand-campaigns"], queryFn: brandApi.campaigns });
  const [sel, setSel] = useState<Campaign | null>(null);
  const [confirmClose, setConfirmClose] = useState(false);
  const [loading, setLoading] = useState(false);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  const setStatus = async (status: "active" | "paused" | "closed") => {
    if (!sel) return;
    setLoading(true);
    try {
      await campaignApi.setStatus(sel.campaign_id, status);
      toast(status === "closed" ? "Campaign ditutup, sisa budget dikembalikan" : status === "paused" ? "Campaign dijeda" : "Campaign aktif lagi", "success");
      setSel(null);
      ["brand-campaigns", "brand-stats", "sections", "campaigns"].forEach((k) => qc.invalidateQueries({ queryKey: [k] }));
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  const S = ({ label, value, icon, testID }: { label: string; value: string; icon: string; testID: string }) => (
    <Card style={styles.stat}>
      <Ionicons name={icon as any} size={18} color={c.primary} />
      <Text style={{ color: c.textPrimary, fontSize: 18, fontWeight: "900", marginTop: 6 }} testID={testID}>{value}</Text>
      <Text style={{ color: c.textSecondary, fontSize: 12 }}>{label}</Text>
    </Card>
  );

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="brand-home-screen">
      <TabHeader title={user?.profile?.brand_name || user?.name || "Brand"} subtitle="Dashboard brand" right={<Bell />} />
      <ScrollView
        contentContainerStyle={{ padding: 16, paddingTop: 4, gap: 16, paddingBottom: bottomChrome + 24 }}
        refreshControl={<RefreshControl refreshing={stats.isRefetching || camps.isRefetching} onRefresh={() => { stats.refetch(); camps.refetch(); }} tintColor={c.primary} colors={[c.primary]} />}
      >
        <View style={[styles.balance, { backgroundColor: c.ink }]}>
          <Text style={{ color: c.textMuted, fontSize: 12, fontWeight: "600" }}>Saldo brand</Text>
          <Text style={[styles.balVal, { color: c.onInk }]} testID="brand-balance">{rp(stats.data?.brand_balance || 0)}</Text>
          <View style={{ flexDirection: "row", gap: 10 }}>
            <Button testID="brand-topup-button" title="Top up" icon="add-circle" onPress={() => router.push("/topup")} style={{ flex: 1 }} />
            <Button testID="brand-new-campaign-button" title="Campaign" icon="megaphone" variant="outline" onPress={() => router.push("/new-campaign")} style={{ flex: 1 }} />
          </View>
        </View>
        <View style={styles.grid}>
          <S label="Campaign aktif" value={String(stats.data?.active ?? 0)} icon="flash" testID="brand-stat-active" />
          <S label="Perlu review" value={String(stats.data?.pending_reviews ?? 0)} icon="time" testID="brand-stat-pending" />
          <S label="Budget terpakai" value={rp(stats.data?.spent || 0)} icon="cash" testID="brand-stat-spent" />
          <S label="Total views" value={num(stats.data?.views || 0)} icon="eye" testID="brand-stat-views" />
        </View>
        <SectionTitle title="Campaign kamu" desc="Ketuk campaign untuk jeda / tutup." />
        {!camps.data?.length ? (
          <Empty testID="brand-campaigns-empty" icon="megaphone-outline" title="Belum ada campaign" desc="Top up saldo lalu buat campaign pertamamu." />
        ) : (
          camps.data.map((cp) => (
            <Pressable key={cp.campaign_id} testID={`brand-campaign-${cp.campaign_id}`} onPress={() => { setSel(cp); setConfirmClose(false); }}>
              <Card style={styles.camp}>
                <View style={[styles.thumb, { backgroundColor: c.surfaceMuted }]}>
                  {cp.thumbnail ? <Image source={{ uri: cp.thumbnail }} style={StyleSheet.absoluteFill} contentFit="cover" /> : null}
                </View>
                <View style={{ flex: 1, gap: 6 }}>
                  <Text numberOfLines={1} style={{ color: c.textPrimary, fontWeight: "800", fontSize: 15 }}>{cp.title}</Text>
                  <View style={{ flexDirection: "row", gap: 8, alignItems: "center" }}>
                    <StatusChip status={cp.status} testID={`brand-campaign-status-${cp.campaign_id}`} />
                    <Text style={{ color: c.textSecondary, fontSize: 12 }}>{cp.submission_count} video</Text>
                  </View>
                  <View style={[styles.track, { backgroundColor: c.surfaceMuted }]}>
                    <View style={{ height: "100%", width: `${100 - cp.budget_left_pct}%`, backgroundColor: c.primary }} />
                  </View>
                  <Text style={{ color: c.textSecondary, fontSize: 12 }}>{rp(cp.spent)} / {rp(cp.budget)}</Text>
                </View>
                <Ionicons name="ellipsis-vertical" size={18} color={c.textMuted} />
              </Card>
            </Pressable>
          ))
        )}
      </ScrollView>
      <Sheet visible={!!sel} onClose={() => setSel(null)} title={sel?.title || ""} testID="campaign-action-sheet">
        {sel && (confirmClose ? (
          <>
            <Text style={{ color: c.textSecondary, fontSize: 14, lineHeight: 21 }}>
              Campaign akan ditutup permanen. Submission yang belum selesai dibatalkan, dan sisa budget{" "}
              <Text style={{ fontWeight: "900", color: c.textPrimary }}>{rp(Math.max(sel.budget - sel.spent, 0))}</Text> dikembalikan ke saldo brand.
            </Text>
            <Button testID="campaign-close-confirm-button" title="Ya, tutup campaign" variant="danger" onPress={() => setStatus("closed")} loading={loading} />
            <Button testID="campaign-close-cancel-button" title="Batal" variant="outline" onPress={() => setConfirmClose(false)} />
          </>
        ) : (
          <>
            <Button testID="campaign-view-button" title="Lihat detail" icon="eye" variant="outline" onPress={() => { const id = sel.campaign_id; setSel(null); router.push(`/campaign/${id}`); }} />
            {sel.status === "active" && <Button testID="campaign-pause-button" title="Jeda campaign" icon="pause" variant="dark" onPress={() => setStatus("paused")} loading={loading} />}
            {sel.status === "paused" && <Button testID="campaign-resume-button" title="Lanjutkan campaign" icon="play" onPress={() => setStatus("active")} loading={loading} />}
            {sel.status !== "closed" && <Button testID="campaign-close-button" title="Tutup & refund sisa budget" icon="close-circle" variant="danger" onPress={() => setConfirmClose(true)} />}
          </>
        ))}
      </Sheet>
    </View>
  );
}

const styles = StyleSheet.create({
  balance: { borderRadius: 24, padding: 20, gap: 12 },
  balVal: { fontSize: 32, fontWeight: "900", letterSpacing: -1 },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  stat: { width: "48%", flexGrow: 1, padding: 14 },
  camp: { flexDirection: "row", alignItems: "center", gap: 12, padding: 10 },
  thumb: { width: 64, height: 64, borderRadius: 12, overflow: "hidden" },
  track: { height: 5, borderRadius: 3, overflow: "hidden" },
});
