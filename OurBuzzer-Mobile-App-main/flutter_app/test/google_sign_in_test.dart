import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/app.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/google_auth_service.dart';

import 'helpers.dart';

/// Google Sign-In palsu: mengembalikan ID token, null (batal), atau melempar error.
class _FakeGoogle implements GoogleAuthService {
  _FakeGoogle(this._result);
  final Future<String?> Function() _result;
  int calls = 0;

  @override
  Future<String?> signIn() {
    calls++;
    return _result();
  }
}

Widget _app(FakeBackend backend, MemoryTokenStorage storage, GoogleAuthService google) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        apiServiceProvider.overrideWithValue(backend.api()),
        tokenStorageProvider.overrideWithValue(storage),
        googleAuthServiceProvider.overrideWithValue(google),
      ],
      child: const OurBuzzerApp(),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  final googleButton = find.byKey(const Key('login-google-button'));

  testWidgets('login Google: ID token Firebase ditukar di /auth/firebase lalu sesi disimpan',
      (tester) async {
    final backend = FakeBackend({
      'POST /auth/firebase': (_) => {...userJson(), 'role': null, 'session_token': 'sess_google'},
    });
    final storage = MemoryTokenStorage();
    final google = _FakeGoogle(() async => 'fb_id_token');

    await tester.pumpWidget(_app(backend, storage, google));
    await tester.pumpAndSettle();
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(google.calls, 1);
    expect(backend.lastBody('POST', '/auth/firebase'), {'id_token': 'fb_id_token'});
    expect(storage.value, 'sess_google');
    expect(googleButton, findsNothing); // keluar dari halaman login
  });

  testWidgets('login Google dibatalkan: tidak ada request ke backend', (tester) async {
    final backend = FakeBackend({});
    final storage = MemoryTokenStorage();

    await tester.pumpWidget(_app(backend, storage, _FakeGoogle(() async => null)));
    await tester.pumpAndSettle();
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(backend.called('POST', '/auth/firebase'), isFalse);
    expect(storage.value, isNull);
    expect(googleButton, findsOneWidget);
  });

  testWidgets('error login Google ditampilkan ke user', (tester) async {
    final backend = FakeBackend({});
    final google = _FakeGoogle(
        () async => throw GoogleSignInException(GoogleAuthService.messageFor('popup-blocked')));

    await tester.pumpWidget(_app(backend, MemoryTokenStorage(), google));
    await tester.pumpAndSettle();
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Popup login diblokir'), findsOneWidget);
    expect(backend.called('POST', '/auth/firebase'), isFalse);
  });
}
