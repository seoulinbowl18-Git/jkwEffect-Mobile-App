import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/views/creator/cari_cuan_view.dart';
import 'package:ourbuzzer/views/creator/content_view.dart';
import 'package:ourbuzzer/views/creator/submit_video_view.dart';
import 'package:ourbuzzer/views/creator/withdraw_view.dart';

import 'helpers.dart';

Map<String, Handler> _creatorBase({List<Map<String, dynamic>> subs = const []}) => {
      'GET /auth/me': (_) => userJson(),
      'GET /creator/submissions': (_) => subs,
      'GET /notifications': (_) => {'items': [], 'unread': 0},
    };

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Cari Cuan: section banner, list, pencarian & kategori dikirim ke API', (tester) async {
    final backend = FakeBackend({
      ..._creatorBase(),
      'GET /creator/stats': (_) => {
            'balance': 125000,
            'total_earned': 0,
            'pending': 0,
            'videos': 0,
            'campaigns': 0,
            'streak': {'streak': 2, 'posted_today': false, 'week': []},
          },
      'GET /campaigns/sections': (_) => {
            'trending': [campaignJson(id: 'cmp_t', title: 'Campaign Trending')],
            'top_rate': [],
            'newest': [],
            'closing': [],
            'total': 1,
            'total_exclusive': 0,
          },
      'GET /campaigns': (req) => [
            campaignJson(title: req.url.queryParameters['q'] == 'kopi' ? 'Kopi Susu Viral' : 'Review Skincare Glowing'),
          ],
    });
    await pumpWithSession(tester, backend, const CariCuanView());

    expect(find.text('🔥 Lagi rame'), findsOneWidget);
    expect(find.text('Campaign Trending'), findsOneWidget);
    expect(find.text('2 hari streak'), findsOneWidget);
    expect(find.text('Rp 125.000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campaign-search-input')), 'kopi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(backend.last('GET', '/campaigns').url.queryParameters['q'], 'kopi');
    expect(find.text('Kopi Susu Viral'), findsOneWidget);
    expect(find.text('🔥 Lagi rame'), findsNothing); // section disembunyikan saat mencari

    await tester.tap(find.byKey(const Key('category-Beauty')));
    await tester.pumpAndSettle();
    expect(backend.last('GET', '/campaigns').url.queryParameters['category'], 'Beauty');

    await tester.tap(find.text('Exclusive'));
    await tester.pumpAndSettle();
    expect(backend.last('GET', '/campaigns').url.queryParameters['exclusive'], 'true');
  });

  group('Submit video', () {
    final campaign = Campaign.fromJson(campaignJson(platforms: ['tiktok', 'instagram']));

    testWidgets('menolak platform yang tidak diterima & link duplikat milik sendiri', (tester) async {
      final backend = FakeBackend(_creatorBase(subs: [
        submissionJson(url: 'https://tiktok.com/@ani/video/99'),
      ]));
      await pumpWithSession(tester, backend, SubmitVideoView(campaign: campaign));

      final input = find.byKey(const Key('submit-url-input'));
      await tester.enterText(input, 'https://youtube.com/shorts/abc');
      await tester.tap(find.byKey(const Key('submit-video-button')));
      await tester.pumpAndSettle();
      expect(find.text('Campaign ini tidak menerima video YouTube'), findsOneWidget);

      await tester.enterText(input, 'https://www.tiktok.com/@ani/video/99/?lang=id');
      await tester.tap(find.byKey(const Key('submit-video-button')));
      await tester.pumpAndSettle();
      expect(find.text('Kamu sudah pernah submit video ini'), findsOneWidget);
      expect(backend.called('POST', '/submissions'), isFalse);
    });

    testWidgets('auto-pilih platform dari link lalu kirim; error duplikat global dari backend tampil', (tester) async {
      var attempt = 0;
      final backend = FakeBackend({
        ..._creatorBase(),
        'POST /submissions': (_) => ++attempt == 1
            ? jsonResponse({'detail': 'Video ini sudah pernah didaftarkan'}, 400)
            : submissionJson(),
      });
      await pumpWithSession(tester, backend, SubmitVideoView(campaign: campaign));

      await tester.enterText(find.byKey(const Key('submit-url-input')), 'https://www.instagram.com/reel/xyz/');
      await tester.pump();
      await tester.tap(find.byKey(const Key('submit-video-button')));
      await tester.pumpAndSettle();

      expect(backend.lastBody('POST', '/submissions'), {
        'campaign_id': 'cmp_1',
        'platform': 'instagram',
        'video_url': 'https://www.instagram.com/reel/xyz/',
      });
      expect(find.text('Video ini sudah pernah didaftarkan'), findsOneWidget);
    });
  });

  testWidgets('Konten: filter status & klaim views (validasi minimum)', (tester) async {
    final backend = FakeBackend({
      ..._creatorBase(subs: [
        submissionJson(id: 'sub_a', status: 'menunggu_views'),
        submissionJson(id: 'sub_b', status: 'direview', url: 'https://tiktok.com/@ani/video/2'),
      ]),
      'POST /submissions/sub_a/claim': (_) => {'ok': true},
      'GET /creator/stats': (_) => {'balance': 0, 'streak': {}},
    });
    await pumpWithSession(tester, backend, const ContentView());

    expect(find.text('Disetujui · Klaim views'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('content-filter-direview')));
    await tester.tap(find.byKey(const Key('content-filter-direview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submission-sub_a')), findsNothing);
    expect(find.byKey(const Key('submission-sub_b')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('content-filter-disetujui')));
    await tester.tap(find.byKey(const Key('content-filter-disetujui')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('claim-views-button-sub_a')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('claim-views-input')), '500');
    await tester.tap(find.byKey(const Key('claim-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Views minimal 1.000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('claim-views-input')), '25000');
    await tester.pump();
    expect(find.text('Estimasi pendapatan: Rp 250.000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('claim-submit-button')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('POST', '/submissions/sub_a/claim'), {'views': 25000});
  });

  testWidgets('Withdraw: minimal Rp 50.000, tidak melebihi saldo, prefill rekening', (tester) async {
    final backend = FakeBackend({
      ..._creatorBase(),
      'POST /withdrawals': (_) => {
            'withdrawal_id': 'wd_1',
            'amount': 60000,
            'method': 'DANA',
            'account_number': '081234567',
            'account_holder': 'Ani',
            'status': 'diproses',
            'reference': '',
            'created_at': DateTime.now().toIso8601String(),
          },
    });
    await pumpWithSession(tester, backend, const WithdrawView(balance: 125000));

    expect(find.text('081234567'), findsOneWidget); // prefill dari profil

    final amount = find.byKey(const Key('withdraw-amount-input'));
    await tester.enterText(amount, '40000');
    await tester.ensureVisible(find.byKey(const Key('withdraw-submit-button')));
    await tester.tap(find.byKey(const Key('withdraw-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Minimal penarikan Rp 50.000'), findsOneWidget);

    await tester.enterText(amount, '200000');
    await tester.tap(find.byKey(const Key('withdraw-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Melebihi saldo (Rp 125.000)'), findsOneWidget);

    await tester.enterText(amount, '60000');
    await tester.tap(find.byKey(const Key('withdraw-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('POST', '/withdrawals'), {
      'amount': 60000,
      'method': 'DANA',
      'account_number': '081234567',
      'account_holder': 'Ani',
    });
  });
}
