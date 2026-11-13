import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/app.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/api_service.dart';
import 'package:ourbuzzer/services/token_storage.dart';

/// Penyimpanan token di memori untuk test.
class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> save(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

Map<String, dynamic> _user({String? role}) => {
      'user_id': 'user_1',
      'email': 'ani@example.com',
      'name': 'Ani Kreator',
      'role': role,
      'balance': 125000,
      'total_earned': 300000,
      'brand_balance': 0,
      'profile': <String, String>{},
    };

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Widget _app(ApiService api, TokenStorage storage) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
      ],
      child: const OurBuzzerApp(),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('tanpa token → halaman login', (tester) async {
    final api = ApiService(baseUrl: 'https://x/api', client: MockClient((_) async => _json({})));
    await tester.pumpWidget(_app(api, _MemoryTokenStorage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
    expect(find.byKey(const Key('login-email-button')), findsOneWidget);
  });

  testWidgets('token valid tanpa peran → onboarding → pilih Kreator → home', (tester) async {
    final storage = _MemoryTokenStorage('tok_1');
    final api = ApiService(
      baseUrl: 'https://x/api',
      client: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok_1');
        switch (req.url.path) {
          case '/api/auth/me':
            return _json(_user());
          case '/api/users/role':
            expect(jsonDecode(req.body), {'role': 'creator'});
            return _json(_user(role: 'creator'));
          case '/api/creator/stats':
            return _json({
              'balance': 125000,
              'total_earned': 300000,
              'pending': 0,
              'videos': 3,
              'campaigns': 2,
              'streak': {'streak': 4, 'posted_today': true, 'week': []},
            });
          case '/api/notifications':
            return _json({'items': [], 'unread': 2});
        }
        return _json({'detail': 'Not Found'}, 404);
      }),
    );

    await tester.pumpWidget(_app(api, storage));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Ani!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Cari Cuan'), findsWidgets);
    expect(find.text('4 hari streak'), findsOneWidget);
    expect(find.text('Rp 125.000'), findsOneWidget);
  });

  testWidgets('token kadaluarsa (401) → dihapus & kembali ke login', (tester) async {
    final storage = _MemoryTokenStorage('expired');
    final api = ApiService(
      baseUrl: 'https://x/api',
      client: MockClient((_) async => _json({'detail': 'Sesi kadaluarsa'}, 401)),
    );
    await tester.pumpWidget(_app(api, storage));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
    expect(storage.value, isNull);
  });

  testWidgets('login email gagal → pesan backend ditampilkan', (tester) async {
    final api = ApiService(
      baseUrl: 'https://x/api',
      client: MockClient((_) async => _json({'detail': 'Email atau password salah'}, 401)),
    );
    await tester.pumpWidget(_app(api, _MemoryTokenStorage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email-input')), 'ani@example.com');
    await tester.enterText(find.byKey(const Key('login-password-input')), 'rahasia123');
    await tester.ensureVisible(find.byKey(const Key('login-email-button')));
    await tester.tap(find.byKey(const Key('login-email-button')));
    await tester.pumpAndSettle();

    expect(find.text('Email atau password salah'), findsOneWidget);
    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
  });

  testWidgets('daftar email sukses → onboarding', (tester) async {
    final storage = _MemoryTokenStorage();
    final api = ApiService(
      baseUrl: 'https://x/api',
      client: MockClient((req) async {
        if (req.url.path == '/api/auth/register') {
          expect(jsonDecode(req.body), {'name': 'Ani Kreator', 'email': 'ani@example.com', 'password': 'rahasia123'});
          return _json({..._user(), 'session_token': 'tok_new'});
        }
        return _json({'detail': 'Not Found'}, 404);
      }),
    );
    await tester.pumpWidget(_app(api, storage));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Belum punya akun? Daftar'));
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-name-input')), 'Ani Kreator');
    await tester.enterText(find.byKey(const Key('login-email-input')), 'Ani@Example.com');
    await tester.enterText(find.byKey(const Key('login-password-input')), 'rahasia123');
    await tester.ensureVisible(find.byKey(const Key('login-email-button')));
    await tester.tap(find.byKey(const Key('login-email-button')));
    await tester.pumpAndSettle();

    expect(find.text('Halo, Ani!'), findsOneWidget);
    expect(storage.value, 'tok_new');
  });
}
