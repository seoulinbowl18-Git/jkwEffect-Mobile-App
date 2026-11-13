import { useColorScheme } from "react-native";

// Tokens derived from /app/design_guidelines.json (web TryBuzzer "Kinetic Orange" palette)
const light = {
  primary: "#FF5500",
  primaryPressed: "#E04B00",
  primarySoft: "#FFF1E8",
  primaryText: "#C2410C",
  onPrimary: "#FFFFFF",
  success: "#10B981",
  successSoft: "#D1FAE5",
  successText: "#065F46",
  warning: "#F59E0B",
  warningSoft: "#FEF3C7",
  warningText: "#92400E",
  info: "#0EA5E9",
  infoSoft: "#E0F2FE",
  infoText: "#075985",
  danger: "#EF4444",
  dangerSoft: "#FEE2E2",
  dangerText: "#B91C1C",
  ink: "#0F172A",
  onInk: "#FFFFFF",
  background: "#F8FAFC",
  surface: "#FFFFFF",
  surfaceMuted: "#F1F5F9",
  border: "#E2E8F0",
  textPrimary: "#0F172A",
  textSecondary: "#64748B",
  textMuted: "#94A3B8",
  overlay: "rgba(15,23,42,0.5)",
};

const dark: typeof light = {
  ...light,
  primarySoft: "#3A1A08",
  primaryText: "#FDBA74",
  successSoft: "#064E3B",
  successText: "#6EE7B7",
  warningSoft: "#451A03",
  warningText: "#FCD34D",
  infoSoft: "#0C4A6E",
  infoText: "#7DD3FC",
  dangerSoft: "#450A0A",
  dangerText: "#FCA5A5",
  ink: "#F8FAFC",
  onInk: "#0F172A",
  background: "#0B1120",
  surface: "#1E293B",
  surfaceMuted: "#273449",
  border: "#334155",
  textPrimary: "#F8FAFC",
  textSecondary: "#94A3B8",
  textMuted: "#64748B",
  overlay: "rgba(0,0,0,0.6)",
};

export type Colors = typeof light;
export const colors = light;

export function useTheme(): Colors {
  return useColorScheme() === "dark" ? dark : light;
}

export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 };
export const radius = { sm: 8, md: 12, lg: 16, xl: 20, pill: 999 };
