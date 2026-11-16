import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourbuzzer/core/config.dart';
import 'package:ourbuzzer/core/theme.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/views/auth/login_view.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers.dart';

class _FakeLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final launched = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

Future<_FakeLauncher> _pumpLogin(WidgetTester tester) async {
  final launcher = _FakeLauncher();
  final original = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = original);
  tester.view
    ..devicePixelRatio = 2.5
    ..physicalSize = const Size(1030, 2300);
  addTearDown(tester.view.reset);
  final backend = FakeBackend({
    'GET /public/community': (_) =>
        {'telegram_url': 'https://t.me/+OurBuzzerGroup', 'telegram_bot': 'OurBuzzerBot', 'telegram_connect_enabled': true},
  });
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [apiServiceProvider.overrideWithValue(backend.api())],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const LoginView(),
    ),
  ));
  await tester.pumpAndSettle();
  return launcher;
}

void main() {
  test('Link WhatsApp admin: nomor dinormalisasi + pesan otomatis', () {
    final uri = AppConfig.whatsappUriFor('0812-3456 7890')!;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/6281234567890');
    expect(uri.queryParameters['text'], startsWith('Halo Admin GIBRAN2029, saya dari brand'));
    expect(AppConfig.whatsappUriFor('+62 812 3456 7890')!.path, '/6281234567890');
    expect(AppConfig.whatsappUriFor(''), isNull);
  });

  testWidgets('Mode Saya Relawan (default): Gabung Komunitas → grup Telegram', (tester) async {
    final launcher = await _pumpLogin(tester);
    expect(find.text('Satukan Barisan,\nKawal Masa Depan.'), findsOneWidget);
    expect(find.text('Saya Relawan'), findsOneWidget);
    expect(find.text('Saya Member'), findsOneWidget);
    expect(find.text('Saya Kreator'), findsNothing);
    expect(find.text('Saya Brand'), findsNothing);
    expect(find.text('Ikut aksi sosial & kegiatan wilayah'), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-community-button')));
    await tester.pumpAndSettle();
    expect(launcher.launched.single, 'https://t.me/+OurBuzzerGroup');
  });

  testWidgets('Mode Saya Member: teks & manfaat member, lalu kembali ke Saya Relawan', (tester) async {
    await _pumpLogin(tester);
    await tester.tap(find.byKey(const Key('login-mode-member')));
    await tester.pumpAndSettle();

    expect(find.text('Jadi Member Resmi\nGIBRAN2029.'), findsOneWidget);
    expect(find.text('KTA digital resmi bernomor unik'), findsOneWidget);
    expect(find.byKey(const Key('login-community-button')), findsOneWidget);
    expect(find.text('Hubungi Kami'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('login-mode-relawan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-mode-relawan')));
    await tester.pumpAndSettle();
    expect(find.text('Satukan Barisan,\nKawal Masa Depan.'), findsOneWidget);
  });
}
