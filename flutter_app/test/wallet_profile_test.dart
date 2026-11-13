import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/image_picker_service.dart';
import 'package:ourbuzzer/views/home/home_shell.dart';

import 'helpers.dart';

Map<String, dynamic> _wd(String id, int amount, String status, {String reference = ''}) => {
      'withdrawal_id': id,
      'amount': amount,
      'method': 'BCA',
      'account_number': '1234567890',
      'account_holder': 'Ani',
      'status': status,
      'reference': reference,
      'created_at': DateTime(2026, 11, 1).toIso8601String(),
    };

FakeBackend _backend() => FakeBackend({
      'GET /auth/me': (_) => userJson(balance: 125000),
      'GET /notifications': (_) => {'items': [], 'unread': 0},
      'GET /creator/stats': (_) => {'balance': 125000, 'total_earned': 300000, 'pending': 25000, 'streak': {}},
      'GET /campaigns/sections': (_) => {'trending': [], 'top_rate': [], 'newest': [], 'closing': []},
      'GET /campaigns': (_) => [],
      'GET /creator/submissions': (_) => [],
      'GET /creator/withdrawals': (_) => [
            _wd('wd_1', 75000, 'diproses'),
            _wd('wd_2', 50000, 'disetujui', reference: 'TRF-777'),
            _wd('wd_3', 60000, 'ditolak'),
          ],
    });

class _FakePicker extends ImagePickerService {
  const _FakePicker();
  @override
  Future<PickedImage?> pickFromGallery() async =>
      const PickedImage(bytes: [0x89, 0x50, 0x4E, 0x47, 1, 2, 3], filename: 'me.png');
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Dompet: saldo, sembunyikan saldo, timeline riwayat, Lihat Semua, menu akun', (tester) async {
    await pumpWithSession(tester, _backend(), HomeShell(user: User.fromJson(userJson(balance: 125000))));
    await tester.tap(find.byKey(const Key('tab-Dompet')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('wallet-balance'))).data, 'Rp 125.000');
    expect(find.text('Rp 300.000'), findsOneWidget); // Total Pendapatan
    expect(find.text('Rp 25.000'), findsOneWidget); // Sedang dicek
    // Saldo cukup → tombol tarik aktif.
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('open-withdraw-button'))).enabled, isTrue);

    // Sembunyikan / tampilkan saldo (hanya tampilan).
    await tester.tap(find.byKey(const Key('wallet-toggle-balance')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('wallet-balance'))).data, 'Rp ••••••');
    await tester.tap(find.byKey(const Key('wallet-toggle-balance')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('wallet-balance'))).data, 'Rp 125.000');

    // Timeline memakai data penarikan asli.
    await tester.scrollUntilVisible(find.byKey(const Key('wallet-history-timeline')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Rp 75.000'), findsOneWidget);
    expect(find.text('Diproses'), findsOneWidget);
    expect(find.text('Berhasil'), findsOneWidget);

    // Lihat Semua → daftar lengkap dengan referensi.
    await tester.tap(find.byKey(const Key('wallet-history-all')));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat penarikan'), findsOneWidget);
    expect(find.text('Ref: TRF-777'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Menu akun di Dompet → Bantuan & FAQ.
    await tester.scrollUntilVisible(find.byKey(const Key('wallet-profile-faq')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('wallet-profile-faq')));
    await tester.pumpAndSettle();
    expect(find.text('Bantuan & FAQ'), findsWidgets);
  });

  testWidgets('Profil: avatar → Edit profil, Riwayat → Dompet, menu lengkap', (tester) async {
    await pumpWithSession(tester, _backend(), HomeShell(user: User.fromJson(userJson(balance: 125000))));
    await tester.tap(find.byKey(const Key('tab-Profil')));
    await tester.pumpAndSettle();

    expect(find.text('Kreator'), findsOneWidget);
    expect(find.text('Rekening pencairan'), findsOneWidget);
    for (final label in ['Konten saya', 'Voucher / Kupon', 'Ajak Teman', 'Bantuan & FAQ', 'Pengaturan', 'Keluar']) {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Segera'), findsNWidgets(2));

    // Avatar header → lembar pilihan → Edit profil.
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('avatar-pick')), findsOneWidget);
    expect(find.byKey(const Key('avatar-remove')), findsNothing); // belum ada foto unggahan
    await tester.tap(find.byKey(const Key('edit-profile-button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit profil'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Riwayat → halaman Dompet (dengan tombol kembali).
    await tester.scrollUntilVisible(find.byKey(const Key('profile-history-button')), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('profile-history-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-balance')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Profil: ganti foto profil dari galeri, lalu hapus', (tester) async {
    final backend = _backend();
    backend.routes['POST /users/avatar'] =
        (_) => {...userJson(balance: 125000), 'picture': 'https://x/api/uploads/img_1', 'picture_custom': true};
    backend.routes['DELETE /users/avatar'] =
        (_) => {...userJson(balance: 125000), 'picture': null, 'picture_custom': false};
    await pumpWithSession(tester, backend, HomeShell(user: User.fromJson(userJson(balance: 125000))),
        overrides: [imagePickerServiceProvider.overrideWithValue(const _FakePicker())]);
    await tester.tap(find.byKey(const Key('tab-Profil')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('avatar-pick')));
    await tester.pumpAndSettle();
    expect(backend.called('POST', '/users/avatar'), isTrue);
    expect(find.text('Foto profil diperbarui'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Foto unggahan → opsi "Hapus foto" muncul.
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('avatar-remove')));
    await tester.pumpAndSettle();
    expect(backend.called('DELETE', '/users/avatar'), isTrue);
    expect(find.text('Foto profil dihapus'), findsOneWidget);
  });
}
