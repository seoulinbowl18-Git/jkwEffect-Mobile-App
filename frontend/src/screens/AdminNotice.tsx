import React from "react";
import { View } from "react-native";
import { TabHeader } from "@/src/components/ScreenHeader";
import { Empty } from "@/src/components/ui";
import { useTheme } from "@/src/theme";

export default function AdminNotice({ title }: { title: string }) {
  const c = useTheme();
  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="admin-notice">
      <TabHeader title={title} />
      <Empty icon="shield-checkmark" title="Akun admin" desc="Panel admin (approve withdraw & kelola campaign) tersedia di versi web untuk saat ini." />
    </View>
  );
}
