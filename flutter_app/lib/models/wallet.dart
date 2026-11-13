import 'enums.dart';
import 'json_utils.dart';

class Withdrawal {
  const Withdrawal({
    required this.withdrawalId,
    required this.amount,
    required this.method,
    required this.accountNumber,
    required this.accountHolder,
    required this.status,
    required this.reference,
    required this.createdAt,
    this.creatorName = '',
    this.creatorEmail = '',
    this.fee = 0,
    this.feePct = 0,
    int? netAmount,
    this.role = 'creator',
  }) : netAmount = netAmount ?? amount;

  final String withdrawalId;
  final int amount;
  final String method;
  final String accountNumber;
  final String accountHolder;
  final WithdrawalStatus status;
  final String reference;
  final String createdAt;

  /// Hanya terisi di endpoint admin.
  final String creatorName;
  final String creatorEmail;

  /// Biaya platform yang dipotong dari [amount]; [netAmount] = dana yang ditransfer.
  final int fee;
  final num feePct;
  final int netAmount;

  /// `creator` atau `brand` (penarikan saldo brand).
  final String role;
  bool get isBrand => role == 'brand';

  factory Withdrawal.fromJson(Json j) => Withdrawal(
        withdrawalId: asStr(j['withdrawal_id']),
        amount: asInt(j['amount']),
        method: asStr(j['method']),
        accountNumber: asStr(j['account_number']),
        accountHolder: asStr(j['account_holder']),
        status: WithdrawalStatus.fromWire(j['status'] as String?),
        reference: asStr(j['reference']),
        createdAt: asStr(j['created_at']),
        creatorName: asStr(j['creator_name']),
        creatorEmail: asStr(j['creator_email']),
        fee: asInt(j['fee']),
        feePct: (j['fee_pct'] as num?) ?? 0,
        netAmount: j['net_amount'] == null ? null : asInt(j['net_amount']),
        role: asStr(j['role']).isEmpty ? (asStr(j['account_type']).isEmpty ? 'creator' : asStr(j['account_type'])) : asStr(j['role']),
      );
}

/// Top up saldo brand via Komerce (QRIS / Virtual Account).
class Topup {
  const Topup({
    required this.topupId,
    required this.amount,
    required this.paymentType,
    required this.channelCode,
    required this.vaNumber,
    required this.qrString,
    required this.paymentUrl,
    required this.status,
    required this.createdAt,
    this.fee = 0,
    this.feePct = 0,
    int? total,
  }) : total = total ?? amount + fee;

  final String topupId;

  /// Saldo yang masuk ke dompet brand (Rp X).
  final int amount;

  /// Biaya layanan platform; [total] = tagihan yang dibayar (X + fee).
  final int fee;
  final num feePct;
  final int total;
  final PaymentType paymentType;
  final String channelCode;

  /// Diisi bila [paymentType] = bank_transfer.
  final String vaNumber;

  /// Payload QRIS — render dengan `qr_flutter` (QrImageView(data: qrString)).
  final String qrString;
  final String paymentUrl;
  final TopupStatus status;
  final String createdAt;

  bool get isPending => status == TopupStatus.pending;

  factory Topup.fromJson(Json j) => Topup(
        topupId: asStr(j['topup_id']),
        amount: asInt(j['amount']),
        paymentType: PaymentType.fromWire(j['payment_type'] as String?),
        channelCode: asStr(j['channel_code']),
        vaNumber: asStr(j['va_number']),
        qrString: asStr(j['qr_string']),
        paymentUrl: asStr(j['payment_url']),
        status: TopupStatus.fromWire(j['status'] as String?),
        createdAt: asStr(j['created_at']),
        fee: asInt(j['fee']),
        feePct: (j['fee_pct'] as num?) ?? 0,
        total: j['total'] == null ? null : asInt(j['total']),
      );
}

/// Persentase fee platform dari backend (GET /config/fees) — UI tidak menyimpan angka sendiri.
class FeesConfig {
  const FeesConfig({
    this.brandTopupFeePct = 10,
    this.creatorWithdrawFeePct = 15,
    this.brandWithdrawFeePct = 0,
    this.minTopup = 10000,
    this.minWithdraw = 50000,
  });

  final num brandTopupFeePct;
  final num creatorWithdrawFeePct;
  final num brandWithdrawFeePct;
  final int minTopup;
  final int minWithdraw;

  num withdrawFeePct({required bool brand}) => brand ? brandWithdrawFeePct : creatorWithdrawFeePct;

  factory FeesConfig.fromJson(Json j) => FeesConfig(
        brandTopupFeePct: (j['brand_topup_fee_pct'] as num?) ?? 10,
        creatorWithdrawFeePct: (j['creator_withdraw_fee_pct'] as num?) ?? 15,
        brandWithdrawFeePct: (j['brand_withdraw_fee_pct'] as num?) ?? 0,
        minTopup: j['min_topup'] == null ? 10000 : asInt(j['min_topup']),
        minWithdraw: j['min_withdraw'] == null ? 50000 : asInt(j['min_withdraw']),
      );
}

/// Satu baris riwayat mutasi saldo (GET /ledger). [amount] positif = masuk, negatif = keluar.
class LedgerEntry {
  const LedgerEntry({
    required this.entryId,
    required this.type,
    required this.label,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  final String entryId;
  final String type;
  final String label;
  final int amount;
  final String note;
  final String createdAt;

  bool get isCredit => amount >= 0;

  factory LedgerEntry.fromJson(Json j) => LedgerEntry(
        entryId: asStr(j['entry_id']),
        type: asStr(j['type']),
        label: asStr(j['label']).isEmpty ? asStr(j['type']) : asStr(j['label']),
        amount: asInt(j['amount']),
        note: asStr(j['note']),
        createdAt: asStr(j['created_at']),
      );
}

class PaymentsConfig {
  const PaymentsConfig({required this.komerceConfigured, required this.sandbox});
  final bool komerceConfigured;
  final bool sandbox;

  factory PaymentsConfig.fromJson(Json j) =>
      PaymentsConfig(komerceConfigured: asBool(j['komerce_configured']), sandbox: asBool(j['sandbox']));
}
