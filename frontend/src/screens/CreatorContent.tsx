import React, { useState } from "react";
import { FlatList, Linking, Pressable, RefreshControl, StyleSheet, Text, View } from "react-native";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { creatorApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import type { Submission } from "@/src/api/types";
import { TabHeader } from "@/src/components/ScreenHeader";
import { Chips } from "@/src/components/Chips";
import { Sheet } from "@/src/components/Sheet";
import { PlatformIcon } from "@/src/components/PlatformIcon";
import { Button, Card, Empty, Field, StatusChip } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { fmtDate, num, rp } from "@/src/lib/format";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

const FILTERS = [
  { key: "all", label: "Semua" },
  { key: "direview", label: "Direview" },
  { key: "menunggu_views", label: "Disetujui" },
  { key: "diproses", label: "Dicek views" },
  { key: "disetujui", label: "Selesai" },
  { key: "ditolak", label: "Ditolak" },
];

export default function CreatorContent() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const qc = useQueryClient();
  const [filter, setFilter] = useState("all");
  const [claim, setClaim] = useState<Submission | null>(null);
  const [views, setViews] = useState("");
  const [loading, setLoading] = useState(false);
  const { data, isLoading, refetch, isRefetching } = useQuery({ queryKey: ["creator-submissions"], queryFn: creatorApi.submissions });
  const items = (data || []).filter((s) => filter === "all" || s.status === filter || (filter === "diproses" && s.status === "verifying"));
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  const v = parseInt(views.replace(/\D/g, ""), 10) || 0;

  const doClaim = async () => {
    if (!claim) return;
    setLoading(true);
    try {
      await creatorApi.claim(claim.submission_id, v);
      toast("Klaim terkirim, brand akan cek views kamu", "success");
      setClaim(null);
      qc.invalidateQueries({ queryKey: ["creator-submissions"] });
      qc.invalidateQueries({ queryKey: ["creator-stats"] });
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="creator-content-screen">
      <View style={{ backgroundColor: c.background }}>
        <TabHeader title="Konten saya" subtitle={`${data?.length ?? 0} video disubmit`} />
        <Chips items={FILTERS} value={filter} onChange={setFilter} testPrefix="submission-filter" />
      </View>
      <FlatList
        data={items}
        keyExtractor={(s) => s.submission_id}
        contentContainerStyle={{ padding: 16, paddingTop: 8, gap: 12, paddingBottom: bottomChrome + 24 }}
        refreshControl={<RefreshControl refreshing={isRefetching} onRefresh={() => { refetch(); }} tintColor={c.primary} colors={[c.primary]} />}
        ListEmptyComponent={isLoading ? undefined : <Empty testID="submissions-empty" icon="videocam-outline" title="Belum ada konten" desc="Cari campaign di tab Cuan lalu submit link videomu." />}
        renderItem={({ item: s }) => (
          <Card testID={`submission-card-${s.submission_id}`} style={{ gap: 10 }}>
            <View style={styles.rowBetween}>
              <StatusChip status={s.status} testID={`submission-status-${s.submission_id}`} />
              <Text style={{ color: c.textMuted, fontSize: 12 }}>{fmtDate(s.created_at)}</Text>
            </View>
            <Text style={[styles.title, { color: c.textPrimary }]} numberOfLines={2}>{s.campaign_title}</Text>
            <Pressable testID={`submission-link-${s.submission_id}`} onPress={() => Linking.openURL(s.video_url)} style={styles.link}>
              <PlatformIcon p={s.platform} color={c.textSecondary} />
              <Text style={{ color: c.info, fontSize: 13, flex: 1 }} numberOfLines={1}>{s.video_url}</Text>
            </Pressable>
            <View style={[styles.metrics, { backgroundColor: c.surfaceMuted }]}>
              <View style={{ flex: 1 }}>
                <Text style={[styles.mLbl, { color: c.textSecondary }]}>Views</Text>
                <Text style={[styles.mVal, { color: c.textPrimary }]}>{num(s.verified_views || s.claimed_views)}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={[styles.mLbl, { color: c.textSecondary }]}>Rate/1K</Text>
                <Text style={[styles.mVal, { color: c.textPrimary }]}>{rp(s.rate_per_1k)}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={[styles.mLbl, { color: c.textSecondary }]}>Cuan</Text>
                <Text style={[styles.mVal, { color: c.success }]} testID={`submission-payout-${s.submission_id}`}>{rp(s.payout)}</Text>
              </View>
            </View>
            {s.note ? <Text style={{ color: c.textSecondary, fontSize: 13 }}>Catatan: {s.note}</Text> : null}
            {s.status === "menunggu_views" && (
              <Button testID={`claim-views-button-${s.submission_id}`} title="Klaim views" icon="eye" small onPress={() => { setClaim(s); setViews(""); }} />
            )}
          </Card>
        )}
      />
      <Sheet visible={!!claim} onClose={() => setClaim(null)} title="Klaim views" testID="claim-sheet">
        {claim && (
          <>
            <Text style={{ color: c.textSecondary, fontSize: 14 }}>
              Masukkan jumlah views video kamu saat ini. Minimal {num(claim.min_views)} views. Brand akan mengecek manual.
            </Text>
            <Field testID="claim-views-input" label="Jumlah views" value={views} onChangeText={setViews} keyboardType="number-pad" placeholder="contoh: 25000" />
            <View style={[styles.estimate, { backgroundColor: c.successSoft }]}>
              <Ionicons name="cash" size={18} color={c.successText} />
              <Text style={{ color: c.successText, fontWeight: "800" }} testID="claim-estimate">
                Estimasi cuan: {rp(Math.floor((v / 1000) * claim.rate_per_1k))}
              </Text>
            </View>
            <Button testID="claim-submit-button" title="Kirim klaim" onPress={doClaim} loading={loading} disabled={v < claim.min_views} />
          </>
        )}
      </Sheet>
    </View>
  );
}

const styles = StyleSheet.create({
  rowBetween: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  title: { fontSize: 16, fontWeight: "800" },
  link: { flexDirection: "row", alignItems: "center", gap: 8 },
  metrics: { flexDirection: "row", padding: 12, borderRadius: 12 },
  mLbl: { fontSize: 11, fontWeight: "600" },
  mVal: { fontSize: 14, fontWeight: "900", marginTop: 2 },
  estimate: { flexDirection: "row", gap: 8, alignItems: "center", padding: 12, borderRadius: 12 },
});
