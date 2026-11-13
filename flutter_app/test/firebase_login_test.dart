import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/app.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/firebase_google_auth_service.dart';

import 'helpers.dart';

/// Pengganti Firebase + Google Sign-In untuk test.
class FakeGoogleFirebaseAuth implements GoogleFirebaseAuth {
  FakeGoogleFirebaseAuth({this.token, this.error});
  final String? token;
  final Object? error;
  int signIns = 0;
  int signOuts = 0;

  @override
  Future<String?> signInAndGetIdToken() async {
    signIns++;
    if (error != null) throw error!;
    return token;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

Future<void> pumpLogin(WidgetTester tester, FakeBackend backend, FakeGoogleFirebaseAuth google,
    MemoryTokenStorage storage) async {
  tester.view
    ..devicePixelRatio = 2.5
    ..physicalSize = const Size(1030, 2500);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      apiServiceProvider.overrideWithValue(backend.api()),
      tokenStorageProvider.overrideWithValue(storage),
      firebaseGoogleAuthProvider.overrideWithValue(google),
    ],
    child: const OurBuzzerApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Masuk dengan Google → Firebase ID token dikirim ke /auth/firebase → onboarding', (tester) async {
    final storage = MemoryTokenStorage();
    final google = FakeGoogleFirebaseAuth(token: 'firebase-id-token-abc');
    final backend = FakeBackend({
      'POST /auth/firebase': (req) {
        expect(jsonDecode(req.body), {'id_token': 'firebase-id-token-abc'});
        return {...userJson(), 'role': null, 'session_token': 'sess_1'};
      },
    });
    await pumpLogin(tester, backend, google, storage);

    await tester.tap(find.byKey(const Key('login-google-button')));
    await tester.pumpAndSettle();

    expect(google.signIns, 1);
    expect(find.text('Halo, Ani!'), findsOneWidget); // onboarding pilih peran
    expect(storage.value, 'sess_1'); // sesi backend tersimpan
  });

  testWidgets('pemilihan akun dibatalkan → tetap di login, backend tidak dipanggil', (tester) async {
    final google = FakeGoogleFirebaseAuth(token: null);
    final backend = FakeBackend({});
    await pumpLogin(tester, backend, google, MemoryTokenStorage());

    await tester.tap(find.byKey(const Key('login-google-button')));
    await tester.pumpAndSettle();

    expect(backend.called('POST', '/auth/firebase'), isFalse);
    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
  });

  testWidgets('backend menolak token → pesan tampil & Firebase di-sign-out', (tester) async {
    final google = FakeGoogleFirebaseAuth(token: 'firebase-id-token-abc');
    final backend = FakeBackend({
      'POST /auth/firebase': (_) => jsonResponse({'detail': 'Token login tidak valid'}, 401),
    });
    final storage = MemoryTokenStorage();
    await pumpLogin(tester, backend, google, storage);

    await tester.tap(find.byKey(const Key('login-google-button')));
    await tester.pumpAndSettle();

    expect(find.text('Token login tidak valid'), findsOneWidget);
    expect(google.signOuts, 1);
    expect(storage.value, isNull);
  });

  testWidgets('error konfigurasi Google (SHA-1) → pesan jelas', (tester) async {
    final google = FakeGoogleFirebaseAuth(
      error: const AuthFlowException('Login Google belum dikonfigurasi untuk aplikasi ini (periksa SHA-1 di Firebase Console).'),
    );
    await pumpLogin(tester, FakeBackend({}), google, MemoryTokenStorage());

    await tester.tap(find.byKey(const Key('login-google-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('periksa SHA-1'), findsOneWidget);
  });

  testWidgets('logout → sesi backend dihapus & keluar dari Firebase', (tester) async {
    final google = FakeGoogleFirebaseAuth();
    final storage = MemoryTokenStorage('sess_1');
    final backend = FakeBackend({
      'GET /auth/me': (_) => userJson(role: 'creator'),
      'POST /auth/logout': (_) => {'ok': true},
      'GET /creator/stats': (_) => {'balance': 0, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /campaigns': (_) => [],
      'GET /notifications': (_) => {'items': [], 'unread': 0},
    });
    await pumpLogin(tester, backend, google, storage);

    await tester.tap(find.byKey(const Key('tab-Profil')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();

    expect(backend.called('POST', '/auth/logout'), isTrue);
    expect(google.signOuts, 1);
    expect(storage.value, isNull);
    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
  });
}
