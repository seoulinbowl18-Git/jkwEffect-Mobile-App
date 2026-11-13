import React from "react";
import { Platform } from "react-native";
import { Tabs } from "expo-router";
import { NativeTabs } from "expo-router/native-tabs";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useAuth } from "@/src/context/AuthContext";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";

export default function TabsLayout() {
  const c = useTheme();
  const { user } = useAuth();
  const brand = user?.role === "brand";
  const tabs = [
    { name: "index", label: brand ? "Beranda" : "Cuan", icon: brand ? "grid" : "flash", sf: brand ? "square.grid.2x2.fill" : "bolt.fill" },
    { name: "activity", label: brand ? "Review" : "Konten", icon: brand ? "checkmark-done" : "videocam", sf: brand ? "checkmark.seal.fill" : "video.fill" },
    { name: "wallet", label: brand ? "Saldo" : "Dompet", icon: "wallet", sf: "wallet.pass.fill" },
    { name: "profile", label: "Profil", icon: "person", sf: "person.fill" },
  ];

  if (usesNativeTabs) {
    return (
      <NativeTabs tintColor={c.primary}>
        {tabs.map((t) => (
          <NativeTabs.Trigger key={t.name} name={t.name}>
            <NativeTabs.Trigger.Icon sf={t.sf as any} />
            <NativeTabs.Trigger.Label>{t.label}</NativeTabs.Trigger.Label>
          </NativeTabs.Trigger>
        ))}
      </NativeTabs>
    );
  }

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: c.primary,
        tabBarInactiveTintColor: c.textMuted,
        tabBarStyle: { backgroundColor: c.surface, borderTopColor: c.border, ...(Platform.OS === "web" ? { height: 64 } : {}) },
        tabBarItemStyle: { alignSelf: "center" },
        tabBarLabelStyle: { fontSize: 11, fontWeight: "700" },
      }}
    >
      {tabs.map((t) => (
        <Tabs.Screen
          key={t.name}
          name={t.name}
          options={{
            title: t.label,
            tabBarButtonTestID: `tab-${t.name}`,
            tabBarIcon: ({ color, focused, size }) => (
              <Ionicons name={(focused ? t.icon : `${t.icon}-outline`) as any} size={size - 2} color={color} />
            ),
          }}
        />
      ))}
    </Tabs>
  );
}
