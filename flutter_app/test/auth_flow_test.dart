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

    // Google Sign-In satu-satunya cara masuk: tidak ada form email / password / daftar.
    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
    expect(find.byKey(const Key('login-email-input')), findsNothing);
    expect(find.byKey(const Key('login-password-input')), findsNothing);
    expect(find.byKey(const Key('login-email-button')), findsNothing);
    expect(find.text('atau dengan email'), findsNothing);
    expect(find.text('Belum punya akun? Daftar'), findsNothing);
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

    // Beranda kreator: header, streak harian, dan kartu Dompet Kamu.
    expect(find.text('Streak Harian'), findsOneWidget);
    expect(find.textContaining('4 hari berturut-turut'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('home-wallet-balance')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<Text>(find.byKey(const Key('home-wallet-balance'))).data, 'Rp 125.000');
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

  testWidgets('Admin Pusat: nomor WhatsApp → OTP → masuk sebagai admin', (tester) async {
    final storage = _MemoryTokenStorage();
    final bodies = <String, dynamic>{};
    final api = ApiService(
      baseUrl: 'https://x/api',
      client: MockClient((req) async {
        switch (req.url.path) {
          case '/api/admin/request-otp':
            bodies['request'] = jsonDecode(req.body);
            return _json({'ok': true, 'phone': '6281•••••890', 'expires_in': 300, 'resend_in': 60});
          case '/api/admin/verify-otp':
            bodies['verify'] = jsonDecode(req.body);
            return _json({..._user(role: 'admin'), 'session_token': 'tok_admin'});
          case '/api/admin/stats':
            return _json({'pending_withdrawals': 0, 'pending_submissions': 0, 'users': 3, 'campaigns': 1});
          case '/api/notifications':
            return _json({'items': [], 'unread': 0});
        }
        return _json({'detail': 'Not Found'}, 404);
      }),
    );
    await tester.pumpWidget(_app(api, storage));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('login-admin-link')));
    await tester.tap(find.byKey(const Key('login-admin-link')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('admin-phone-input')), '081234567890');
    await tester.tap(find.byKey(const Key('admin-send-otp-button')));
    await tester.pumpAndSettle();
    expect(bodies['request'], {'phone': '081234567890'});
    expect(find.textContaining('6281•••••890'), findsOneWidget);
    expect(find.text('Kirim ulang kode dalam 60 detik'), findsOneWidget);

    // 6 digit → verifikasi otomatis → sesi admin tersimpan → dashboard admin.
    await tester.enterText(find.byKey(const Key('admin-otp-input')), '123456');
    await tester.pumpAndSettle();
    expect(bodies['verify'], {'phone': '081234567890', 'code': '123456'});
    expect(storage.value, 'tok_admin');
    expect(find.byKey(const Key('admin-phone-input')), findsNothing);
    expect(find.text('GIBRAN2029 Admin'), findsOneWidget);
  });
}
