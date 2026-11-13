import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/core/fees.dart';
import 'package:ourbuzzer/views/brand/brand_wallet_view.dart';
import 'package:ourbuzzer/views/brand/topup_view.dart';
import 'package:ourbuzzer/views/creator/withdraw_view.dart';

import 'helpers.dart';

Map<String, dynamic> _fees({num topup = 10, num creator = 15, num brand = 0}) => {
      'brand_topup_fee_pct': topup,
      'creator_withdraw_fee_pct': creator,
      'brand_withdraw_fee_pct': brand,
      'min_topup': 10000,
      'min_withdraw': 50000,
    };

Map<String, Handler> _base({String role = 'creator', Map<String, dynamic>? fees, int brandBalance = 0}) => {
      'GET /auth/me': (_) => userJson(role: role, brandBalance: brandBalance),
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /config/fees': (_) => fees ?? _fees(),
    };

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('perhitungan fee identik dengan backend (integer, bulat ke rupiah terdekat)', () {
    const cases = [
      (1000000, 10, 100000), (250000, 10, 25000), (333333, 10, 33333), (10005, 10, 1001),
      (100000, 15, 15000), (66667, 15, 10000), (50003, 15, 7500), (123456, 12.5, 15432), (0, 15, 0),
    ];
    for (final (amount, pct, fee) in cases) {
      expect(feeOf(amount, pct), fee, reason: '$amount × $pct%');
    }
    expect(topupQuote(1000000, 10), (amount: 1000000, fee: 100000, total: 1100000));
    expect(withdrawQuote(200000, 15), (amount: 200000, fee: 30000, net: 170000));
    expect(pctLabel(10), '10');
    expect(pctLabel(12.5), '12,5');
  });

  testWidgets('Top up: rincian saldo masuk + biaya layanan 10% + total tagihan; body kirim saldo masuk', (tester) async {
    final backend = FakeBackend({
      ..._base(role: 'brand'),
      'GET /brand/stats': (_) => {'brand_balance': 0},
      'POST /brand/topups': (_) => {
            'topup_id': 'TOP_1', 'amount': 1000000, 'fee': 100000, 'fee_pct': 10, 'total': 1100000,
            'payment_type': 'qris', 'qr_string': 'QR', 'status': 'pending', 'created_at': '',
          },
      'POST /brand/topups/TOP_1/check': (_) => {'topup_id': 'TOP_1', 'amount': 1000000, 'status': 'pending'},
    });
    await pumpWithSession(tester, backend, const TopupView());
    await tester.enterText(find.byKey(const Key('topup-amount-input')), '1000000');
    await tester.pumpAndSettle();
    final breakdown = find.byKey(const Key('topup-breakdown'));
    expect(find.descendant(of: breakdown, matching: find.text('Nominal saldo masuk')), findsOneWidget);
    expect(find.descendant(of: breakdown, matching: find.text('Rp 1.000.000')), findsOneWidget);
    expect(find.descendant(of: breakdown, matching: find.text('Biaya layanan platform (10%)')), findsOneWidget);
    expect(find.descendant(of: breakdown, matching: find.text('Rp 100.000')), findsOneWidget);
    expect(find.descendant(of: breakdown, matching: find.text('Rp 1.100.000')), findsOneWidget);
    expect(find.text('Bayar Rp 1.100.000'), findsOneWidget);

    await _tap(tester, const Key('topup-create-button'));
    expect(backend.lastBody('POST', '/brand/topups')['amount'], 1000000); // saldo masuk, bukan total
    expect(find.text('Rp 1.100.000'), findsOneWidget); // halaman pembayaran: total tagihan
    expect(find.text('Saldo masuk Rp 1.000.000 + biaya layanan Rp 100.000'), findsOneWidget);
  });

  testWidgets('Top up: persentase fee mengikuti konfigurasi backend', (tester) async {
    final backend = FakeBackend({..._base(role: 'brand', fees: _fees(topup: 12.5))});
    await pumpWithSession(tester, backend, const TopupView());
    await tester.enterText(find.byKey(const Key('topup-amount-input')), '200000');
    await tester.pumpAndSettle();
    expect(find.text('Biaya layanan platform (12,5%)'), findsOneWidget);
    expect(find.text('Bayar Rp 225.000'), findsOneWidget);
  });

  testWidgets('Tarik saldo kreator: rincian biaya platform 15% & dana diterima bersih', (tester) async {
    final backend = FakeBackend({
      ..._base(),
      'GET /creator/stats': (_) => {'balance': 500000, 'streak': {}},
      'POST /withdrawals': (_) => {
            'withdrawal_id': 'wd_1', 'amount': 200000, 'fee': 30000, 'fee_pct': 15, 'net_amount': 170000,
            'role': 'creator', 'method': 'DANA', 'account_number': '081234567', 'account_holder': 'Ani',
            'status': 'diproses', 'reference': '', 'created_at': '',
          },
    });
    await pumpWithSession(tester, backend, const WithdrawView(balance: 500000));
    await tester.enterText(find.byKey(const Key('withdraw-amount-input')), '200000');
    await tester.pumpAndSettle();
    final b = find.byKey(const Key('withdraw-breakdown'));
    expect(find.descendant(of: b, matching: find.text('Nominal penarikan')), findsOneWidget);
    expect(find.descendant(of: b, matching: find.text('Rp 200.000')), findsOneWidget);
    expect(find.descendant(of: b, matching: find.text('Biaya platform (15%)')), findsOneWidget);
    expect(find.descendant(of: b, matching: find.text('-Rp 30.000')), findsOneWidget);
    expect(find.descendant(of: b, matching: find.text('Total dana diterima bersih')), findsOneWidget);
    expect(find.descendant(of: b, matching: find.text('Rp 170.000')), findsOneWidget);

    await _tap(tester, const Key('withdraw-submit-button'));
    expect(find.textContaining('Dana diterima bersih: Rp 170.000'), findsOneWidget); // dialog konfirmasi
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('POST', '/withdrawals')['amount'], 200000);
  });

  testWidgets('Tarik saldo brand: ke /brand/withdrawals, tanpa biaya (konfigurasi 0%)', (tester) async {
    final backend = FakeBackend({
      ..._base(role: 'brand', brandBalance: 300000),
      'GET /brand/stats': (_) => {'brand_balance': 300000},
      'POST /brand/withdrawals': (_) => {
            'withdrawal_id': 'wd_b', 'amount': 120000, 'fee': 0, 'fee_pct': 0, 'net_amount': 120000, 'role': 'brand',
            'method': 'BCA', 'account_number': '1234567', 'account_holder': 'Kopi', 'status': 'diproses',
            'reference': '', 'created_at': '',
          },
    });
    await pumpWithSession(tester, backend, const WithdrawView(balance: 300000, forBrand: true));
    expect(find.text('Saldo brand tersedia: Rp 300.000'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('withdraw-amount-input')), '120000');
    await tester.enterText(find.byKey(const Key('withdraw-account-input')), '1234567');
    await tester.enterText(find.byKey(const Key('withdraw-holder-input')), 'Kopi');
    await tester.pumpAndSettle();
    expect(find.text('Biaya platform (0%)'), findsOneWidget);
    await _tap(tester, const Key('withdraw-submit-button'));
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.called('POST', '/withdrawals'), isFalse);
    expect(backend.lastBody('POST', '/brand/withdrawals')['amount'], 120000);
  });

  testWidgets('Dompet brand: escrow, tombol Tarik saldo, riwayat penarikan & mutasi saldo', (tester) async {
    final backend = FakeBackend({
      ..._base(role: 'brand', brandBalance: 880000),
      'GET /brand/stats': (_) =>
          {'brand_balance': 880000, 'active': 1, 'spent': 120000, 'views': 12000, 'creators': 1, 'budget_left': 500000},
      'GET /brand/topups': (_) => [
            {'topup_id': 'TOP_9', 'amount': 1000000, 'fee': 100000, 'fee_pct': 10, 'total': 1100000,
             'payment_type': 'qris', 'status': 'paid', 'created_at': ''},
          ],
      'GET /brand/withdrawals': (_) => [
            {'withdrawal_id': 'wd_b', 'amount': 100000, 'fee': 0, 'net_amount': 100000, 'role': 'brand',
             'method': 'BCA', 'account_number': '1234567', 'account_holder': 'Kopi', 'status': 'disetujui',
             'reference': 'TRX', 'created_at': ''},
          ],
      'GET /ledger': (_) => [
            {'entry_id': 'l3', 'type': 'campaign_refund', 'label': 'Sisa budget dikembalikan', 'amount': 380000,
             'note': 'Kopi', 'created_at': ''},
            {'entry_id': 'l2', 'type': 'campaign_budget', 'label': 'Budget campaign dikunci', 'amount': -500000,
             'note': 'Kopi', 'created_at': ''},
          ],
    });
    await pumpWithSession(tester, backend, const BrandWalletView());
    expect(find.byKey(const Key('brand-balance')), findsOneWidget);
    expect(find.text('Terkunci di campaign berjalan: Rp 500.000'), findsOneWidget);
    expect(find.text('+Rp 1.000.000 saldo masuk'), findsOneWidget);
    expect(find.textContaining('Dibayar Rp 1.100.000 (biaya layanan Rp 100.000)'), findsOneWidget);
    expect(find.byKey(const Key('withdrawal-net-wd_b')), findsOneWidget);

    await _tap(tester, const Key('brand-ledger-button'));
    expect(find.text('Sisa budget dikembalikan'), findsOneWidget);
    expect(find.text('+Rp 380.000'), findsOneWidget);
    expect(find.text('-Rp 500.000'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tap(tester, const Key('brand-withdraw-button'));
    expect(find.text('Saldo brand tersedia: Rp 880.000'), findsOneWidget);
  });
}
