import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/api_service.dart';
import 'package:ourbuzzer/services/image_picker_service.dart';
import 'package:ourbuzzer/views/brand/create_campaign_view.dart';
import 'package:ourbuzzer/views/brand/topup_view.dart';
import 'package:ourbuzzer/views/common/edit_profile_view.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';

import 'helpers.dart';

class _FakePicker extends ImagePickerService {
  const _FakePicker();
  @override
  Future<PickedImage?> pickFromGallery() async =>
      const PickedImage(bytes: [0x89, 0x50, 0x4E, 0x47, 1, 2, 3], filename: 'thumb.png');
}

Map<String, dynamic> _wd(String id, {String status = 'diproses'}) => {
      'withdrawal_id': id,
      'creator_name': 'Ani Kreator',
      'creator_email': 'ani@example.com',
      'amount': 75000,
      'method': 'BCA',
      'account_number': '1234567890',
      'account_holder': 'Ani',
      'status': status,
      'reference': '',
      'created_at': DateTime.now().toIso8601String(),
    };

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('uploadImage mengirim multipart + Bearer dan mengembalikan URL', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: 'https://x/api',
      client: MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'upload_id': 'img_1', 'url': 'https://x/api/uploads/img_1'}), 200);
      }),
    )..token = 'tok';
    final url = await api.uploadImage([1, 2, 3], filename: 'a.png');

    expect(url, 'https://x/api/uploads/img_1');
    expect(captured.url.path, '/api/uploads');
    expect(captured.headers['Authorization'], 'Bearer tok');
    expect(captured.headers['content-type'], startsWith('multipart/form-data'));
    expect(captured.body, contains('name="file"; filename="a.png"'));
  });

  testWidgets('Edit profil kreator: semua field profil dikirim (tidak ada yang terhapus)', (tester) async {
    final backend = FakeBackend({
      'GET /auth/me': (_) => userJson(),
      'PUT /users/profile': (req) => {
            ...userJson(),
            'name': 'Ani Baru',
            'profile': (jsonDecode(req.body) as Map)..remove('name'),
          },
    });
    await pumpWithSession(tester, backend, const EditProfileView());

    await tester.enterText(find.byKey(const Key('profile-name-input')), 'Ani Baru');
    await tester.enterText(find.byKey(const Key('profile-tiktok-input')), 'ani.creates');
    await tester.ensureVisible(find.byKey(const Key('profile-method-BCA')));
    await tester.tap(find.byKey(const Key('profile-method-BCA')));
    await tester.enterText(find.byKey(const Key('profile-account-input')), '1234567890');
    await tester.ensureVisible(find.byKey(const Key('profile-save-button')));
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();

    expect(backend.lastBody('PUT', '/users/profile'), {
      'name': 'Ani Baru',
      'brand_name': '',
      'tiktok': 'ani.creates',
      'instagram': '',
      'bank_method': 'BCA',
      'bank_account': '1234567890',
      'bank_holder': 'Ani', // dipertahankan dari profil lama
    });
  });

  testWidgets('Edit profil: nomor rekening tanpa metode ditolak', (tester) async {
    final user = userJson()..['profile'] = <String, String>{};
    final backend = FakeBackend({'GET /auth/me': (_) => user});
    await pumpWithSession(tester, backend, const EditProfileView());

    await tester.enterText(find.byKey(const Key('profile-account-input')), '1234567890');
    await tester.ensureVisible(find.byKey(const Key('profile-save-button')));
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Pilih metode pencairan'), findsOneWidget);
    expect(backend.called('PUT', '/users/profile'), isFalse);
  });

  testWidgets('Buat campaign: pilih gambar → upload → URL dipakai sebagai thumbnail', (tester) async {
    final backend = FakeBackend({
      'GET /auth/me': (_) => userJson(role: 'brand', brandBalance: 5000000),
      'POST /uploads': (_) => {'upload_id': 'img_9', 'url': 'https://x/api/uploads/img_9'},
      'POST /campaigns': (_) => campaignJson(),
    });
    await pumpWithSession(tester, backend, const CreateCampaignView(),
        overrides: [imagePickerServiceProvider.overrideWithValue(const _FakePicker())]);

    await tester.enterText(find.byKey(const Key('campaign-title-input')), 'Kopi Susu Viral');
    await tester.scrollUntilVisible(find.byKey(const Key('thumbnail-pick-button')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('thumbnail-pick-button')));
    await tester.pumpAndSettle();
    expect(backend.called('POST', '/uploads'), isTrue);
    expect(find.text('https://x/api/uploads/img_9'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // tunggu snackbar "Gambar terunggah" hilang
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('campaign-instructions-input')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('campaign-instructions-input')), 'Video 30 detik, sebut brand.');
    await tester.scrollUntilVisible(find.byKey(const Key('campaign-create-button')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();

    expect(backend.lastBody('POST', '/campaigns')['thumbnail'], 'https://x/api/uploads/img_9');
  });

  group('Top up: status konfigurasi Komerce', () {
    Map<String, Handler> routes(bool configured, bool sandbox) => {
          'GET /auth/me': (_) => userJson(role: 'brand'),
          'GET /payments/config': (_) => {'komerce_configured': configured, 'sandbox': sandbox},
        };

    testWidgets('belum dikonfigurasi → banner & tombol bayar nonaktif', (tester) async {
      await pumpWithSession(tester, FakeBackend(routes(false, false)), const TopupView());
      expect(find.byKey(const Key('topup-not-configured')), findsOneWidget);
      final btn = tester.widget<ButtonStyleButton>(
          find.descendant(of: find.byKey(const Key('topup-create-button')), matching: find.byType(FilledButton)));
      expect(btn.enabled, isFalse);
    });

    testWidgets('sudah dikonfigurasi (sandbox) → banner sandbox, tanpa pesan error', (tester) async {
      await pumpWithSession(tester, FakeBackend(routes(true, true)), const TopupView());
      expect(find.byKey(const Key('topup-not-configured')), findsNothing);
      expect(find.byKey(const Key('topup-sandbox')), findsOneWidget);
    });
  });

  testWidgets('Admin: tab Ringkasan & Withdraw; setujui dengan referensi, tolak dengan alasan', (tester) async {
    final admin = userJson(role: 'admin');
    final backend = FakeBackend({
      'GET /auth/me': (_) => admin,
      'GET /admin/stats': (_) => {
            'creators': 10,
            'brands': 3,
            'active_campaigns': 4,
            'pending_withdrawals': 2,
            'pending_submissions': 5,
            'total_paid': 1500000,
            'total_views': 250000,
          },
      'GET /admin/withdrawals': (_) => [_wd('wd_1'), _wd('wd_2'), _wd('wd_3', status: 'disetujui')],
      'POST /admin/withdrawals/wd_1': (_) => {'ok': true},
      'POST /admin/withdrawals/wd_2': (_) => {'ok': true},
    });
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(admin)));

    expect(find.text('Rp 1.500.000'), findsOneWidget);
    expect(find.text('Withdraw menunggu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-Withdraw')));
    await tester.pumpAndSettle();
    expect(find.text('Menunggu (2)'), findsOneWidget);
    expect(find.byKey(const Key('admin-wd-wd_3')), findsNothing); // sudah selesai → di tab Semua

    await tester.tap(find.byKey(const Key('admin-wd-approve-wd_1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('sudah ditransfer ke BCA 1234567890'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('note-dialog-input')), 'TRF-001');
    await tester.tap(find.byKey(const Key('note-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('POST', '/admin/withdrawals/wd_1'), {'action': 'approve', 'reference': 'TRF-001'});

    await tester.tap(find.byKey(const Key('admin-wd-reject-wd_2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-dialog-input')), 'Nama rekening tidak cocok');
    await tester.tap(find.byKey(const Key('note-dialog-ok')));
    await tester.pumpAndSettle();
    expect(backend.lastBody('POST', '/admin/withdrawals/wd_2'),
        {'action': 'reject', 'reference': 'Nama rekening tidak cocok'});

    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-wd-wd_3')), findsOneWidget);
  });
}
