import React, { useState } from "react";
import { Pressable, StyleSheet, Switch, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { brandApi, campaignApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import type { Platform } from "@/src/api/types";
import { ScreenHeader } from "@/src/components/ScreenHeader";
import { Chips } from "@/src/components/Chips";
import { PlatformIcon } from "@/src/components/PlatformIcon";
import { Button, Card, Field } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { CATEGORIES, PLATFORMS, rp } from "@/src/lib/format";
import { useTheme } from "@/src/theme";

const CATS = CATEGORIES.map((k) => ({ key: k, label: k }));
const toInt = (s: string) => parseInt(s.replace(/\D/g, ""), 10) || 0;

export default function NewCampaign() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const qc = useQueryClient();
  const stats = useQuery({ queryKey: ["brand-stats"], queryFn: brandApi.stats });
  const [f, setF] = useState({ title: "", rate: "5000", minViews: "5000", budget: "1000000", days: "30", thumbnail: "", instructions: "" });
  const [category, setCategory] = useState("Produk");
  const [platforms, setPlatforms] = useState<Platform[]>(["tiktok"]);
  const [exclusive, setExclusive] = useState(false);
  const [loading, setLoading] = useState(false);
  const set = (k: keyof typeof f) => (v: string) => setF((p) => ({ ...p, [k]: v }));
  const budget = toInt(f.budget);
  const bal = stats.data?.brand_balance || 0;

  const toggle = (p: Platform) => setPlatforms((cur) => (cur.includes(p) ? cur.filter((x) => x !== p) : [...cur, p]));

  const submit = async () => {
    setLoading(true);
    try {
      await campaignApi.create({
        title: f.title.trim(), category, platforms, rate_per_1k: toInt(f.rate), min_views: toInt(f.minViews), budget,
        thumbnail: f.thumbnail.trim(), instructions: f.instructions.trim(), exclusive, deadline_days: toInt(f.days) || 30,
      });
      ["brand-campaigns", "brand-stats", "sections", "campaigns"].forEach((k) => qc.invalidateQueries({ queryKey: [k] }));
      toast("Campaign aktif! Budget dipotong dari saldo.", "success");
      router.back();
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  const valid = f.title.trim().length >= 3 && f.instructions.trim().length >= 10 && platforms.length > 0 && budget >= 100000 && toInt(f.rate) >= 500 && toInt(f.minViews) >= 100;

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="new-campaign-screen">
      <ScreenHeader title="Buat campaign" />
      <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: insets.bottom + 24 }}>
        <Card style={{ backgroundColor: budget > bal ? c.dangerSoft : c.successSoft, borderColor: "transparent" }}>
          <Text style={{ color: budget > bal ? c.dangerText : c.successText, fontWeight: "700" }} testID="new-campaign-balance">
            Saldo brand: {rp(bal)}{budget > bal ? " · saldo kurang, top up dulu" : ""}
          </Text>
        </Card>
        <Field testID="campaign-title-input" label="Judul campaign" value={f.title} onChangeText={set("title")} placeholder="Review jujur serum baru kami" />
        <View style={{ gap: 6 }}>
          <Text style={[styles.label, { color: c.textSecondary }]}>Kategori</Text>
          <Chips items={CATS} value={category} onChange={setCategory} testPrefix="campaign-category" padded={false} />
        </View>
        <View style={{ gap: 8 }}>
          <Text style={[styles.label, { color: c.textSecondary }]}>Platform</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
            {(Object.keys(PLATFORMS) as Platform[]).map((p) => {
              const on = platforms.includes(p);
              return (
                <Pressable key={p} testID={`campaign-platform-${p}`} onPress={() => toggle(p)}
                  style={[styles.plat, { backgroundColor: on ? c.ink : c.surface, borderColor: on ? c.ink : c.border }]}>
                  <PlatformIcon p={p} color={on ? c.onInk : c.textPrimary} />
                  <Text style={{ fontWeight: "700", color: on ? c.onInk : c.textPrimary }}>{PLATFORMS[p]}</Text>
                </Pressable>
              );
            })}
          </View>
        </View>
        <View style={styles.two}>
          <View style={{ flex: 1 }}><Field testID="campaign-rate-input" label="Rate / 1K (Rp)" value={f.rate} onChangeText={set("rate")} keyboardType="number-pad" /></View>
          <View style={{ flex: 1 }}><Field testID="campaign-min-views-input" label="Min. views" value={f.minViews} onChangeText={set("minViews")} keyboardType="number-pad" /></View>
        </View>
        <View style={styles.two}>
          <View style={{ flex: 1 }}><Field testID="campaign-budget-input" label="Budget (Rp)" value={f.budget} onChangeText={set("budget")} keyboardType="number-pad" hint="Min. Rp 100.000" /></View>
          <View style={{ flex: 1 }}><Field testID="campaign-days-input" label="Durasi (hari)" value={f.days} onChangeText={set("days")} keyboardType="number-pad" /></View>
        </View>
        <Field testID="campaign-thumbnail-input" label="URL gambar (opsional)" value={f.thumbnail} onChangeText={set("thumbnail")} autoCapitalize="none" placeholder="https://..." />
        <Field testID="campaign-instructions-input" label="Instruksi konten" value={f.instructions} onChangeText={set("instructions")} multiline placeholder="1. Sebutkan nama brand di 3 detik pertama..." />
        <View style={[styles.switchRow, { borderColor: c.border, backgroundColor: c.surface }]}>
          <View style={{ flex: 1 }}>
            <Text style={{ color: c.textPrimary, fontWeight: "800" }}>Campaign exclusive</Text>
            <Text style={{ color: c.textSecondary, fontSize: 12 }}>Tampil di tab Exclusive</Text>
          </View>
          <Switch testID="campaign-exclusive-switch" value={exclusive} onValueChange={setExclusive} trackColor={{ true: c.primary, false: c.border }} />
        </View>
        <Button testID="campaign-create-button" title={`Buat campaign · ${rp(budget)}`} onPress={submit} loading={loading} disabled={!valid || budget > bal} />
      </KeyboardAwareScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  label: { fontSize: 12, fontWeight: "700", textTransform: "uppercase", letterSpacing: 0.6 },
  plat: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 12, height: 40, borderRadius: 10, borderWidth: 1 },
  two: { flexDirection: "row", gap: 10 },
  switchRow: { flexDirection: "row", alignItems: "center", padding: 14, borderRadius: 14, borderWidth: 1 },
});
