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
  });

  final String withdrawalId;
  final int amount;
  final String method;
  final String accountNumber;
  final String accountHolder;
  final WithdrawalStatus status;
  final String reference;
  final String createdAt;

  factory Withdrawal.fromJson(Json j) => Withdrawal(
        withdrawalId: asStr(j['withdrawal_id']),
        amount: asInt(j['amount']),
        method: asStr(j['method']),
        accountNumber: asStr(j['account_number']),
        accountHolder: asStr(j['account_holder']),
        status: WithdrawalStatus.fromWire(j['status'] as String?),
        reference: asStr(j['reference']),
        createdAt: asStr(j['created_at']),
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
  });

  final String topupId;
  final int amount;
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
      );
}
