import React from "react";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import type { Platform } from "@/src/api/types";

const ICON: Record<Platform, string> = { tiktok: "logo-tiktok", instagram: "logo-instagram", threads: "at", youtube: "logo-youtube" };

export function PlatformIcon({ p, size = 16, color }: { p: Platform; size?: number; color: string }) {
  return <Ionicons name={ICON[p] as any} size={size} color={color} />;
}
