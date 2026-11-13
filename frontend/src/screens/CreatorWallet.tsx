import React from "react";
import { RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { creatorApi } from "@/src/api/services";
import { TabHeader } from "@/src/components/ScreenHeader";
import { Button, Card, Empty, SectionTitle, StatusChip } from "@/src/components/ui";
import { MIN_WITHDRAW, fmtDate, rp } from "@/src/lib/format";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

export default function CreatorWallet() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const stats = useQuery({ queryKey: ["creator-stats"], queryFn: creatorApi.stats });
  const wds = useQuery({ queryKey: ["withdrawals"], queryFn: creatorApi.withdrawals });
  const bal = stats.data?.balance || 0;
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="creator-wallet-screen">
      <TabHeader title="Dompet" subtitle="Saldo cuan dari views kamu" />
      <ScrollView
        contentContainerStyle={{ padding: 16, paddingTop: 4, gap: 16, paddingBottom: bottomChrome + 24 }}
        refreshControl={<RefreshControl refreshing={stats.isRefetching} onRefresh={() => { stats.refetch(); wds.refetch(); }} tintColor={c.primary} colors={[c.primary]} />}
      >
        <View style={[styles.balance, { backgroundColor: c.ink }]}>
          <Text style={[styles.balLbl, { color: c.textMuted }]}>Saldo bisa ditarik</Text>
          <Text style={[styles.balVal, { color: c.onInk }]} testID="wallet-balance">{rp(bal)}</Text>
          <View style={styles.balRow}>
            <View>
              <Text style={[styles.balLbl, { color: c.textMuted }]}>Total cuan</Text>
              <Text style={[styles.balSmall, { color: c.onInk }]} testID="wallet-total-earned">{rp(stats.data?.total_earned || 0)}</Text>
            </View>
            <View>
              <Text style={[styles.balLbl, { color: c.textMuted }]}>Sedang dicek</Text>
              <Text style={[styles.balSmall, { color: c.primary }]} testID="wallet-pending">{rp(stats.data?.pending || 0)}</Text>
            </View>
          </View>
          <Button testID="wallet-withdraw-button" title="Tarik saldo" icon="arrow-up-circle" onPress={() => router.push("/withdraw")} disabled={bal < MIN_WITHDRAW} />
          {bal < MIN_WITHDRAW && (
            <Text style={{ color: c.textMuted, fontSize: 12, textAlign: "center" }} testID="wallet-min-hint">Minimal penarikan {rp(MIN_WITHDRAW)}</Text>
          )}
        </View>
        <View style={styles.stats}>
          <Card style={{ flex: 1 }}>
            <Text style={{ color: c.textSecondary, fontSize: 12 }}>Video</Text>
            <Text style={{ color: c.textPrimary, fontSize: 22, fontWeight: "900" }}>{stats.data?.videos ?? 0}</Text>
          </Card>
          <Card style={{ flex: 1 }}>
            <Text style={{ color: c.textSecondary, fontSize: 12 }}>Campaign</Text>
            <Text style={{ color: c.textPrimary, fontSize: 22, fontWeight: "900" }}>{stats.data?.campaigns ?? 0}</Text>
          </Card>
          <Card style={{ flex: 1 }}>
            <Text style={{ color: c.textSecondary, fontSize: 12 }}>Streak</Text>
            <Text style={{ color: c.primary, fontSize: 22, fontWeight: "900" }}>{stats.data?.streak.streak ?? 0} hari</Text>
          </Card>
        </View>
        <SectionTitle title="Riwayat penarikan" />
        {!wds.data?.length ? (
          <Empty testID="withdrawals-empty" icon="receipt-outline" title="Belum ada penarikan" />
        ) : (
          wds.data.map((w) => (
            <Card key={w.withdrawal_id} testID={`withdrawal-${w.withdrawal_id}`} style={styles.wd}>
              <View style={{ flex: 1, gap: 4 }}>
                <Text style={{ color: c.textPrimary, fontWeight: "900", fontSize: 16 }}>{rp(w.amount)}</Text>
                <Text style={{ color: c.textSecondary, fontSize: 12 }}>{w.method} · {w.account_number} · {fmtDate(w.created_at)}</Text>
                {w.reference ? <Text style={{ color: c.textMuted, fontSize: 12 }}>Ref: {w.reference}</Text> : null}
              </View>
              <StatusChip status={`wd_${w.status}`} />
            </Card>
          ))
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  balance: { borderRadius: 24, padding: 20, gap: 14 },
  balLbl: { fontSize: 12, fontWeight: "600" },
  balVal: { fontSize: 34, fontWeight: "900", letterSpacing: -1 },
  balRow: { flexDirection: "row", gap: 32 },
  balSmall: { fontSize: 16, fontWeight: "800", marginTop: 2 },
  stats: { flexDirection: "row", gap: 10 },
  wd: { flexDirection: "row", alignItems: "center", gap: 12 },
});
