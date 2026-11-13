import React, { useEffect, useState } from "react";
import { FlatList, Pressable, RefreshControl, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeInDown } from "react-native-reanimated";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { campaignApi, creatorApi } from "@/src/api/services";
import type { Campaign } from "@/src/api/types";
import { useAuth } from "@/src/context/AuthContext";
import { CampaignCard } from "@/src/components/CampaignCard";
import { StreakBanner } from "@/src/components/StreakBanner";
import { Chips } from "@/src/components/Chips";
import { Bell } from "@/src/components/Bell";
import { Empty, SectionTitle } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { CATEGORIES, rp } from "@/src/lib/format";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

const CAT_ITEMS = ["Semua", ...CATEGORIES].map((k) => ({ key: k, label: k }));

function Row({ id, title, desc, items, ranked, onInfo, onSubmit }: {
  id: string; title: string; desc: string; items?: Campaign[]; ranked?: boolean;
  onInfo: (c: Campaign) => void; onSubmit: (c: Campaign) => void;
}) {
  if (!items?.length) return null;
  return (
    <View style={{ gap: 12 }} testID={`row-${id}`}>
      <View style={{ paddingHorizontal: 16 }}><SectionTitle title={title} desc={desc} /></View>
      <FlatList
        horizontal
        data={items}
        keyExtractor={(c) => c.campaign_id}
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={{ paddingHorizontal: 16, gap: 12 }}
        snapToInterval={276}
        decelerationRate="fast"
        renderItem={({ item, index }) => (
          <CampaignCard c={item} width={264} rank={ranked ? index + 1 : undefined} onInfo={onInfo} onSubmit={onSubmit} />
        )}
      />
    </View>
  );
}

export default function CariCuan() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const { user } = useAuth();
  const isCreator = user?.role === "creator";
  const [tab, setTab] = useState<"public" | "exclusive">("public");
  const [q, setQ] = useState("");
  const [dq, setDq] = useState("");
  const [cat, setCat] = useState("Semua");

  useEffect(() => { const t = setTimeout(() => setDq(q.trim()), 300); return () => clearTimeout(t); }, [q]);

  const sections = useQuery({ queryKey: ["sections"], queryFn: campaignApi.sections });
  const list = useQuery({
    queryKey: ["campaigns", dq, cat, tab],
    queryFn: () => campaignApi.list({ q: dq, category: cat, exclusive: tab === "exclusive" }),
  });
  const stats = useQuery({ queryKey: ["creator-stats"], queryFn: creatorApi.stats, enabled: isCreator });

  const browsing = !!dq || tab === "exclusive" || cat !== "Semua";
  const refreshing = sections.isRefetching || list.isRefetching;
  const onRefresh = () => { sections.refetch(); list.refetch(); if (isCreator) stats.refetch(); };
  const onInfo = (cp: Campaign) => router.push(`/campaign/${cp.campaign_id}`);
  const onSubmit = (cp: Campaign) => {
    if (!isCreator) return toast("Hanya akun kreator yang bisa submit video", "error");
    router.push(`/submit/${cp.campaign_id}`);
  };
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="cari-cuan-screen">
      {/* Sticky header */}
      <View style={[styles.header, { paddingTop: insets.top + 8, backgroundColor: c.background, borderBottomColor: c.border }]}>
        <View style={styles.topRow}>
          <View style={[styles.logo, { backgroundColor: c.primary }]}><Text style={styles.logoB}>B</Text></View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.hello, { color: c.textSecondary }]}>Halo, {user?.name?.split(" ")[0]}</Text>
            <Text style={[styles.h1, { color: c.textPrimary }]}>Cari Cuan</Text>
          </View>
          {isCreator && stats.data && (
            <Pressable testID="header-balance-pill" onPress={() => router.push("/wallet")} style={[styles.balance, { backgroundColor: c.successSoft }]}>
              <Ionicons name="wallet" size={14} color={c.successText} />
              <Text style={[styles.balanceText, { color: c.successText }]}>{rp(stats.data.balance)}</Text>
            </Pressable>
          )}
          <Bell />
        </View>
        <View style={styles.searchRow}>
          <View style={[styles.segment, { backgroundColor: c.surfaceMuted }]}>
            {(["public", "exclusive"] as const).map((k) => {
              const on = tab === k;
              return (
                <Pressable key={k} testID={`bounty-tab-${k}`} onPress={() => setTab(k)} style={[styles.segBtn, on && { backgroundColor: c.surface }]}>
                  <Ionicons name={k === "public" ? "sparkles" : "lock-closed"} size={14} color={on ? c.primary : c.textSecondary} />
                  <Text style={[styles.segText, { color: on ? c.textPrimary : c.textSecondary }]}>{k === "public" ? "Public" : "Exclusive"}</Text>
                  {sections.data ? <Text style={[styles.segCount, { color: c.primary }]}>{k === "public" ? sections.data.total : sections.data.total_exclusive}</Text> : null}
                </Pressable>
              );
            })}
          </View>
          <View style={[styles.search, { backgroundColor: c.surfaceMuted }]}>
            <Ionicons name="search" size={16} color={c.textMuted} />
            <TextInput
              testID="bounty-search-input"
              value={q}
              onChangeText={setQ}
              placeholder="Cari campaign..."
              placeholderTextColor={c.textMuted}
              style={[styles.searchInput, { color: c.textPrimary }]}
              returnKeyType="search"
            />
            {q ? (
              <Pressable testID="bounty-search-clear" onPress={() => setQ("")} hitSlop={10}>
                <Ionicons name="close-circle" size={18} color={c.textMuted} />
              </Pressable>
            ) : null}
          </View>
        </View>
        <Chips items={CAT_ITEMS} value={cat} onChange={setCat} testPrefix="category" />
      </View>

      <ScrollView
        contentContainerStyle={{ paddingTop: 16, paddingBottom: bottomChrome + 24, gap: 28 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.primary} colors={[c.primary]} />}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="on-drag"
      >
        {isCreator && stats.data && !browsing && (
          <Animated.View entering={FadeInDown.duration(400)} style={{ paddingHorizontal: 16 }}>
            <StreakBanner s={stats.data.streak} />
          </Animated.View>
        )}

        {!browsing && sections.data && (
          <>
            <Row id="trending" title="Lagi rame minggu ini" desc="Paling banyak disubmit kreator 7 hari terakhir." items={sections.data.trending} ranked onInfo={onInfo} onSubmit={onSubmit} />
            <Row id="closing" title="Segera ditutup" desc="Daftarkan videomu sebelum campaign tutup." items={sections.data.closing} onInfo={onInfo} onSubmit={onSubmit} />
            <Row id="toprate" title="Rate tertinggi" desc="Bayaran per 1.000 views paling tinggi." items={sections.data.top_rate} onInfo={onInfo} onSubmit={onSubmit} />
            <Row id="newest" title="Campaign baru" desc="Baru dibuka, belum banyak saingan." items={sections.data.newest} onInfo={onInfo} onSubmit={onSubmit} />
          </>
        )}

        <View style={{ paddingHorizontal: 16, gap: 12 }}>
          <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
            <SectionTitle title={tab === "exclusive" ? "Campaign exclusive" : cat !== "Semua" ? `Kategori ${cat}` : "Semua campaign"} />
            <View style={[styles.count, { backgroundColor: c.surfaceMuted }]}>
              <Text style={{ fontWeight: "800", fontSize: 12, color: c.textPrimary }} testID="all-count">{list.data?.length ?? 0}</Text>
            </View>
          </View>
          {list.isLoading ? (
            <Text style={{ color: c.textSecondary }} testID="campaigns-loading">Memuat campaign...</Text>
          ) : list.isError ? (
            <Empty testID="campaigns-error" icon="cloud-offline" title="Gagal memuat" desc="Tarik ke bawah untuk coba lagi." />
          ) : !list.data?.length ? (
            <Empty testID="no-campaigns" icon="search" title="Belum ada campaign di sini" desc="Coba kategori lain atau ubah kata kunci." />
          ) : (
            list.data.map((cp) => <CampaignCard key={cp.campaign_id} c={cp} onInfo={onInfo} onSubmit={onSubmit} />)
          )}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  header: { borderBottomWidth: StyleSheet.hairlineWidth },
  topRow: { flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: 16 },
  logo: { width: 40, height: 40, borderRadius: 12, alignItems: "center", justifyContent: "center" },
  logoB: { color: "#FFFFFF", fontWeight: "900", fontSize: 20 },
  hello: { fontSize: 12, fontWeight: "600" },
  h1: { fontSize: 22, fontWeight: "900", letterSpacing: -0.6 },
  balance: { flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 10, height: 32, borderRadius: 10 },
  balanceText: { fontSize: 12, fontWeight: "800" },
  searchRow: { paddingHorizontal: 16, paddingTop: 12, gap: 8 },
  segment: { flexDirection: "row", padding: 4, borderRadius: 12, gap: 4 },
  segBtn: { flex: 1, height: 38, borderRadius: 9, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6 },
  segText: { fontSize: 14, fontWeight: "800" },
  segCount: { fontSize: 12, fontWeight: "900" },
  search: { flexDirection: "row", alignItems: "center", gap: 8, height: 46, borderRadius: 12, paddingHorizontal: 14 },
  searchInput: { flex: 1, fontSize: 15, height: "100%" },
  count: { paddingHorizontal: 8, paddingVertical: 2, borderRadius: 6 },
});
