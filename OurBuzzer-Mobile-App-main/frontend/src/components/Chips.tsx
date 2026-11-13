import React from "react";
import { Pressable, ScrollView, StyleSheet, Text } from "react-native";
import { useTheme } from "@/src/theme";

type Props = { items: { key: string; label: string }[]; value: string; onChange: (k: string) => void; testPrefix: string; padded?: boolean };

export function Chips({ items, value, onChange, testPrefix, padded = true }: Props) {
  const c = useTheme();
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      style={styles.row}
      contentContainerStyle={[styles.content, padded && { paddingHorizontal: 16 }]}
      keyboardShouldPersistTaps="handled"
    >
      {items.map((it) => {
        const on = it.key === value;
        return (
          <Pressable
            key={it.key}
            testID={`${testPrefix}-${it.key}`}
            onPress={() => onChange(it.key)}
            style={[styles.chip, { backgroundColor: on ? c.primary : c.surface, borderColor: on ? c.primary : c.border }]}
          >
            <Text style={[styles.text, { color: on ? c.onPrimary : c.textSecondary }]}>{it.label}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: { height: 56, flexGrow: 0 },
  content: { gap: 8, alignItems: "center" },
  chip: { height: 36, paddingHorizontal: 14, borderRadius: 10, borderWidth: 1, justifyContent: "center", flexShrink: 0 },
  text: { fontSize: 13, fontWeight: "700" },
});
