import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Kreator: semua tab bisa dibuka', (tester) async {
    final backend = FakeBackend({
      'GET /auth/me': (_) => userJson(),
      'GET /notifications': (_) => {'items': [], 'unread': 3},
      'GET /creator/stats': (_) => {'balance': 40000, 'total_earned': 90000, 'pending': 5000, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /campaigns': (_) => [campaignJson()],
      'GET /creator/submissions': (_) => [submissionJson(status: 'disetujui')],
      'GET /creator/withdrawals': (_) => [],
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(userJson())));

    expect(find.text('Review Skincare Glowing'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // badge lonceng

    await tester.tap(find.byKey(const Key('tab-Konten')));
    await tester.pumpAndSettle();
    expect(find.text('Selesai'), findsWidgets);

    await tester.tap(find.byKey(const Key('tab-Dompet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-balance')), findsOneWidget);
    // Saldo < Rp 50.000 → tombol tarik nonaktif.
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('open-withdraw-button'))).enabled, isFalse);

    await tester.tap(find.byKey(const Key('tab-Profil')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
  });

  testWidgets('Brand: semua tab bisa dibuka', (tester) async {
    final brand = userJson(role: 'brand', brandBalance: 500000);
    final backend = FakeBackend({
      'GET /auth/me': (_) => brand,
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /brand/stats': (_) =>
          {'brand_balance': 500000, 'active': 1, 'spent': 250000, 'views': 5000, 'pending_reviews': 2},
      'GET /brand/campaigns': (_) => [campaignJson()],
      'GET /brand/submissions': (_) => [submissionJson()],
      'GET /brand/topups': (_) => [
            {'topup_id': 'TOP_9', 'amount': 100000, 'payment_type': 'qris', 'status': 'paid', 'created_at': ''},
          ],
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(brand)));

    expect(find.text('2 submission perlu direview'), findsOneWidget);
    expect(find.text('Review Skincare Glowing'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-Review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('approve-content-sub_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-Saldo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('topup-TOP_9')), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
  });
}
