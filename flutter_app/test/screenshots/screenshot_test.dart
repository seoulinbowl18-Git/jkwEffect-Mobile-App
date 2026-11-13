// Pengaman desain baku jkwEffect: render semua halaman penting di 4 ukuran HP
// (kecil, sedang, besar, kecil + huruf 130%) dan GAGAL bila ada overflow /
// error layout. Selalu ikut `flutter test`.
//
// Untuk sekaligus menyimpan screenshot PNG + `layout_report.json`:
//   flutter test test/screenshots --dart-define=SCREENSHOT_DIR=build/screenshots
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/core/theme.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/providers/auth_provider.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/views/auth/login_view.dart';
import 'package:ourbuzzer/views/campaign/campaign_detail_view.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';
import 'package:ourbuzzer/views/brand/create_campaign_view.dart';
import 'package:ourbuzzer/views/brand/topup_view.dart';
import 'package:ourbuzzer/views/common/edit_profile_view.dart';
import 'package:ourbuzzer/views/common/settings_view.dart';
import 'package:ourbuzzer/views/common/faq_view.dart';
import 'package:ourbuzzer/views/creator/campaign_list_view.dart';
import 'package:ourbuzzer/views/creator/withdraw_view.dart';
import 'package:ourbuzzer/views/creator/content_view.dart';
import 'package:ourbuzzer/views/creator/claim_proof_view.dart';

import '../firebase_login_test.dart' show FakeGoogleFirebaseAuth;
import '../helpers.dart';

const outDir = String.fromEnvironment('SCREENSHOT_DIR');

class Device {
  const Device(this.name, this.width, this.height, {this.textScale = 1.0});
  final String name;
  final double width;
  final double height;
  final double textScale;
}

const devices = [
  Device('kecil_360x640', 360, 640),
  Device('sedang_393x852', 393, 852),
  Device('besar_430x932', 430, 932),
  Device('kecil_teks130', 360, 640, textScale: 1.3),
];

final report = <Map<String, Object?>>[];

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('$fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

// ------------------------------- data contoh -------------------------------
Map<String, dynamic> stressCampaign(String id, String title, {int rate = 12500, bool exclusive = false}) => {
      ...campaignJson(id: id, title: title, exclusive: exclusive, budget: 25000000, spent: 9375000),
      'brand_name': 'Glow Cosmetics Indonesia Official Store',
      'rate_per_1k': rate,
      'min_views': 10000,
      'instructions': '1. Buat video 15–60 detik yang menampilkan produk secara natural.\n'
          '2. Sebutkan nama brand di 3 detik pertama.\n'
          '3. Wajib pakai hashtag #jkwEffect dan tag akun brand.\n'
          '4. Dilarang konten SARA, kekerasan, atau beli views/bot.',
      'submission_count': 1284,
      'total_views': 4567890,
    };

/// Submission yang sudah diklaim dengan 3 bukti + catatan panjang (uji overflow).
final proofSubmission = {
  ...submissionJson(id: 'sub_p', status: 'diproses', claimed: 1234567, url: 'https://tiktok.com/@ani/video/77'),
  'campaign_title': 'Review Skincare Glowing Serum Vitamin C Terbaru 2026 untuk Kulit Kusam',
  'claim_note': 'Views per tanggal 12 Nov pukul 20.00, sudah termasuk tayangan dari FYP dan halaman profil.',
  'proofs': [
    for (final (i, k) in [(1, 'video'), (2, 'image'), (3, 'image')])
      {'proof_id': 'prf_$i', 'kind': k, 'content_type': k == 'video' ? 'video/mp4' : 'image/png', 'size': 1000, 'url': '/api/proofs/prf_$i?exp=1&sig=x'},
  ],
};

final claimTarget = Submission.fromJson({
  ...submissionJson(id: 'sub_k', status: 'menunggu_views'),
  'campaign_title': 'Review Skincare Glowing Serum Vitamin C Terbaru 2026 untuk Kulit Kusam',
  'min_views': 10000,
  'rate_per_1k': 150000,
});

final campaigns = [
  stressCampaign('cmp_1', 'Review Skincare Glowing Serum Vitamin C Terbaru 2026 untuk Kulit Kusam'),
  stressCampaign('cmp_2', 'Unboxing Smartphone Murah Spek Dewa', rate: 150000),
  stressCampaign('cmp_3', 'Kopi Susu Viral', exclusive: true),
];

Map<String, Handler> routes({required Map<String, dynamic> me}) => {
      'GET /auth/me': (_) => me,
      'GET /notifications': (_) => {'items': [], 'unread': 12},
      'GET /creator/stats': (_) => {
            'balance': 12345678,
            'total_earned': 98765432,
            'pending': 250000,
            'videos': 37,
            'campaigns': 12,
            'streak': {
              'streak': 6,
              'posted_today': true,
              'week': [
                for (final l in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Hari ini'])
                  {'date': '2026-11-0$l', 'label': l, 'posted': l != 'Sel'},
              ],
            },
          },
      'GET /campaigns/sections': (_) => {
            'trending': campaigns,
            'top_rate': campaigns.reversed.toList(),
            'newest': campaigns,
            'closing': campaigns,
            'total': 3,
            'total_exclusive': 1,
          },
      'GET /campaigns': (_) => campaigns,
      'GET /campaigns/cmp_1': (_) => campaigns.first,
      'GET /brand/stats': (_) => {
            'brand_balance': 123456789,
            'active': 3,
            'spent': 98765432,
            'views': 12345678,
            'creators': 1284,
            'budget_left': 15625000,
          },
      'GET /brand/campaigns': (_) => campaigns,
      'GET /creator/submissions': (_) => [
            submissionJson(id: 'sub_1', status: 'menunggu_views'),
            proofSubmission,
            submissionJson(id: 'sub_2', status: 'disetujui', url: 'https://tiktok.com/@ani/video/2'),
          ],
      'GET /creator/withdrawals': (_) => [
            {
              'withdrawal_id': 'wd_1',
              'amount': 1250000,
              'method': 'ShopeePay',
              'account_number': '081234567890',
              'account_holder': 'Ani Kreator Nusantara Sejahtera',
              'status': 'diproses',
              'reference': '',
              'created_at': '2026-11-01T10:00:00Z',
            },
            {
              'withdrawal_id': 'wd_2',
              'amount': 500000,
              'method': 'BCA',
              'account_number': '1234567890',
              'account_holder': 'Ani',
              'status': 'disetujui',
              'reference': 'TRF-001',
              'created_at': '2026-10-20T10:00:00Z',
            },
            {
              'withdrawal_id': 'wd_3',
              'amount': 75000,
              'method': 'DANA',
              'account_number': '081234567',
              'account_holder': 'Ani',
              'status': 'ditolak',
              'reference': '',
              'created_at': '2026-10-02T10:00:00Z',
            },
          ],
      'GET /brand/topups': (_) => [],
      'GET /payments/config': (_) => {'komerce_configured': true, 'sandbox': true},
      'GET /users/social': (_) => {
            'tiktok': {'username': 'ani.kreator.nusantara', 'url': 'https://www.tiktok.com/@ani.kreator.nusantara'},
            'instagram': {'username': 'ani.kreator', 'url': 'https://www.instagram.com/ani.kreator'},
            'threads': null,
            'telegram': null,
          },
      'GET /public/community': (_) =>
          {'telegram_url': 'https://t.me/+OurBuzzer', 'telegram_bot': 'OurBuzzerBot', 'telegram_connect_enabled': true},
    };

final creator = {
  ...userJson(balance: 12345678),
  'name': 'Ani Kreator Nusantara Sejahtera',
  'email': 'ani.kreator.nusantara@gmail.com',
};
final brand = {
  ...userJson(role: 'brand', brandBalance: 123456789),
  'user_id': 'brand_1',
  'profile': {'brand_name': 'Glow Cosmetics Indonesia Official Store'},
};

// ------------------------------- harness -------------------------------
Future<void> shoot(
  WidgetTester tester, {
  required String screen,
  required Device d,
  required Map<String, dynamic>? me,
  required Widget Function() page,
  Future<void> Function(WidgetTester)? before,
}) async {
  final errors = <String>[];
  final original = FlutterError.onError;
  // Selalu dipulihkan, walau test gagal di tengah jalan (kalau tidak, test berikutnya macet).
  addTearDown(() => FlutterError.onError = original);
  FlutterError.onError = (details) {
    final m = details.exceptionAsString().split('\n').first;
    final where = details.informationCollector
            ?.call()
            .map((e) => e.toString())
            .firstWhere((s) => s.contains('lib/'), orElse: () => '') ??
        '';
    final loc = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(where)?.group(0) ?? '';
    errors.add(loc.isEmpty ? m : '$m  @ $loc');
  };

  // Mode sentuh seperti di HP (tanpa cincin fokus keyboard ala desktop).
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(d.width, d.height);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = d.textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final backend = FakeBackend(routes(me: me ?? {}));
  final key = GlobalKey();
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      apiServiceProvider.overrideWithValue(backend.api()),
      tokenStorageProvider.overrideWithValue(MemoryTokenStorage(me == null ? null : 'tok')),
      firebaseGoogleAuthProvider.overrideWithValue(FakeGoogleFirebaseAuth()),
    ],
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Font eksplisit hanya untuk screenshot: lingkungan test tidak punya font sistem.
        theme: AppTheme.light(fontFamily: 'Roboto'),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Consumer(builder: (context, ref, _) {
          final auth = ref.watch(authProvider);
          if (me != null && auth.value == null) return const SizedBox.shrink();
          return page();
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  if (before != null) await before(tester);
  await tester.pump(const Duration(seconds: 1));

  final file = '$outDir/${screen}__${d.name}.png';
  if (outDir.isNotEmpty) {
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  FlutterError.onError = original;
  final unique = errors.toSet().toList();
  report.add({'screen': screen, 'device': d.name, 'file': file, 'errors': unique});
  expect(unique, isEmpty, reason: 'Layout "$screen" di ${d.name} bermasalah (overflow?)');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
    if (outDir.isNotEmpty) Directory(outDir).createSync(recursive: true);
  });
  tearDownAll(() {
    if (outDir.isEmpty) return;
    File('$outDir/layout_report.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  });

  Future<void> openTab(WidgetTester t, String tab) async {
    await t.tap(find.byKey(Key('tab-$tab')));
    await t.pumpAndSettle();
  }

  for (final d in devices) {
    // ---- 6 halaman utama (lembar screenshot acuan) ----
    testWidgets('login ${d.name}', (t) => shoot(t, screen: '1_login', d: d, me: null, page: () => const LoginView()));

    testWidgets('beranda kreator ${d.name}', (t) => shoot(t,
        screen: '2_kreator_beranda', d: d, me: creator, page: () => HomeShell(user: User.fromJson(creator))));

    testWidgets('detail kreator ${d.name}', (t) => shoot(t,
        screen: '3_detail_campaign_kreator', d: d, me: creator,
        page: () => const CampaignDetailView(campaignId: 'cmp_1')));

    testWidgets('detail brand ${d.name}', (t) => shoot(t,
        screen: '4_detail_campaign_brand', d: d, me: brand, page: () => const CampaignDetailView(campaignId: 'cmp_1'),
        before: (t) async {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
          await t.pumpAndSettle();
        }));

    testWidgets('beranda brand ${d.name}', (t) => shoot(t,
        screen: '5_brand_beranda', d: d, me: brand, page: () => HomeShell(user: User.fromJson(brand))));

    testWidgets('profil ${d.name}', (t) => shoot(t,
        screen: '6_profil_kreator', d: d, me: creator, page: () => HomeShell(user: User.fromJson(creator)),
        before: (t) => openTab(t, 'Profil')));

    // ---- halaman lain: dicek overflow juga (screenshot berawalan x_) ----
    final extra = <String, (Map<String, dynamic>?, Widget Function(), Future<void> Function(WidgetTester)?)>{
      'x_beranda_bawah': (creator, () => HomeShell(user: User.fromJson(creator)), (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await t.pumpAndSettle();
      }),
      'x_jelajah': (creator, () => HomeShell(user: User.fromJson(creator)), (t) => openTab(t, 'Jelajah')),
      'x_konten': (creator, () => const ContentView(), null),
      'x_klaim': (creator, () => ClaimProofView(submission: claimTarget), null),
      'x_klaim_bawah': (creator, () => ClaimProofView(submission: claimTarget), (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await t.pumpAndSettle();
      }),
      'x_dompet': (creator, () => HomeShell(user: User.fromJson(creator)), (t) => openTab(t, 'Dompet')),
      'x_tarik_saldo': (creator, () => const WithdrawView(balance: 12345678), null),
      'x_tarik_saldo_rincian': (creator, () => const WithdrawView(balance: 12345678), (t) async {
        await t.enterText(find.byKey(const Key('withdraw-amount-input')), '12345678');
        await t.pumpAndSettle();
      }),
      'x_brand_tarik_saldo': (brand, () => const WithdrawView(balance: 123456789, forBrand: true), (t) async {
        await t.enterText(find.byKey(const Key('withdraw-amount-input')), '123456789');
        await t.pumpAndSettle();
      }),
      'x_lihat_semua': (creator, () => const CampaignListView(title: 'Rate tertinggi', sort: CampaignSort.rate), null),
      'x_faq': (creator, () => const FaqView(), null),
      'x_pengaturan': (creator, () => const SettingsView(), null),
      'x_edit_profil': (creator, () => const EditProfileView(), null),
      'x_brand_saldo': (brand, () => HomeShell(user: User.fromJson(brand)), (t) => openTab(t, 'Saldo')),
      'x_brand_profil': (brand, () => HomeShell(user: User.fromJson(brand)), (t) => openTab(t, 'Profil')),
      'x_brand_topup': (brand, () => const TopupView(), null),
      'x_brand_buat_campaign': (brand, () => const CreateCampaignView(), null),
      // Halaman login mode "Saya Brand".
      'x_login_brand': (
        null,
        () => const LoginView(),
        (t) async {
          await t.tap(find.byKey(const Key('login-mode-brand')));
          await t.pumpAndSettle();
        },
      ),
    };
    for (final MapEntry(key: name, value: (me, page, before)) in extra.entries) {
      testWidgets('$name ${d.name}', (t) => shoot(t, screen: name, d: d, me: me, page: page, before: before));
    }
  }
}
