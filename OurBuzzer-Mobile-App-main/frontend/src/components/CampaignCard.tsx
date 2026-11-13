import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Image } from "expo-image";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme } from "@/src/theme";
import { num, rp } from "@/src/lib/format";
import { PlatformIcon } from "./PlatformIcon";
import type { Campaign } from "@/src/api/types";

type Props = { c: Campaign; onInfo: (c: Campaign) => void; onSubmit: (c: Campaign) => void; width?: number; rank?: number };

export function CampaignCard({ c, onInfo, onSubmit, width, rank }: Props) {
  const t = useTheme();
  const pct = c.budget_left_pct;
  const bar = pct > 50 ? t.success : pct > 20 ? t.warning : t.danger;
  return (
    <Pressable
      testID={`campaign-card-${c.campaign_id}`}
      onPress={() => onInfo(c)}
      style={({ pressed }) => [styles.card, { width, backgroundColor: t.surface, borderColor: t.border, transform: [{ scale: pressed ? 0.98 : 1 }] }]}
    >
      <View style={[styles.thumb, { backgroundColor: t.surfaceMuted }]}>
        {c.thumbnail ? <Image source={{ uri: c.thumbnail }} style={StyleSheet.absoluteFill} contentFit="cover" transition={200} /> : null}
        <View style={[styles.cat, { backgroundColor: t.surface }]}>
          <Text style={[styles.catText, { color: t.textPrimary }]}>{c.category}</Text>
        </View>
        {rank ? (
          <View style={[styles.rank, { backgroundColor: t.primary }]}>
            <Text style={styles.rankText}>#{rank}</Text>
          </View>
        ) : null}
      </View>
      <View style={styles.body}>
        <View style={styles.rowBetween}>
          <View style={styles.platforms}>
            {c.platforms.map((p) => <PlatformIcon key={p} p={p} color={t.textSecondary} />)}
          </View>
          <View style={[styles.rate, { backgroundColor: t.primarySoft }]} testID="campaign-rate">
            <Text style={[styles.rateText, { color: t.primary }]}>{rp(c.rate_per_1k)}</Text>
            <Text style={[styles.rateUnit, { color: t.primary }]}>/1K</Text>
          </View>
        </View>
        <Text numberOfLines={2} style={[styles.title, { color: t.textPrimary }]}>{c.title}</Text>
        <View style={styles.rowBetween}>
          <Text style={[styles.meta, { color: t.textSecondary }]}>
            Min. <Text style={{ fontWeight: "800", color: t.textPrimary }}>{num(c.min_views)}</Text> views
          </Text>
          <Text style={[styles.meta, { color: t.textSecondary }]}>
            Budget <Text style={{ fontWeight: "800", color: t.textPrimary }}>{pct}%</Text>
          </Text>
        </View>
        <View style={[styles.track, { backgroundColor: t.surfaceMuted }]}>
          <View style={[styles.fill, { width: `${pct}%`, backgroundColor: bar }]} />
        </View>
        <View style={styles.actions}>
          <Pressable testID={`campaign-info-${c.campaign_id}`} onPress={() => onInfo(c)} style={[styles.infoBtn, { borderColor: t.border }]}>
            <Ionicons name="information-circle-outline" size={16} color={t.textPrimary} />
            <Text style={[styles.btnText, { color: t.textPrimary }]}>Instruksi</Text>
          </Pressable>
          <Pressable
            testID={`campaign-submit-${c.campaign_id}`}
            onPress={() => onSubmit(c)}
            style={({ pressed }) => [styles.submitBtn, { backgroundColor: t.ink, opacity: pressed ? 0.85 : 1 }]}
          >
            <Text style={[styles.btnText, { color: t.onInk }]}>Submit</Text>
            <Ionicons name="chevron-forward" size={16} color={t.onInk} />
          </Pressable>
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderRadius: 18, borderWidth: 1, padding: 8 },
  thumb: { height: 136, borderRadius: 12, overflow: "hidden" },
  cat: { position: "absolute", top: 8, left: 8, paddingHorizontal: 10, paddingVertical: 4, borderRadius: 8 },
  catText: { fontSize: 12, fontWeight: "700" },
  rank: { position: "absolute", top: 8, right: 8, paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 },
  rankText: { color: "#FFFFFF", fontWeight: "900", fontSize: 13 },
  body: { paddingHorizontal: 6, paddingTop: 10, paddingBottom: 4, gap: 8 },
  rowBetween: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  platforms: { flexDirection: "row", gap: 6 },
  rate: { flexDirection: "row", alignItems: "baseline", paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6 },
  rateText: { fontWeight: "900", fontSize: 14 },
  rateUnit: { fontSize: 10, fontWeight: "700", marginLeft: 2 },
  title: { fontSize: 15, fontWeight: "800", lineHeight: 20, minHeight: 40 },
  meta: { fontSize: 12 },
  track: { height: 6, borderRadius: 3, overflow: "hidden" },
  fill: { height: "100%" },
  actions: { flexDirection: "row", gap: 8, marginTop: 2 },
  infoBtn: { height: 42, paddingHorizontal: 12, borderRadius: 12, borderWidth: 1, flexDirection: "row", alignItems: "center", gap: 6 },
  submitBtn: { flex: 1, height: 42, borderRadius: 12, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 4 },
  btnText: { fontSize: 14, fontWeight: "800" },
});
