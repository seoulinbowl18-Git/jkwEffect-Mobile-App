import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme } from "@/src/theme";
import type { Streak } from "@/src/api/types";

export function StreakBanner({ s }: { s: Streak }) {
  const c = useTheme();
  const target = s.streak < 3 ? 3 : s.streak < 7 ? 7 : 30;
  return (
    <LinearGradient testID="streak-banner" colors={["#FFF7ED", "#FFEDD5", "#FDBA74"]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.wrap}>
      <View style={styles.top}>
        <View style={styles.count}>
          <Text style={styles.countNum} testID="streak-count">{s.streak}</Text>
          <Text style={styles.countLbl}>hari</Text>
        </View>
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
            {s.streak > 0 && <Ionicons name="flame" size={18} color={c.primary} />}
            <Text style={styles.title}>{s.streak > 0 ? `Streak ${s.streak} hari` : "Mulai streak"}</Text>
          </View>
          <Text style={styles.sub}>Target berikutnya: {target} hari</Text>
        </View>
      </View>
      <View style={styles.week}>
        {s.week.map((d) => {
          const today = d.label === "Hari ini";
          return (
            <View key={d.date} style={{ flex: 1, alignItems: "center", gap: 4 }}>
              <View style={[styles.dot, d.posted ? { backgroundColor: c.primary } : today ? styles.todayDot : { backgroundColor: "rgba(255,255,255,0.85)" }]} />
              <Text style={[styles.day, today && { fontWeight: "800", color: "#0F172A" }]} numberOfLines={1}>{today ? "Hari ini" : d.label}</Text>
            </View>
          );
        })}
      </View>
      <View style={styles.foot}>
        <View style={[styles.live, { backgroundColor: s.posted_today ? c.success : c.danger }]} />
        <Text style={styles.footText}>
          {s.posted_today ? "Mantap! Kamu sudah posting hari ini." : "Posting 1 video hari ini biar streak lanjut."}
        </Text>
      </View>
    </LinearGradient>
  );
}

// Banner keeps the same warm gradient in light & dark mode, so text colors are fixed literals.
const styles = StyleSheet.create({
  wrap: { borderRadius: 20, padding: 16, borderWidth: 1, borderColor: "#FED7AA", gap: 14 },
  top: { flexDirection: "row", alignItems: "center", gap: 14 },
  count: { width: 60, height: 60, borderRadius: 14, backgroundColor: "#FFFFFF", alignItems: "center", justifyContent: "center" },
  countNum: { fontSize: 24, fontWeight: "900", color: "#0F172A", lineHeight: 26 },
  countLbl: { fontSize: 11, color: "#64748B" },
  title: { fontSize: 17, fontWeight: "900", color: "#0F172A" },
  sub: { fontSize: 13, fontWeight: "700", color: "#C2410C", marginTop: 2 },
  week: { flexDirection: "row", gap: 6 },
  dot: { height: 10, alignSelf: "stretch", borderRadius: 5 },
  todayDot: { borderWidth: 2, borderStyle: "dashed", borderColor: "#94A3B8", backgroundColor: "#FFFFFF" },
  day: { fontSize: 10, color: "#64748B" },
  foot: { flexDirection: "row", alignItems: "center", gap: 8, borderTopWidth: 1, borderTopColor: "rgba(251,146,60,0.4)", paddingTop: 10 },
  live: { width: 8, height: 8, borderRadius: 4 },
  footText: { fontSize: 13, color: "#0F172A", fontWeight: "600", flex: 1 },
});
