import React from "react";
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { brandApi } from "@/src/api/services";
import { TabHeader } from "@/src/components/ScreenHeader";
import { Button, Card, Empty, SectionTitle, StatusChip } from "@/src/components/ui";
import { fmtDate, rp } from "@/src/lib/format";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

export default function BrandWallet() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const stats = useQuery({ queryKey: ["brand-stats"], queryFn: brandApi.stats });
  const topups = useQuery({ queryKey: ["topups"], queryFn: brandApi.topups });
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="brand-wallet-screen">
      <TabHeader title="Saldo" subtitle="Top up via QRIS / Virtual Account" />
      <ScrollView
        contentContainerStyle={{ padding: 16, paddingTop: 4, gap: 16, paddingBottom: bottomChrome + 24 }}
        refreshControl={<RefreshControl refreshing={topups.isRefetching} onRefresh={() => { stats.refetch(); topups.refetch(); }} tintColor={c.primary} colors={[c.primary]} />}
      >
        <View style={[styles.balance, { backgroundColor: c.ink }]}>
          <Text style={{ color: c.textMuted, fontSize: 12, fontWeight: "600" }}>Saldo brand</Text>
          <Text style={[styles.balVal, { color: c.onInk }]} testID="brand-wallet-balance">{rp(stats.data?.brand_balance || 0)}</Text>
          <Button testID="brand-wallet-topup-button" title="Top up saldo" icon="add-circle" onPress={() => router.push("/topup")} />
        </View>
        <SectionTitle title="Riwayat top up" />
        {!topups.data?.length ? (
          <Empty testID="topups-empty" icon="card-outline" title="Belum ada top up" />
        ) : (
          topups.data.map((t) => (
            <Pressable key={t.topup_id} testID={`topup-item-${t.topup_id}`} disabled={t.status !== "pending"} onPress={() => router.push(`/topup?tid=${t.topup_id}`)}>
              <Card style={styles.row}>
                <View style={[styles.icon, { backgroundColor: c.primarySoft }]}>
                  <Ionicons name={t.payment_type === "qris" ? "qr-code" : "business"} size={20} color={c.primary} />
                </View>
                <View style={{ flex: 1, gap: 2 }}>
                  <Text style={{ color: c.textPrimary, fontWeight: "900", fontSize: 16 }}>{rp(t.amount)}</Text>
                  <Text style={{ color: c.textSecondary, fontSize: 12 }}>
                    {t.payment_type === "qris" ? "QRIS" : `VA ${t.channel_code}`} · {fmtDate(t.created_at)}
                  </Text>
                </View>
                <StatusChip status={t.status} testID={`topup-status-${t.topup_id}`} />
              </Card>
            </Pressable>
          ))
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  balance: { borderRadius: 24, padding: 20, gap: 12 },
  balVal: { fontSize: 32, fontWeight: "900", letterSpacing: -1 },
  row: { flexDirection: "row", alignItems: "center", gap: 12 },
  icon: { width: 44, height: 44, borderRadius: 12, alignItems: "center", justifyContent: "center" },
});
