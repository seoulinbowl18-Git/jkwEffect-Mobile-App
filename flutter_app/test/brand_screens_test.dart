import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/views/brand/create_campaign_view.dart';
import 'package:ourbuzzer/views/brand/topup_payment_view.dart';
import 'package:ourbuzzer/views/brand/topup_view.dart';
import 'package:ourbuzzer/views/campaign/campaign_detail_view.dart';

import 'helpers.dart';

Map<String, dynamic> _topup({String status = 'pending', String type = 'qris'}) => {
      'topup_id': 'TOP_1',
      'amount': 250000,
      'payment_type': type,
      'channel_code': type == 'qris' ? '' : 'BNI',
      'va_number': type == 'qris' ? '' : '8808123456789',
      'qr_string': type == 'qris' ? '00020101021226...QRIS' : '',
      'payment_url': '',
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    };

Map<String, Handler> _brandBase({int balance = 2000000}) => {
      'GET /auth/me': (_) => userJson(role: 'brand', brandBalance: balance),
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /brand/stats': (_) => {'brand_balance': balance, 'active': 1, 'spent': 0, 'views': 0, 'creators': 0, 'budget_left': 0},
      'GET /brand/campaigns': (_) => [],
      'GET /brand/topups': (_) => [],
    };

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Detail campaign milik brand: tutup → konfirmasi refund → PATCH closed', (tester) async {
    var status = 'active';
    final backend = FakeBackend({
      ..._brandBase(),
      'GET /campaigns/cmp_1': (_) => campaignJson(status: status, budget: 1000000, spent: 250000),
      'PATCH /campaigns/cmp_1/status': (req) {
        status = 'closed';
        return {'ok': true, 'refund': 750000};
      },
    });
    await pumpWithSession(tester, backend, const CampaignDetailView(campaignId: 'cmp_1'));

    await tester.ensureVisible(find.byKey(const Key('campaign-close-button')));
    await tester.tap(find.byKey(const Key('campaign-close-button')));
    await tester.pumpAndSettle();
    expect(find.text('Hentikan / Tutup'), findsOneWidget);
    expect(find.textContaining('Sisa budget Rp 750.000 langsung dikembalikan ke saldo brand'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('PATCH', '/campaigns/cmp_1/status'), {'status': 'closed'});
    expect(find.text('Campaign sudah ditutup.'), findsOneWidget);
    expect(find.text('Campaign ditutup · Rp 750.000 kembali ke saldo brand'), findsOneWidget);
  });

  testWidgets('Detail campaign: jeda campaign', (tester) async {
    final backend = FakeBackend({
      ..._brandBase(),
      'GET /campaigns/cmp_1': (_) => campaignJson(),
      'PATCH /campaigns/cmp_1/status': (_) => {'ok': true},
    });
    await pumpWithSession(tester, backend, const CampaignDetailView(campaignId: 'cmp_1'));
    await tester.ensureVisible(find.byKey(const Key('campaign-pause-button')));
    await tester.tap(find.byKey(const Key('campaign-pause-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('PATCH', '/campaigns/cmp_1/status'), {'status': 'paused'});
  });

  testWidgets('Buat campaign: tombol nonaktif bila saldo kurang; sukses mengirim body lengkap', (tester) async {
    final backend = FakeBackend({
      ..._brandBase(balance: 1500000),
      'POST /campaigns': (_) => campaignJson(),
    });
    await pumpWithSession(tester, backend, const CreateCampaignView());

    final budget = find.byKey(const Key('campaign-budget-input'));
    await tester.enterText(budget, '2000000');
    await tester.pump();
    expect(find.text('Saldo kurang, top up dulu'), findsOneWidget);

    await tester.enterText(budget, '1000000');
    await tester.enterText(find.byKey(const Key('campaign-title-input')), 'Kopi Susu Viral');
    await tester.tap(find.byKey(const Key('campaign-platform-youtube')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('campaign-instructions-input')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('campaign-instructions-input')), 'Video 30 detik, sebut brand.');
    await tester.pumpAndSettle();
    // ListView membangun item secara lazy → gulir sampai tombol ter-build.
    await tester.scrollUntilVisible(find.byKey(const Key('campaign-create-button')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();

    expect(backend.lastBody('POST', '/campaigns'), {
      'title': 'Kopi Susu Viral',
      'category': 'Produk',
      'platforms': ['tiktok', 'youtube'],
      'rate_per_1k': 5000,
      'min_views': 5000,
      'budget': 1000000,
      'thumbnail': '',
      'instructions': 'Video 30 detik, sebut brand.',
      'exclusive': false,
      'deadline_days': 30,
    });
  });

  testWidgets('Top up VA: buat tagihan → nomor VA tampil → cek status lunas', (tester) async {
    var status = 'pending';
    final backend = FakeBackend({
      ..._brandBase(),
      'POST /brand/topups': (_) => _topup(type: 'bank_transfer'),
      'POST /brand/topups/TOP_1/check': (_) => _topup(type: 'bank_transfer', status: status),
    });
    await pumpWithSession(tester, backend, const TopupView());

    await tester.tap(find.byKey(const Key('topup-preset-250000')));
    await tester.tap(find.text('Virtual Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('topup-bank-BNI')));
    await tester.ensureVisible(find.byKey(const Key('topup-create-button')));
    await tester.tap(find.byKey(const Key('topup-create-button')));
    await tester.pumpAndSettle();

    expect(backend.lastBody('POST', '/brand/topups'),
        {'amount': 250000, 'payment_type': 'bank_transfer', 'channel_code': 'BNI'});
    expect(find.text('8808123456789'), findsOneWidget);

    await tester.tap(find.byKey(const Key('topup-check-button')));
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran belum diterima'), findsOneWidget);

    status = 'paid';
    await tester.tap(find.byKey(const Key('topup-check-button')));
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran diterima'), findsOneWidget);
    expect(find.byKey(const Key('topup-check-button')), findsNothing);
  });

  testWidgets('Top up QRIS: QR tampil & polling otomatis mendeteksi lunas', (tester) async {
    var checks = 0;
    final backend = FakeBackend({
      ..._brandBase(),
      'POST /brand/topups/TOP_1/check': (_) => _topup(status: ++checks >= 2 ? 'paid' : 'pending'),
    });
    await pumpWithSession(
      tester,
      backend,
      TopupPaymentView(topup: Topup.fromJson(_topup()), pollInterval: const Duration(seconds: 5)),
    );
    expect(find.byKey(const Key('topup-qr')), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(checks, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('Pembayaran diterima'), findsOneWidget);

    // Polling berhenti setelah lunas.
    await tester.pump(const Duration(seconds: 15));
    expect(checks, 2);
  });
}
