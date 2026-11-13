import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Versi /sync berubah → saldo & data dimuat ulang otomatis', (tester) async {
    var version = 5;
    var balance = 40000;
    final backend = FakeBackend({
      'GET /sync': (_) => {'v': version},
      'GET /auth/me': (_) => userJson(balance: balance),
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /creator/stats': (_) => {'balance': balance, 'total_earned': 0, 'pending': 0, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /creator/submissions': (_) => [],
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(userJson(balance: balance))));
    expect(tester.widget<Text>(find.byKey(const Key('home-wallet-balance'))).data, 'Rp 40.000');

    // Owner menambah saldo dari web → versi naik.
    balance = 90000;
    version = 6;
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('home-wallet-balance'))).data, 'Rp 90.000');
  });

  testWidgets('Versi tidak berubah → tidak ada request ulang', (tester) async {
    final backend = FakeBackend({
      'GET /sync': (_) => {'v': 1},
      'GET /auth/me': (_) => userJson(),
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /creator/stats': (_) => {'balance': 0, 'total_earned': 0, 'pending': 0, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /creator/submissions': (_) => [],
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(userJson())));
    final statsCalls = backend.calls.where((r) => r.url.path == '/api/creator/stats').length;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(backend.calls.where((r) => r.url.path == '/api/creator/stats').length, statsCalls);
    expect(backend.calls.where((r) => r.url.path == '/api/sync').length, greaterThanOrEqualTo(3));
  });
}
