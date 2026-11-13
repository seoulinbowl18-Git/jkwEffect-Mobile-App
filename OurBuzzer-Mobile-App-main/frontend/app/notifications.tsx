import React, { useEffect } from "react";
import { FlatList, RefreshControl, StyleSheet, Text, View } from "react-native";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { notifApi } from "@/src/api/services";
import { ScreenHeader } from "@/src/components/ScreenHeader";
import { Card, Empty } from "@/src/components/ui";
import { fmtDate } from "@/src/lib/format";
import { useTheme } from "@/src/theme";

export default function Notifications() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const qc = useQueryClient();
  const { data, refetch, isRefetching, isLoading } = useQuery({ queryKey: ["notifications"], queryFn: notifApi.list });

  useEffect(() => {
    if (data?.unread) notifApi.readAll().then(() => qc.invalidateQueries({ queryKey: ["notifications"] })).catch(() => {});
  }, [data?.unread, qc]);

  const tone = (k: string) => (k === "success" ? [c.successSoft, c.success, "checkmark-circle"] : k === "error" ? [c.dangerSoft, c.danger, "alert-circle"] : [c.primarySoft, c.primary, "notifications"]);

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="notifications-screen">
      <ScreenHeader title="Notifikasi" />
      <FlatList
        data={data?.items || []}
        keyExtractor={(n) => n.notification_id}
        contentContainerStyle={{ padding: 16, gap: 10, paddingBottom: insets.bottom + 24 }}
        refreshControl={<RefreshControl refreshing={isRefetching} onRefresh={() => { refetch(); }} tintColor={c.primary} colors={[c.primary]} />}
        ListEmptyComponent={isLoading ? undefined : <Empty testID="notifications-empty" icon="notifications-off-outline" title="Belum ada notifikasi" />}
        renderItem={({ item: n }) => {
          const [bg, fg, icon] = tone(n.kind);
          return (
            <Card testID={`notification-${n.notification_id}`} style={styles.row}>
              <View style={[styles.icon, { backgroundColor: bg }]}><Ionicons name={icon as any} size={20} color={fg} /></View>
              <View style={{ flex: 1, gap: 2 }}>
                <Text style={{ color: c.textPrimary, fontWeight: "800" }}>{n.title}</Text>
                <Text style={{ color: c.textSecondary, fontSize: 13 }}>{n.body}</Text>
                <Text style={{ color: c.textMuted, fontSize: 11, marginTop: 2 }}>{fmtDate(n.created_at)}</Text>
              </View>
              {!n.read && <View style={[styles.dot, { backgroundColor: c.primary }]} />}
            </Card>
          );
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", gap: 12, alignItems: "flex-start", padding: 14 },
  icon: { width: 40, height: 40, borderRadius: 12, alignItems: "center", justifyContent: "center" },
  dot: { width: 8, height: 8, borderRadius: 4, marginTop: 6 },
});
