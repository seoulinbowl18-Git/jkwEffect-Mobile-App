import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers.dart';

class _FakeLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final launched = <String>[];
  LaunchOptions? lastOptions;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    lastOptions = options;
    return true;
  }
}

Map<String, dynamic> _social({Map<String, dynamic>? tiktok, Map<String, dynamic>? telegram}) =>
    {'tiktok': tiktok, 'instagram': null, 'threads': null, 'telegram': telegram};

FakeBackend _backend(Map<String, Object? Function(dynamic)> extra) => FakeBackend({
      'GET /auth/me': (_) => userJson(),
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /creator/stats': (_) => {'balance': 125000, 'total_earned': 300000, 'pending': 0, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /creator/submissions': (_) => [],
      'GET /creator/withdrawals': (_) => [],
      'GET /public/community': (_) =>
          {'telegram_url': 'https://t.me/+OurBuzzerGroup', 'telegram_bot': 'OurBuzzerBot', 'telegram_connect_enabled': true},
      for (final e in extra.entries) e.key: (req) => e.value(req),
    });

Future<void> _openProfile(WidgetTester tester, FakeBackend backend) async {
  await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(userJson())));
  await tester.tap(find.byKey(const Key('tab-Profil')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('social-accounts-card')), 200,
      scrollable: find.byType(Scrollable).first);
}

/// Gulir sampai [f] berada di tengah layar (tidak tertutup header / navigasi bawah).
Future<void> _reveal(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Akun Sosial Media: tambah TikTok, tampil @username, lalu putuskan', (tester) async {
    Map<String, dynamic>? tiktok;
    final backend = _backend({
      'GET /users/social': (_) => _social(tiktok: tiktok),
      'PUT /users/social/tiktok': (req) {
        expect(jsonDecode((req as dynamic).body), {'handle': 'https://www.tiktok.com/@ani.kreator'});
        tiktok = {'username': 'ani.kreator', 'url': 'https://www.tiktok.com/@ani.kreator'};
        return _social(tiktok: tiktok);
      },
      'DELETE /users/social/tiktok': (_) {
        tiktok = null;
        return _social();
      },
    });
    await _openProfile(tester, backend);

    for (final label in ['TikTok', 'Instagram', 'Threads', 'Telegram']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Belum terhubung'), findsNWidgets(3));

    await _reveal(tester, find.byKey(const Key('social-tiktok-add')));
    await tester.tap(find.byKey(const Key('social-tiktok-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('social-tiktok-input')), 'https://www.tiktok.com/@ani.kreator');
    await tester.tap(find.byKey(const Key('social-tiktok-save')));
    await tester.pumpAndSettle();
    expect(find.text('@ani.kreator'), findsOneWidget);
    expect(find.byKey(const Key('social-tiktok-edit')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // snackbar hilang
    await tester.pumpAndSettle();

    await _reveal(tester, find.byKey(const Key('social-tiktok-unlink')));
    await tester.tap(find.byKey(const Key('social-tiktok-unlink')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Putuskan'));
    await tester.pumpAndSettle();
    expect(backend.called('DELETE', '/users/social/tiktok'), isTrue);
    expect(find.text('@ani.kreator'), findsNothing);
  });

  testWidgets('Hubungkan Telegram: buka bot di aplikasi Telegram, status ter-update saat kembali', (tester) async {
    final launcher = _FakeLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);

    Map<String, dynamic>? telegram;
    final backend = _backend({
      'GET /users/social': (_) => _social(telegram: telegram),
      'POST /users/social/telegram/link': (_) => {'url': 'https://t.me/OurBuzzerBot?start=abc123', 'expires_in': 900},
    });
    await _openProfile(tester, backend);

    await _reveal(tester, find.byKey(const Key('social-telegram-connect')));
    expect(find.text('Hubungkan Telegram'), findsOneWidget);
    await tester.tap(find.byKey(const Key('social-telegram-connect')));
    await tester.pumpAndSettle();
    expect(launcher.launched.single, 'https://t.me/OurBuzzerBot?start=abc123');
    expect(launcher.lastOptions?.mode, PreferredLaunchMode.externalApplication); // aplikasi Telegram

    // Pengguna menekan START di bot (backend mencatat akunnya), lalu kembali ke aplikasi.
    telegram = {'username': 'ani_tg', 'name': 'Ani', 'linked_at': '2026-11-12T07:40:00Z'};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Terhubung · @ani_tg'), findsOneWidget);
    expect(find.text('Buka grup komunitas'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // timer refresh kedua & snackbar
    await tester.pumpAndSettle();

    await _reveal(tester, find.byKey(const Key('social-telegram-group')));
    await tester.tap(find.byKey(const Key('social-telegram-group')));
    await tester.pumpAndSettle();
    expect(launcher.launched.last, 'https://t.me/+OurBuzzerGroup');
  });

  testWidgets('Telegram belum dikonfigurasi → tombol nonaktif "segera hadir"', (tester) async {
    final backend = _backend({'GET /users/social': (_) => _social()});
    backend.routes['GET /public/community'] = (_) => {'telegram_url': '', 'telegram_bot': '', 'telegram_connect_enabled': false};
    await _openProfile(tester, backend);
    await _reveal(tester, find.byKey(const Key('social-telegram-connect')));
    expect(find.text('Hubungkan Telegram (segera hadir)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('social-telegram-connect'))).onPressed, isNull);
  });
}
