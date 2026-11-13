import React, { useState } from "react";
import { FlatList, Linking, Pressable, RefreshControl, StyleSheet, Text, View } from "react-native";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { brandApi } from "@/src/api/services";
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
  { key: "direview", label: "Review konten" },
  { key: "diproses", label: "Cek views" },
  { key: "menunggu_views", label: "Menunggu klaim" },
  { key: "disetujui", label: "Selesai" },
  { key: "ditolak", label: "Ditolak" },
  { key: "", label: "Semua" },
];

export default function BrandReview() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const qc = useQueryClient();
  const [filter, setFilter] = useState("direview");
  const [mode, setMode] = useState<"review" | "verify" | null>(null);
  const [sel, setSel] = useState<Submission | null>(null);
  const [note, setNote] = useState("");
  const [views, setViews] = useState("");
  const [loading, setLoading] = useState<string | null>(null);
  const { data, isLoading, refetch, isRefetching } = useQuery({ queryKey: ["brand-submissions", filter], queryFn: () => brandApi.submissions(filter) });
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  const v = parseInt(views.replace(/\D/g, ""), 10) || 0;

  const open = (s: Submission, m: "review" | "verify") => { setSel(s); setMode(m); setNote(""); setViews(String(s.claimed_views || "")); };
  const close = () => { setSel(null); setMode(null); };

  const act = async (action: "approve" | "reject") => {
    if (!sel) return;
    setLoading(action);
    try {
      if (mode === "review") {
        await brandApi.review(sel.submission_id, action, note);
        toast(action === "approve" ? "Konten disetujui" : "Konten ditolak", "success");
      } else {
        const r = await brandApi.verify(sel.submission_id, action, v, note);
        toast(action === "approve" && r.payout ? `Views terverifikasi, dibayar ${rp(r.payout)}` : "Klaim ditolak", "success");
      }
      close();
      ["brand-submissions", "brand-stats", "brand-campaigns"].forEach((k) => qc.invalidateQueries({ queryKey: [k] }));
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(null);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="brand-review-screen">
      <View style={{ backgroundColor: c.background }}>
        <TabHeader title="Review" subtitle="Cek konten & verifikasi views kreator" />
        <Chips items={FILTERS} value={filter} onChange={setFilter} testPrefix="review-filter" />
      </View>
      <FlatList
        data={data || []}
        keyExtractor={(s) => s.submission_id}
        contentContainerStyle={{ padding: 16, paddingTop: 8, gap: 12, paddingBottom: bottomChrome + 24 }}
        refreshControl={<RefreshControl refreshing={isRefetching} onRefresh={() => { refetch(); }} tintColor={c.primary} colors={[c.primary]} />}
        ListEmptyComponent={isLoading ? undefined : <Empty testID="review-empty" icon="checkmark-done-circle-outline" title="Tidak ada antrian" desc="Semua submission di status ini sudah beres." />}
        renderItem={({ item: s }) => (
          <Card testID={`review-card-${s.submission_id}`} style={{ gap: 10 }}>
            <View style={styles.rowBetween}>
              <StatusChip status={s.status} />
              <Text style={{ color: c.textMuted, fontSize: 12 }}>{fmtDate(s.created_at)}</Text>
            </View>
            <Text style={{ color: c.textPrimary, fontWeight: "800", fontSize: 16 }}>{s.creator_name}</Text>
            <Text style={{ color: c.textSecondary, fontSize: 13 }} numberOfLines={1}>{s.campaign_title}</Text>
            <Pressable testID={`review-link-${s.submission_id}`} onPress={() => Linking.openURL(s.video_url)} style={styles.link}>
              <PlatformIcon p={s.platform} color={c.textSecondary} />
              <Text style={{ color: c.info, fontSize: 13, flex: 1 }} numberOfLines={1}>{s.video_url}</Text>
            </Pressable>
            {s.claimed_views > 0 && (
              <Text style={{ color: c.textPrimary, fontSize: 13 }}>
                Klaim: <Text style={{ fontWeight: "900" }}>{num(s.claimed_views)}</Text> views · estimasi {rp(Math.floor((s.claimed_views / 1000) * s.rate_per_1k))}
              </Text>
            )}
            {s.status === "direview" && (
              <Button testID={`review-open-${s.submission_id}`} title="Review konten" icon="eye" small variant="dark" onPress={() => open(s, "review")} />
            )}
            {s.status === "diproses" && (
              <Button testID={`verify-open-${s.submission_id}`} title="Verifikasi views" icon="shield-checkmark" small onPress={() => open(s, "verify")} />
            )}
          </Card>
        )}
      />
      <Sheet visible={!!sel} onClose={close} title={mode === "review" ? "Review konten" : "Verifikasi views"} testID="review-sheet">
        {sel && (
          <>
            <Pressable onPress={() => Linking.openURL(sel.video_url)} testID="review-sheet-open-video">
              <Card style={{ flexDirection: "row", gap: 10, alignItems: "center" }}>
                <PlatformIcon p={sel.platform} size={22} color={c.textPrimary} />
                <Text style={{ color: c.info, flex: 1 }} numberOfLines={2}>{sel.video_url}</Text>
              </Card>
            </Pressable>
            {mode === "verify" && (
              <>
                <Field testID="verify-views-input" label="Views terverifikasi" value={views} onChangeText={setViews} keyboardType="number-pad"
                  hint={`Klaim kreator: ${num(sel.claimed_views)} · minimal ${num(sel.min_views)}`} />
                <Text style={{ color: c.success, fontWeight: "900" }} testID="verify-payout-estimate">Dibayar: {rp(Math.floor((v / 1000) * sel.rate_per_1k))}</Text>
              </>
            )}
            <Field testID="review-note-input" label="Catatan (opsional)" value={note} onChangeText={setNote} placeholder="Alasan / catatan untuk kreator" />
            <View style={{ flexDirection: "row", gap: 10 }}>
              <Button testID="review-reject-button" title="Tolak" variant="outline" onPress={() => act("reject")} loading={loading === "reject"} style={{ flex: 1 }} />
              <Button testID="review-approve-button" title={mode === "review" ? "Setujui" : "Bayar"} onPress={() => act("approve")} loading={loading === "approve"} style={{ flex: 1 }} disabled={mode === "verify" && !v} />
            </View>
          </>
        )}
      </Sheet>
    </View>
  );
}

const styles = StyleSheet.create({
  rowBetween: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  link: { flexDirection: "row", alignItems: "center", gap: 8 },
});
