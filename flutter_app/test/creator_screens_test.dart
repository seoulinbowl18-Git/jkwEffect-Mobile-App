import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/image_picker_service.dart';
import 'package:ourbuzzer/views/creator/claim_proof_view.dart';
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

class _FakeProofPicker extends ImagePickerService {
  const _FakeProofPicker(this.media);
  final List<PickedMedia> media;

  @override
  Future<List<PickedMedia>> pickProofMedia({int limit = 3}) async => media.take(limit).toList();
}

/// Chip filter ada di ListView horizontal yang lazy: gulir sampai chip terbangun, lalu tap.
Future<void> _tapChip(WidgetTester tester, String key) async {
  final chips = find.ancestor(of: find.byType(ChoiceChip).first, matching: find.byType(Scrollable)).first;
  for (final delta in [120.0, -120.0]) {
    if (find.byKey(Key(key)).evaluate().isNotEmpty) break;
    await tester.scrollUntilVisible(find.byKey(Key(key)), delta, scrollable: chips, maxScrolls: 20).catchError((_) {});
  }
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Gulir halaman klaim (ListView lazy) sampai [key] ada & terlihat.
Future<void> _scrollTo(WidgetTester tester, Key key) async {
  final scrollable = find.descendant(of: find.byType(ClaimProofView), matching: find.byType(Scrollable)).first;
  for (final delta in [300.0, -300.0]) {
    if (find.byKey(key).evaluate().isNotEmpty) break;
    await tester.scrollUntilVisible(find.byKey(key), delta, scrollable: scrollable, maxScrolls: 30)
        .catchError((_) {});
  }
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  await _scrollTo(tester, key);
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  await _scrollTo(tester, key);
  await tester.enterText(find.byKey(key), text);
  await tester.pump();
}

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

    expect(find.text('Lagi rame'), findsOneWidget);
    expect(find.text('Campaign Trending'), findsOneWidget);
    expect(find.text('Rp 125.000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campaign-search-input')), 'kopi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(backend.last('GET', '/campaigns').url.queryParameters['q'], 'kopi');
    expect(find.text('Kopi Susu Viral'), findsOneWidget);
    expect(find.text('Lagi rame'), findsNothing); // section disembunyikan saat mencari

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

  testWidgets('Konten: banner & tab Siap Diklaim, klaim dengan bukti analitik', (tester) async {
    final picker = _FakeProofPicker([
      const PickedMedia(bytes: [0x89, 0x50, 0x4E, 0x47, 1, 2, 3], filename: 'insight.png', isVideo: false),
      const PickedMedia(bytes: [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70], filename: 'rekaman.mp4', isVideo: true),
    ]);
    final backend = FakeBackend({
      ..._creatorBase(subs: [
        submissionJson(id: 'sub_a', status: 'menunggu_views'),
        submissionJson(id: 'sub_c', status: 'menunggu_views', url: 'https://tiktok.com/@ani/video/3'),
        submissionJson(id: 'sub_b', status: 'direview', url: 'https://tiktok.com/@ani/video/2'),
      ]),
      'POST /submissions/sub_a/claim-proof': (_) => {'ok': true, 'proofs': []},
      'GET /creator/stats': (_) => {'balance': 0, 'streak': {}},
    });
    await pumpWithSession(tester, backend, const ContentView(),
        overrides: [imagePickerServiceProvider.overrideWithValue(picker)]);

    // Banner: 2 video × (1.000 views min × Rp 10.000/1K) = Rp 20.000.
    expect(find.text('2 video siap diklaim'), findsOneWidget);
    expect(find.text('Estimasi min. Rp 20.000'), findsOneWidget);
    expect(find.text('Siap Diklaim (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ready-to-claim-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submission-sub_b')), findsNothing);
    expect(find.byKey(const Key('submission-sub_a')), findsOneWidget);

    await _tapChip(tester, 'content-filter-direview');
    expect(find.byKey(const Key('submission-sub_a')), findsNothing);
    expect(find.byKey(const Key('claim-views-button-sub_b')), findsNothing);

    await _tapChip(tester, 'content-filter-siapDiklaim');
    await tester.tap(find.byKey(const Key('claim-views-button-sub_a')));
    await tester.pumpAndSettle();

    // Halaman instruksi TikTok.
    expect(find.byKey(const Key('claim-guide')), findsOneWidget);
    expect(find.textContaining('Rekam layar analitik TikTok'), findsOneWidget);

    // Kirim tanpa bukti & views terlalu kecil → dua pesan validasi.
    await _enter(tester, const Key('claim-views-input'), '500');
    await _tapVisible(tester, const Key('claim-submit-button'));
    expect(find.text('Views minimal 1.000'), findsOneWidget);
    expect(find.byKey(const Key('proof-file-error')), findsOneWidget);
    expect(backend.called('POST', '/submissions/sub_a/claim-proof'), isFalse);

    await _tapVisible(tester, const Key('proof-pick-button'));
    expect(find.byKey(const Key('proof-file-0')), findsOneWidget);
    expect(find.byKey(const Key('proof-file-1')), findsOneWidget);
    expect(find.text('Rekaman layar · 0.0 MB'), findsOneWidget);
    expect(find.byKey(const Key('proof-file-error')), findsNothing);

    await _enter(tester, const Key('claim-views-input'), '25000');
    await tester.pump();
    expect(find.text('Estimasi pendapatan: Rp 250.000'), findsOneWidget);
    await _enter(tester, const Key('claim-note-input'), 'Data per hari ini');
    await _tapVisible(tester, const Key('claim-submit-button'));

    final req = backend.last('POST', '/submissions/sub_a/claim-proof');
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(req.bodyBytes);
    expect(body, contains('name="views"\r\n\r\n25000'));
    expect(body, contains('name="note"\r\n\r\nData per hari ini'));
    expect(body, contains('name="files"; filename="insight.png"'));
    expect(body, contains('name="files"; filename="rekaman.mp4"'));
    expect(find.text('Klaim & bukti terkirim. Brand akan mengecek secara manual.'), findsOneWidget);
    expect(find.byType(ContentView), findsOneWidget);
  });

  testWidgets('Klaim: file terlalu besar ditolak di HP sebelum upload', (tester) async {
    final big = _FakeProofPicker([
      PickedMedia(bytes: List.filled(maxProofImageBytes + 1, 0), filename: 'besar.png', isVideo: false),
    ]);
    final backend = FakeBackend({..._creatorBase()});
    await pumpWithSession(tester, backend, ClaimProofView(submission: Submission.fromJson(submissionJson(status: 'menunggu_views'))),
        overrides: [imagePickerServiceProvider.overrideWithValue(big)]);
    await _tapVisible(tester, const Key('proof-pick-button'));
    expect(find.byKey(const Key('proof-file-0')), findsNothing);
    expect(find.text('besar.png: screenshot maksimal 3 MB.'), findsOneWidget);
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
