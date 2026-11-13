import React from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, TextInputProps, View, ViewStyle } from "react-native";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme, radius } from "@/src/theme";
import { STATUS, Tone } from "@/src/lib/format";

type BtnProps = {
  title: string;
  onPress: () => void;
  variant?: "primary" | "dark" | "outline" | "danger";
  icon?: string;
  loading?: boolean;
  disabled?: boolean;
  testID: string;
  style?: ViewStyle;
  small?: boolean;
};

export function Button({ title, onPress, variant = "primary", icon, loading, disabled, testID, style, small }: BtnProps) {
  const c = useTheme();
  const bg = { primary: c.primary, dark: c.ink, outline: c.surface, danger: c.danger }[variant];
  const fg = variant === "outline" ? c.textPrimary : variant === "dark" ? c.onInk : c.onPrimary;
  return (
    <Pressable
      testID={testID}
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.btn,
        small && styles.btnSmall,
        { backgroundColor: bg, opacity: disabled ? 0.5 : 1, transform: [{ scale: pressed ? 0.97 : 1 }] },
        variant === "outline" && { borderWidth: 1, borderColor: c.border },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <>
          {icon && <Ionicons name={icon as any} size={small ? 16 : 18} color={fg} />}
          <Text style={[styles.btnText, small && { fontSize: 14 }, { color: fg }]}>{title}</Text>
        </>
      )}
    </Pressable>
  );
}

export function Field({ label, hint, ...props }: TextInputProps & { label: string; hint?: string }) {
  const c = useTheme();
  return (
    <View style={{ gap: 6 }}>
      <Text style={[styles.label, { color: c.textSecondary }]}>{label}</Text>
      <TextInput
        placeholderTextColor={c.textMuted}
        {...props}
        style={[styles.input, { backgroundColor: c.surfaceMuted, color: c.textPrimary }, props.multiline && { height: 110, paddingTop: 12, textAlignVertical: "top" }, props.style]}
      />
      {hint ? <Text style={{ fontSize: 12, color: c.textMuted }}>{hint}</Text> : null}
    </View>
  );
}

export function StatusChip({ status, testID }: { status: string; testID?: string }) {
  const c = useTheme();
  const s = STATUS[status] || { label: status, tone: "muted" as Tone };
  const map: Record<Tone, [string, string]> = {
    warning: [c.warningSoft, c.warningText], info: [c.infoSoft, c.infoText], primary: [c.primarySoft, c.primaryText],
    success: [c.successSoft, c.successText], danger: [c.dangerSoft, c.dangerText], muted: [c.surfaceMuted, c.textSecondary],
  };
  const [bg, fg] = map[s.tone];
  return (
    <View testID={testID} style={[styles.chip, { backgroundColor: bg }]}>
      <Text style={[styles.chipText, { color: fg }]}>{s.label}</Text>
    </View>
  );
}

export function Card({ children, style, testID }: { children: React.ReactNode; style?: ViewStyle; testID?: string }) {
  const c = useTheme();
  return <View testID={testID} style={[styles.card, { backgroundColor: c.surface, borderColor: c.border }, style]}>{children}</View>;
}

export function Empty({ icon, title, desc, testID }: { icon: string; title: string; desc?: string; testID?: string }) {
  const c = useTheme();
  return (
    <View testID={testID} style={styles.empty}>
      <View style={[styles.emptyIcon, { backgroundColor: c.primarySoft }]}>
        <Ionicons name={icon as any} size={28} color={c.primary} />
      </View>
      <Text style={[styles.emptyTitle, { color: c.textPrimary }]}>{title}</Text>
      {desc ? <Text style={{ color: c.textSecondary, textAlign: "center", fontSize: 14 }}>{desc}</Text> : null}
    </View>
  );
}

export function SectionTitle({ title, desc }: { title: string; desc?: string }) {
  const c = useTheme();
  return (
    <View style={{ gap: 2 }}>
      <Text style={{ fontSize: 20, fontWeight: "800", color: c.textPrimary, letterSpacing: -0.4 }}>{title}</Text>
      {desc ? <Text style={{ fontSize: 13, color: c.textSecondary }}>{desc}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  btn: { height: 50, borderRadius: radius.md, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, paddingHorizontal: 18 },
  btnSmall: { height: 40, paddingHorizontal: 12, borderRadius: 10 },
  btnText: { fontSize: 15, fontWeight: "800" },
  label: { fontSize: 12, fontWeight: "700", textTransform: "uppercase", letterSpacing: 0.6 },
  input: { height: 50, borderRadius: radius.md, paddingHorizontal: 14, fontSize: 15 },
  chip: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 8, alignSelf: "flex-start" },
  chipText: { fontSize: 12, fontWeight: "700" },
  card: { borderRadius: radius.lg, borderWidth: 1, padding: 16 },
  empty: { alignItems: "center", paddingVertical: 48, paddingHorizontal: 24, gap: 10 },
  emptyIcon: { width: 64, height: 64, borderRadius: 20, alignItems: "center", justifyContent: "center" },
  emptyTitle: { fontSize: 17, fontWeight: "800" },
});
