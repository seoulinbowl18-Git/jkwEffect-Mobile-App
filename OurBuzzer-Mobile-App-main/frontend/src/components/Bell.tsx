import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme } from "@/src/theme";
import { notifApi } from "@/src/api/services";

export function Bell() {
  const c = useTheme();
  const router = useRouter();
  const { data } = useQuery({ queryKey: ["notifications"], queryFn: notifApi.list, refetchInterval: 30000 });
  const unread = data?.unread || 0;
  return (
    <Pressable testID="notification-bell" onPress={() => router.push("/notifications")} style={[styles.btn, { backgroundColor: c.surface, borderColor: c.border }]}>
      <Ionicons name="notifications-outline" size={22} color={c.textPrimary} />
      {unread > 0 && (
        <View style={[styles.badge, { backgroundColor: c.primary }]} testID="notification-unread-badge">
          <Text style={styles.badgeText}>{unread > 9 ? "9+" : unread}</Text>
        </View>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  btn: { width: 44, height: 44, borderRadius: 14, borderWidth: 1, alignItems: "center", justifyContent: "center" },
  badge: { position: "absolute", top: -4, right: -4, minWidth: 20, height: 20, borderRadius: 10, alignItems: "center", justifyContent: "center", paddingHorizontal: 4 },
  badgeText: { color: "#FFFFFF", fontSize: 11, fontWeight: "900" },
});
