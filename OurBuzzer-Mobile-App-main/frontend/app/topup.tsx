import React, { useEffect, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Clipboard from "expo-clipboard";
import * as WebBrowser from "expo-web-browser";
import QRCode from "react-native-qrcode-svg";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { brandApi } from "@/src/api/services";
import { errMsg } from "@/src/api/client";
import type { Topup } from "@/src/api/types";
import { useAuth } from "@/src/context/AuthContext";
import { ScreenHeader } from "@/src/components/ScreenHeader";
import { Chips } from "@/src/components/Chips";
import { Button, Card, Field, StatusChip } from "@/src/components/ui";
import { useToast } from "@/src/components/Toast";
import { rp } from "@/src/lib/format";
import { useTheme } from "@/src/theme";

const BANKS = ["BCA", "BNI", "BRI", "MANDIRI", "PERMATA", "CIMB"].map((k) => ({ key: k, label: k }));

export default function TopupScreen() {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const qc = useQueryClient();
  const { refresh } = useAuth();
  const { tid } = useLocalSearchParams<{ tid?: string }>();
  const history = useQuery({ queryKey: ["topups"], queryFn: brandApi.topups, enabled: !!tid });
  const [pay, setPay] = useState<Topup | null>(null);
  const [amount, setAmount] = useState("100000");
  const [type, setType] = useState<"qris" | "bank_transfer">("qris");
  const [bank, setBank] = useState("BCA");
  const [phone, setPhone] = useState("");
  const [loading, setLoading] = useState(false);
  const [checking, setChecking] = useState(false);
  const amt = parseInt(amount.replace(/\D/g, ""), 10) || 0;

  useEffect(() => {
    if (tid && history.data && !pay) setPay(history.data.find((t) => t.topup_id === tid) || null);
  }, [tid, history.data, pay]);

  const onPaid = () => {
    toast("Top up berhasil! Saldo brand bertambah.", "success");
    ["brand-stats", "topups"].forEach((k) => qc.invalidateQueries({ queryKey: [k] }));
    refresh();
  };

  // Poll payment status every 5s while pending (Komerce allows max 1 request / 3s)
  useEffect(() => {
    if (!pay || pay.status !== "pending") return;
    const t = setInterval(async () => {
      try {
        const r = await brandApi.checkTopup(pay.topup_id);
        if (r.status !== "pending") { setPay(r); if (r.status === "paid") onPaid(); }
      } catch {}
    }, 5000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pay?.topup_id, pay?.status]);

  const create = async () => {
    setLoading(true);
    try {
      const t = await brandApi.createTopup({ amount: amt, payment_type: type, channel_code: type === "bank_transfer" ? bank : undefined, phone: phone || undefined });
      setPay(t);
      qc.invalidateQueries({ queryKey: ["topups"] });
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setLoading(false);
    }
  };

  const check = async () => {
    if (!pay) return;
    setChecking(true);
    try {
      const r = await brandApi.checkTopup(pay.topup_id);
      setPay(r);
      if (r.status === "paid") onPaid();
      else toast(r.status === "pending" ? "Pembayaran belum diterima" : "Pembayaran tidak berhasil", "info");
    } catch (e) {
      toast(errMsg(e), "error");
    } finally {
      setChecking(false);
    }
  };

  const copy = async (s: string) => { await Clipboard.setStringAsync(s); toast("Disalin", "success"); };

  return (
    <View style={{ flex: 1, backgroundColor: c.background }} testID="topup-screen">
      <ScreenHeader title="Top up saldo" />
      <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: insets.bottom + 24 }}>
        {pay ? (
          <>
            <Card style={{ alignItems: "center", gap: 12 }} testID="topup-payment-card">
              <StatusChip status={pay.status} testID="topup-payment-status" />
              <Text style={{ color: c.textSecondary }}>Total pembayaran</Text>
              <Text style={{ color: c.textPrimary, fontSize: 30, fontWeight: "900" }} testID="topup-payment-amount">{rp(pay.amount)}</Text>
              {pay.status === "paid" ? (
                <View style={{ alignItems: "center", gap: 8, paddingVertical: 12 }}>
                  <Ionicons name="checkmark-circle" size={64} color={c.success} />
                  <Text style={{ color: c.textPrimary, fontWeight: "800" }}>Saldo sudah masuk</Text>
                </View>
              ) : pay.qr_string ? (
                <View style={styles.qr} testID="topup-qris-code">
                  <QRCode value={pay.qr_string} size={220} backgroundColor="#FFFFFF" color="#0F172A" />
                </View>
              ) : pay.va_number ? (
                <View style={[styles.va, { backgroundColor: c.surfaceMuted }]}>
                  <Text style={{ color: c.textSecondary, fontSize: 12 }}>Virtual Account {pay.channel_code}</Text>
                  <Text style={{ color: c.textPrimary, fontSize: 24, fontWeight: "900", letterSpacing: 1 }} testID="topup-va-number">{pay.va_number}</Text>
                  <Button testID="topup-copy-va-button" title="Salin nomor VA" icon="copy" small variant="outline" onPress={() => copy(pay.va_number)} />
                </View>
              ) : null}
              {pay.status === "pending" && (
                <Text style={{ color: c.textSecondary, fontSize: 13, textAlign: "center" }}>
                  {pay.qr_string ? "Scan QRIS dengan aplikasi bank / e-wallet." : "Transfer ke nomor VA di atas."} Status dicek otomatis.
                </Text>
              )}
            </Card>
            {pay.status === "pending" && (
              <>
                {pay.payment_url ? (
                  <Button testID="topup-open-payment-page" title="Buka halaman pembayaran" icon="open-outline" variant="outline" onPress={() => WebBrowser.openBrowserAsync(pay.payment_url)} />
                ) : null}
                <Button testID="topup-check-status-button" title="Cek status pembayaran" icon="refresh" variant="dark" onPress={check} loading={checking} />
              </>
            )}
            <Button testID="topup-new-button" title="Top up baru" variant="outline" onPress={() => setPay(null)} />
          </>
        ) : (
          <>
            <Field testID="topup-amount-input" label="Nominal (Rp)" value={amount} onChangeText={setAmount} keyboardType="number-pad" hint="Minimal Rp 10.000 · QRIS maks. Rp 10.000.000" />
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {[100000, 250000, 500000, 1000000].map((v) => (
                <Pressable key={v} testID={`topup-quick-${v}`} onPress={() => setAmount(String(v))}
                  style={[styles.quick, { borderColor: amt === v ? c.primary : c.border, backgroundColor: amt === v ? c.primarySoft : c.surface }]}>
                  <Text style={{ fontWeight: "700", color: amt === v ? c.primary : c.textPrimary }}>{rp(v)}</Text>
                </Pressable>
              ))}
            </View>
            <View style={{ flexDirection: "row", gap: 10 }}>
              {([["qris", "QRIS", "qr-code"], ["bank_transfer", "Virtual Account", "business"]] as const).map(([k, label, icon]) => {
                const on = type === k;
                return (
                  <Pressable key={k} testID={`topup-method-${k}`} onPress={() => setType(k)}
                    style={[styles.method, { borderColor: on ? c.primary : c.border, backgroundColor: c.surface, borderWidth: on ? 2 : 1 }]}>
                    <Ionicons name={icon} size={24} color={on ? c.primary : c.textSecondary} />
                    <Text style={{ fontWeight: "800", color: c.textPrimary }}>{label}</Text>
                  </Pressable>
                );
              })}
            </View>
            {type === "bank_transfer" && <Chips items={BANKS} value={bank} onChange={setBank} testPrefix="topup-bank" padded={false} />}
            <Field testID="topup-phone-input" label="No. HP (opsional)" value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="0812..." />
            <Card style={{ backgroundColor: c.infoSoft, borderColor: c.infoSoft }}>
              <Text style={{ color: c.infoText, fontSize: 13 }}>Mode sandbox Komerce: tidak ada uang sungguhan yang berpindah.</Text>
            </Card>
            <Button testID="topup-create-button" title={`Bayar ${rp(amt)}`} onPress={create} loading={loading}
              disabled={amt < 10000 || (type === "qris" && amt > 10000000)} />
          </>
        )}
      </KeyboardAwareScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  qr: { padding: 16, backgroundColor: "#FFFFFF", borderRadius: 16 },
  va: { alignSelf: "stretch", alignItems: "center", gap: 8, padding: 16, borderRadius: 14 },
  quick: { height: 36, paddingHorizontal: 12, borderRadius: 10, borderWidth: 1, justifyContent: "center" },
  method: { flex: 1, height: 84, borderRadius: 16, alignItems: "center", justifyContent: "center", gap: 6 },
});
