/// Perhitungan fee platform — identik dengan backend `fee_amount()`:
/// persen → basis point (integer), dibulatkan ke rupiah terdekat (setengah ke atas).
library;

int feeOf(int amount, num pct) {
  final a = amount < 0 ? 0 : amount;
  final bp = (pct * 100).round();
  return (a * bp + 5000) ~/ 10000;
}

/// Top up brand: saldo masuk [amount], tagihan = amount + fee.
({int amount, int fee, int total}) topupQuote(int amount, num pct) {
  final fee = feeOf(amount, pct);
  return (amount: amount, fee: fee, total: amount + fee);
}

/// Penarikan: saldo dipotong [amount], dana diterima = amount - fee.
({int amount, int fee, int net}) withdrawQuote(int amount, num pct) {
  final fee = feeOf(amount, pct);
  return (amount: amount, fee: fee, net: amount - fee);
}

/// `10` → "10", `12.5` → "12,5".
String pctLabel(num pct) => pct == pct.roundToDouble() ? '${pct.round()}' : '$pct'.replaceAll('.', ',');
