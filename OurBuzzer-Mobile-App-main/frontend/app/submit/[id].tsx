import React, { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { campaignApi, creatorApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import type { Platform } from "@/src/api/types";
import { ScreenHeader } from "@/src/components/ScreenHeader";
import { PlatformIcon } from "@/src/components/PlatformIcon";
import { Button, Card, Field } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { PLATFORMS, num, rp } from "@/src/lib/format";
import { useTheme } from "@/src/theme";

const DOMAINS: Record<Platform, string[]> = {
  tiktok: ["tiktok.com"], instagram: ["instagram.com"], threads: ["threads.net", "threads.com"], youtube: ["youtube.com", "youtu.be"],
};

export const validateLink = (url: string, p: Platform) => {
  const m = url.trim().match(/^https?:\/\/([^/]+)\/\S+$/i);
  if (!m) return "Link harus diawali https:// dan lengkap";
  const host = m[1].toLowerCase().split(":")[0];
  return DOMAINS[p].some((d) => host === d || host.endsWith("." + d)) ? null : `Ini bukan link ${PLATFORMS[p]} yang valid`;
};

export default function SubmitVideo() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const qc = useQueryClient();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data: cp } = useQuery({ queryKey: ["campaign", id], queryFn: () => campaignApi.get(id) });
  const [platform, setPlatform] = useState<Platform | null>(null);
  const [url, setUrl] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => { if (cp && !platform) setPlatform(cp.platforms[0]); }, [cp, platform]);

  const submit = async () => {
    if (!cp || !platform) return;
    const v = validateLink(url, platform);
    if (v) return setErr(v);
    setErr(null);
    setLoading(true);
    try {
      await creatorApi.submit(cp.campaign_id, platform, url.trim());
      qc.invalidateQueries({ queryKey: ["creator-submissions"] });
      qc.invalidateQueries({ queryKey: ["creator-stats"] });
      toast("Video terkirim! Tunggu review dari brand.", "success");
      router.replace("/activity");
    } catch (e) {
      setErr(errMsg(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="submit-screen">
      <ScreenHeader title="Submit video" />
      {!cp ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={c.primary} />
      ) : (
        <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: 16, gap: 18, paddingBottom: insets.bottom + 24 }}>
          <Card>
            <Text style={{ color: c.textSecondary, fontSize: 12, fontWeight: "700" }}>CAMPAIGN</Text>
            <Text style={{ color: c.textPrimary, fontSize: 17, fontWeight: "800", marginTop: 4 }} testID="submit-campaign-title">{cp.title}</Text>
            <Text style={{ color: c.textSecondary, marginTop: 6, fontSize: 13 }}>
              {rp(cp.rate_per_1k)}/1K views · min. {num(cp.min_views)} views
            </Text>
          </Card>
          <View style={{ gap: 8 }}>
            <Text style={[styles.label, { color: c.textSecondary }]}>Platform</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {cp.platforms.map((p) => {
                const on = platform === p;
                return (
                  <Pressable key={p} testID={`submit-platform-${p}`} onPress={() => { setPlatform(p); setErr(null); }}
                    style={[styles.plat, { backgroundColor: on ? c.ink : c.surface, borderColor: on ? c.ink : c.border }]}>
                    <PlatformIcon p={p} color={on ? c.onInk : c.textPrimary} />
                    <Text style={{ fontWeight: "800", color: on ? c.onInk : c.textPrimary }}>{PLATFORMS[p]}</Text>
                  </Pressable>
                );
              })}
            </View>
          </View>
          <Field
            testID="submit-url-input"
            label="Link video"
            value={url}
            onChangeText={(t) => { setUrl(t); setErr(null); }}
            placeholder={platform === "youtube" ? "https://youtube.com/shorts/..." : `https://www.${platform}.com/...`}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            hint="Satu video hanya bisa didaftarkan sekali (anti-duplikat)."
          />
          {err ? (
            <View style={[styles.err, { backgroundColor: c.dangerSoft }]} testID="submit-error">
              <Ionicons name="alert-circle" size={18} color={c.dangerText} />
              <Text style={{ color: c.dangerText, fontWeight: "700", flex: 1 }}>{err}</Text>
            </View>
          ) : null}
          <Card style={{ backgroundColor: c.surfaceMuted, borderColor: c.surfaceMuted, gap: 6 }}>
            {["Brand review konten kamu (Direview)", "Setelah views cukup, klaim views", "Brand cek views → saldo masuk (Selesai)"].map((t, i) => (
              <Text key={t} style={{ color: c.textSecondary, fontSize: 13 }}>{i + 1}. {t}</Text>
            ))}
          </Card>
          <Button testID="submit-video-button" title="Kirim video" icon="paper-plane" onPress={submit} loading={loading} disabled={!url} />
        </KeyboardAwareScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  label: { fontSize: 12, fontWeight: "700", textTransform: "uppercase", letterSpacing: 0.6 },
  plat: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 14, height: 44, borderRadius: 12, borderWidth: 1 },
  err: { flexDirection: "row", gap: 8, alignItems: "center", padding: 12, borderRadius: 12 },
});
