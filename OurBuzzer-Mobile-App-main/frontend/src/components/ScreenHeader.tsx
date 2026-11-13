import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme } from "@/src/theme";

// Header for stack (non-tab) screens with a back button
export function ScreenHeader({ title, right }: { title: string; right?: React.ReactNode }) {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  return (
    <View style={[styles.wrap, { paddingTop: insets.top + 8, backgroundColor: c.background, borderBottomColor: c.border }]}>
      <Pressable testID="header-back-button" onPress={() => (router.canGoBack() ? router.back() : router.replace("/"))} style={[styles.back, { backgroundColor: c.surface, borderColor: c.border }]}>
        <Ionicons name="chevron-back" size={22} color={c.textPrimary} />
      </Pressable>
      <Text numberOfLines={1} style={[styles.title, { color: c.textPrimary }]}>{title}</Text>
      <View style={{ minWidth: 44, alignItems: "flex-end" }}>{right}</View>
    </View>
  );
}

// Title header for tab screens
export function TabHeader({ title, subtitle, right }: { title: string; subtitle?: string; right?: React.ReactNode }) {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.tabWrap, { paddingTop: insets.top + 12, backgroundColor: c.background }]}>
      <View style={{ flex: 1 }}>
        <Text style={[styles.tabTitle, { color: c.textPrimary }]}>{title}</Text>
        {subtitle ? <Text style={{ color: c.textSecondary, fontSize: 13, marginTop: 2 }}>{subtitle}</Text> : null}
      </View>
      {right}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: 16, paddingBottom: 12, borderBottomWidth: StyleSheet.hairlineWidth },
  back: { width: 44, height: 44, borderRadius: 14, borderWidth: 1, alignItems: "center", justifyContent: "center" },
  title: { flex: 1, fontSize: 18, fontWeight: "800" },
  tabWrap: { flexDirection: "row", alignItems: "center", paddingHorizontal: 20, paddingBottom: 12, gap: 12 },
  tabTitle: { fontSize: 28, fontWeight: "900", letterSpacing: -0.8 },
});
