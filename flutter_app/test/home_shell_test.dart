import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Kreator: Beranda baru + semua tab (Beranda · Jelajah · Dompet · Profil)', (tester) async {
    final backend = FakeBackend({
      'GET /auth/me': (_) => userJson(),
      'GET /notifications': (_) => {'items': [], 'unread': 3},
      'GET /creator/stats': (_) => {'balance': 40000, 'total_earned': 90000, 'pending': 5000, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [campaignJson()], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /campaigns': (_) => [campaignJson(id: 'cmp_2', title: 'Kopi Susu Viral')],
      'GET /creator/submissions': (_) => [submissionJson(status: 'menunggu_views')],
      'GET /creator/withdrawals': (_) => [],
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(userJson())));

    // Beranda: header, streak, campaign horizontal, jelajahi, dompet, profil saya.
    expect(find.text('PAGI'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // badge lonceng
    expect(find.text('Streak Harian'), findsOneWidget);
    expect(find.byKey(const Key('home-campaign-cmp_1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('home-wallet-balance'))).data, 'Rp 40.000');
    await tester.scrollUntilVisible(find.byKey(const Key('home-content-tile')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('1 konten siap klaim views'), findsOneWidget);

    // "Konten saya" dari Beranda (tab Konten tidak ada lagi di desain baru).
    await tester.tap(find.byKey(const Key('home-content-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Siap diklaim'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tombol "Saldo" di kartu Dompet → tab Dompet.
    await tester.scrollUntilVisible(find.byKey(const Key('home-wallet-button')), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('home-wallet-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-balance')), findsOneWidget);
    // Saldo < Rp 50.000 → tombol tarik nonaktif.
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('open-withdraw-button'))).enabled, isFalse);

    await tester.tap(find.byKey(const Key('tab-Jelajah')));
    await tester.pumpAndSettle();
    expect(find.text('Kopi Susu Viral'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-Profil')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-Beranda')));
    await tester.pumpAndSettle();
    // Gulir Beranda kembali ke atas (posisi scroll tab dipertahankan IndexedStack).
    await tester.drag(find.byKey(const Key('home-wallet-card')), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Jelajah'), findsWidgets); // tombol cari → tab Jelajah
  });

  testWidgets('Brand: tanpa tab Review, beranda hanya data umum campaign', (tester) async {
    final brand = userJson(role: 'brand', brandBalance: 500000);
    final backend = FakeBackend({
      'GET /auth/me': (_) => brand,
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /brand/stats': (_) =>
          {'brand_balance': 500000, 'active': 1, 'spent': 250000, 'views': 5000, 'creators': 7, 'budget_left': 750000},
      'GET /brand/campaigns': (_) => [campaignJson()],
      'GET /brand/topups': (_) => [
            {'topup_id': 'TOP_9', 'amount': 100000, 'payment_type': 'qris', 'status': 'paid', 'created_at': ''},
          ],
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(brand)));

    expect(find.text('Review Skincare Glowing'), findsOneWidget);
    expect(find.text('Kreator terdaftar'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Sisa budget campaign'), findsOneWidget);
    expect(find.text('Rp 750.000'), findsOneWidget);
    expect(find.byKey(const Key('brand-review-by-admin-note')), findsOneWidget);
    // Brand tidak lagi punya menu review / approval kreator.
    expect(find.byKey(const Key('tab-Review')), findsNothing);
    expect(find.textContaining('perlu direview'), findsNothing);
    expect(backend.called('GET', '/brand/submissions'), isFalse);

    await tester.tap(find.byKey(const Key('tab-Saldo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('topup-TOP_9')), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
  });
}
