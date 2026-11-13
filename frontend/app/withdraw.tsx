import React, { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { creatorApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import { useAuth } from "@/src/context/AuthContext";
import { ScreenHeader } from "@/src/components/ScreenHeader";
import { Chips } from "@/src/components/Chips";
import { Button, Card, Field } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { MIN_WITHDRAW, rp } from "@/src/lib/format";
import { useTheme } from "@/src/theme";

const METHODS = ["BCA", "BNI", "BRI", "Mandiri", "DANA", "OVO", "GoPay", "ShopeePay"].map((k) => ({ key: k, label: k }));

export default function Withdraw() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const qc = useQueryClient();
  const { user, refresh } = useAuth();
  const stats = useQuery({ queryKey: ["creator-stats"], queryFn: creatorApi.stats });
  const bal = stats.data?.balance || 0;
  const p = user?.profile || {};
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState(p.bank_method || "BCA");
  const [acc, setAcc] = useState(p.bank_account || "");
  const [holder, setHolder] = useState(p.bank_holder || user?.name || "");
  const [loading, setLoading] = useState(false);
  const amt = parseInt(amount.replace(/\D/g, ""), 10) || 0;
  const error = amt && amt < MIN_WITHDRAW ? `Minimal ${rp(MIN_WITHDRAW)}` : amt > bal ? "Saldo tidak cukup" : null;

  const submit = async () => {
    setLoading(true);
    try {
      await creatorApi.withdraw({ amount: amt, method, account_number: acc.trim(), account_holder: holder.trim() });
      qc.invalidateQueries({ queryKey: ["creator-stats"] });
      qc.invalidateQueries({ queryKey: ["withdrawals"] });
      refresh();
      toast("Penarikan diajukan, admin akan memproses", "success");
      router.back();
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="withdraw-screen">
      <ScreenHeader title="Tarik saldo" />
      <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: insets.bottom + 24 }}>
        <Card style={{ backgroundColor: c.successSoft, borderColor: c.successSoft }}>
          <Text style={{ color: c.successText, fontSize: 12, fontWeight: "700" }}>SALDO TERSEDIA</Text>
          <Text style={{ color: c.successText, fontSize: 26, fontWeight: "900" }} testID="withdraw-balance">{rp(bal)}</Text>
        </Card>
        <Field testID="withdraw-amount-input" label="Jumlah (Rp)" value={amount} onChangeText={setAmount} keyboardType="number-pad" placeholder="50000" />
        <View style={{ flexDirection: "row", gap: 8, flexWrap: "wrap" }}>
          {[50000, 100000, 250000].map((v) => (
            <Pressable key={v} testID={`withdraw-quick-${v}`} onPress={() => setAmount(String(v))} style={[styles.quick, { borderColor: c.border, backgroundColor: c.surface }]}>
              <Text style={{ fontWeight: "700", color: c.textPrimary }}>{rp(v)}</Text>
            </Pressable>
          ))}
          <Pressable testID="withdraw-quick-all" onPress={() => setAmount(String(bal))} style={[styles.quick, { borderColor: c.primary, backgroundColor: c.primarySoft }]}>
            <Text style={{ fontWeight: "800", color: c.primary }}>Semua</Text>
          </Pressable>
        </View>
        {error ? <Text style={{ color: c.danger, fontWeight: "700" }} testID="withdraw-error">{error}</Text> : null}
        <View style={{ gap: 6 }}>
          <Text style={[styles.label, { color: c.textSecondary }]}>Metode</Text>
          <Chips items={METHODS} value={method} onChange={setMethod} testPrefix="withdraw-method" padded={false} />
        </View>
        <Field testID="withdraw-account-input" label="Nomor rekening / e-wallet" value={acc} onChangeText={setAcc} keyboardType="number-pad" />
        <Field testID="withdraw-holder-input" label="Nama pemilik" value={holder} onChangeText={setHolder} />
        <Button testID="withdraw-submit-button" title="Ajukan penarikan" onPress={submit} loading={loading}
          disabled={!amt || !!error || acc.trim().length < 5 || holder.trim().length < 2} />
      </KeyboardAwareScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  quick: { height: 36, paddingHorizontal: 12, borderRadius: 10, borderWidth: 1, justifyContent: "center" },
  label: { fontSize: 12, fontWeight: "700", textTransform: "uppercase", letterSpacing: 0.6 },
});
