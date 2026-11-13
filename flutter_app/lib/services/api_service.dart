// ============================================================================
//  ApiService — SATU-SATUNYA pintu komunikasi ke backend.
//
//  Semua view/provider memanggil method di kelas ini, tidak pernah memakai
//  `http` langsung. Saat migrasi ke Supabase cukup ganti implementasi method
//  di file ini (signature & model tetap sama), UI tidak perlu disentuh.
//
//  Kontrak endpoint meniru persis `backend/server.py` (FastAPI, prefix /api):
//  - Auth via header `Authorization: Bearer <session_token>`
//  - Error backend berbentuk `{"detail": "pesan"}` atau
//    `{"detail": [{"msg": ...}, ...]}` (validasi Pydantic, status 422)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'image_picker_service.dart';

import '../core/config.dart';
import '../models/models.dart';

/// Error yang dilempar oleh [ApiService]. [message] sudah siap ditampilkan.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// 0 = tidak ada koneksi / timeout.
  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNetwork => statusCode == 0;

  @override
  String toString() => message;
}

typedef _Query = Map<String, Object?>;

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = baseUrl ?? AppConfig.apiBase;

  final http.Client _client;
  final String _base;

  /// Token sesi aktif; dikirim sebagai `Authorization: Bearer <token>`.
  /// Diatur oleh AuthNotifier (dari secure storage / setelah login).
  String? token;

  /// Dipanggil saat server membalas 401 untuk request yang membawa token
  /// (sesi kadaluarsa / dihapus) → AuthNotifier akan logout lokal.
  void Function()? onUnauthorized;

  // ---------------------------------------------------------------------------
  //  Core HTTP
  // ---------------------------------------------------------------------------

  Uri _uri(String path, [_Query? query]) {
    final qp = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) qp[k] = '$v';
    });
    return Uri.parse('$_base$path').replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Future<dynamic> _send(String method, String path, {Object? body, _Query? query}) {
    final req = http.Request(method, _uri(path, query));
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    return _dispatch(req);
  }

  /// Kirim request apa pun (JSON atau multipart) dengan header auth & penanganan error standar.
  Future<dynamic> _dispatch(http.BaseRequest req) async {
    req.headers['Accept'] = 'application/json';
    final sentToken = token;
    if (sentToken != null) req.headers['Authorization'] = 'Bearer $sentToken';

    http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(AppConfig.httpTimeout),
      );
    } on TimeoutException {
      throw const ApiException(0, 'Koneksi timeout, coba lagi');
    } on SocketException {
      throw const ApiException(0, 'Tidak ada koneksi internet');
    } on http.ClientException {
      throw const ApiException(0, 'Tidak ada koneksi internet');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && sentToken != null) onUnauthorized?.call();
    throw ApiException(res.statusCode, _errorMessage(data, res.statusCode));
  }

  static String _errorMessage(dynamic data, int status) {
    final d = data is Map ? data['detail'] : null;
    if (d is String && d.isNotEmpty) return d;
    if (d is List) {
      final msgs = d.map((e) => e is Map ? '${e['msg'] ?? ''}' : '$e').where((m) => m.isNotEmpty);
      if (msgs.isNotEmpty) return msgs.join(', ');
    }
    if (status >= 500) return 'Server sedang bermasalah, coba lagi nanti';
    return 'Terjadi kesalahan';
  }

  Future<Json> _obj(String method, String path, {Object? body, _Query? query}) async {
    final data = await _send(method, path, body: body, query: query);
    return data is Map ? Json.from(data) : <String, dynamic>{};
  }

  Future<List<T>> _list<T>(String path, T Function(Json) fromJson, {_Query? query}) async {
    final data = await _send('GET', path, query: query);
    return asList(data, fromJson);
  }

  Future<void> _ok(String method, String path, {Object? body}) => _send(method, path, body: body);

  // ---------------------------------------------------------------------------
  //  Auth & profil
  // ---------------------------------------------------------------------------

  /// Tukar **Firebase ID token** (hasil login Google di aplikasi) menjadi sesi
  /// backend. `POST /auth/firebase {id_token}` → backend memverifikasi token,
  /// membuat/menemukan user di MongoDB, lalu mengembalikan user + `session_token`
  /// (berlaku 7 hari). User baru belum punya peran → onboarding.
  Future<AuthSession> exchangeFirebaseToken(String idToken) async =>
      AuthSession.fromJson(await _obj('POST', '/auth/firebase', body: {'id_token': idToken}));

  /// Login Admin Pusat (Owner) langkah 1: `POST /admin/request-otp {phone}` — backend
  /// mengirim OTP 6 digit lewat WhatsApp (Fonnte). Mengembalikan nomor tersamar &
  /// jeda kirim ulang (detik).
  Future<({String maskedPhone, int resendIn})> requestAdminOtp(String phone) async {
    final j = await _obj('POST', '/admin/request-otp', body: {'phone': phone.trim()});
    return (maskedPhone: asStr(j['phone']), resendIn: j['resend_in'] == null ? 60 : asInt(j['resend_in']));
  }

  /// Langkah 2: `POST /admin/verify-otp {phone, code}` → sesi admin (user + `session_token`).
  Future<AuthSession> verifyAdminOtp(String phone, String code) async =>
      AuthSession.fromJson(await _obj('POST', '/admin/verify-otp', body: {'phone': phone.trim(), 'code': code}));

  /// Login email + password. `POST /auth/login {email, password}` → respons
  /// sama dengan `/auth/session` (user + `session_token`).
  /// Error: 401 "Email atau password salah" / "Akun ini terdaftar lewat Google...",
  /// 429 setelah terlalu banyak percobaan gagal (15 menit).
  /// Saat pindah ke Supabase: ganti dengan `supabase.auth.signInWithPassword`.
  Future<AuthSession> loginWithEmail(String email, String password) async =>
      AuthSession.fromJson(await _obj('POST', '/auth/login',
          body: {'email': email.trim().toLowerCase(), 'password': password}));

  /// Daftar akun email. `POST /auth/register {name, email, password}`
  /// (password 8–72 karakter). User baru belum punya peran → onboarding.
  /// Error 400 bila email sudah terdaftar (termasuk akun Google).
  Future<AuthSession> registerWithEmail(String name, String email, String password) async =>
      AuthSession.fromJson(await _obj('POST', '/auth/register',
          body: {'name': name.trim(), 'email': email.trim().toLowerCase(), 'password': password}));

  /// `GET /sync` → nomor versi data yang naik setiap ada perubahan (web, aplikasi, atau Owner).
  Future<int> syncVersion() async => asInt((await _obj('GET', '/sync'))['v']);

  /// `GET /auth/me`
  Future<User> me() async => User.fromJson(await _obj('GET', '/auth/me'));

  /// `POST /auth/logout` — menghapus sesi di server.
  Future<void> logout() => _ok('POST', '/auth/logout');

  /// Pilih peran setelah login pertama (hanya sekali; backend menolak jika
  /// sudah punya peran). `POST /users/role`
  Future<User> setRole(UserRole role, {String? brandName}) async {
    assert(role != UserRole.admin, 'Admin tidak bisa dipilih dari aplikasi');
    return User.fromJson(await _obj('POST', '/users/role', body: {
      'role': role.wire,
      if (role == UserRole.brand && brandName != null && brandName.trim().isNotEmpty)
        'brand_name': brandName.trim(),
    }));
  }

  /// `PUT /users/profile` — field: name (wajib), tiktok, instagram, brand_name,
  /// bank_method, bank_account, bank_holder.
  Future<User> updateProfile({required String name, Map<String, String> profile = const {}}) async =>
      User.fromJson(await _obj('PUT', '/users/profile', body: {'name': name, ...profile}));

  /// `POST /users/avatar` (multipart, field `file`) — ganti foto profil sendiri.
  /// JPG/PNG/WebP, maks. 2 MB. Mengembalikan data user terbaru.
  Future<User> uploadAvatar(List<int> bytes, {String filename = 'avatar.jpg'}) async {
    final req = http.MultipartRequest('POST', _uri('/users/avatar'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final data = await _dispatch(req);
    return User.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  /// `DELETE /users/avatar` — hapus foto unggahan, kembali ke foto Google / inisial.
  Future<User> deleteAvatar() async => User.fromJson(await _obj('DELETE', '/users/avatar'));

  // ---------------------------------------------------------------------------
  //  Akun sosial media & komunitas Telegram
  // ---------------------------------------------------------------------------

  /// `GET /users/social` — TikTok / Instagram / Threads / Telegram milik user.
  Future<SocialAccounts> socialAccounts() async => SocialAccounts.fromJson(await _obj('GET', '/users/social'));

  /// `PUT /users/social/{platform}` — `handle` boleh `@username` atau link profil.
  Future<SocialAccounts> linkSocial(SocialPlatform p, String handle) async =>
      SocialAccounts.fromJson(await _obj('PUT', '/users/social/${p.wire}', body: {'handle': handle.trim()}));

  /// `DELETE /users/social/{platform}` — `platform` = tiktok / instagram / threads / telegram.
  Future<SocialAccounts> unlinkSocial(String platform) async =>
      SocialAccounts.fromJson(await _obj('DELETE', '/users/social/$platform'));

  /// `POST /users/social/telegram/link` → deep link sekali pakai `https://t.me/<bot>?start=<kode>`.
  Future<String> telegramLinkUrl() async => asStr((await _obj('POST', '/users/social/telegram/link'))['url']);

  /// `GET /public/community` — link grup Telegram & status integrasi bot.
  Future<CommunityLinks> community() async => CommunityLinks.fromJson(await _obj('GET', '/public/community'));

  // ---------------------------------------------------------------------------
  //  Campaign (publik) — halaman Cari Cuan
  // ---------------------------------------------------------------------------

  /// Section banner: Lagi rame, Segera ditutup, Rate tertinggi, Campaign baru.
  Future<CampaignSections> campaignSections() async =>
      CampaignSections.fromJson(await _obj('GET', '/campaigns/sections'));

  /// Daftar campaign aktif. [exclusive] = tab Exclusive vs Public.
  /// [category] "Semua"/kosong = tanpa filter.
  Future<List<Campaign>> campaigns({
    String query = '',
    String? category,
    bool exclusive = false,
    CampaignSort sort = CampaignSort.newest,
  }) =>
      _list('/campaigns', Campaign.fromJson, query: {
        'q': query.trim(),
        'category': category,
        'exclusive': exclusive,
        'sort': sort.wire,
      });

  Future<Campaign> campaign(String id) async =>
      Campaign.fromJson(await _obj('GET', '/campaigns/${Uri.encodeComponent(id)}'));

  // ---------------------------------------------------------------------------
  //  Kreator
  // ---------------------------------------------------------------------------

  /// `GET /creator/stats` — saldo, pending, jumlah video, streak.
  Future<CreatorStats> creatorStats() async => CreatorStats.fromJson(await _obj('GET', '/creator/stats'));

  /// `GET /streak`
  Future<Streak> streak() async => Streak.fromJson(await _obj('GET', '/streak'));

  /// Konten saya (semua status).
  Future<List<Submission>> creatorSubmissions() => _list('/creator/submissions', Submission.fromJson);

  /// Submit link video. Backend memvalidasi: campaign aktif, platform diterima
  /// campaign, domain link sesuai platform, dan anti-duplikat (link yang sudah
  /// pernah didaftarkan siapa pun → "Video ini sudah pernah didaftarkan").
  /// Status awal: `direview`.
  Future<Submission> submitVideo({
    required String campaignId,
    required VideoPlatform platform,
    required String videoUrl,
  }) async =>
      Submission.fromJson(await _obj('POST', '/submissions', body: {
        'campaign_id': campaignId,
        'platform': platform.wire,
        'video_url': videoUrl.trim(),
      }));

  /// Klaim views (status harus `menunggu_views`, views ≥ min_views campaign).
  /// Status berubah → `diproses` (Dicek views).
  /// Klaim views + bukti analitik (1-3 screenshot / rekaman layar). Multipart.
  Future<void> claimWithProof(
    String submissionId, {
    required int views,
    required List<PickedMedia> files,
    String note = '',
  }) async {
    final req = http.MultipartRequest('POST', _uri('/submissions/$submissionId/claim-proof'))
      ..fields['views'] = '$views'
      ..fields['note'] = note;
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes('files', f.bytes, filename: f.filename));
    }
    await _dispatch(req);
  }

  // ---------------------------------------------------------------------------
  //  Upload gambar (thumbnail campaign) — brand/admin
  // ---------------------------------------------------------------------------

  /// `POST /uploads` (multipart, field `file`). JPG/PNG/WebP, maks. 2 MB.
  /// Mengembalikan URL publik gambar untuk field `thumbnail` campaign.
  Future<String> uploadImage(List<int> bytes, {String filename = 'image.jpg'}) async {
    final req = http.MultipartRequest('POST', _uri('/uploads'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final data = await _dispatch(req);
    return data is Map ? asStr(data['url']) : '';
  }

  /// Riwayat penarikan.
  Future<List<Withdrawal>> withdrawals() => _list('/creator/withdrawals', Withdrawal.fromJson);

  /// Penarikan saldo brand (sisa budget yang sudah kembali / saldo mengendap).
  Future<List<Withdrawal>> brandWithdrawals() => _list('/brand/withdrawals', Withdrawal.fromJson);

  /// Persentase fee platform & batas minimal (publik).
  Future<FeesConfig> fees() async => FeesConfig.fromJson(await _obj('GET', '/config/fees'));

  /// Riwayat mutasi saldo akun yang login.
  Future<List<LedgerEntry>> ledger() => _list('/ledger', LedgerEntry.fromJson);

  /// Tarik saldo (min Rp 50.000). Saldo langsung ditahan penuh; dana yang ditransfer = nominal - biaya
  /// platform. [brand] = tarik saldo brand (`/brand/withdrawals`).
  Future<Withdrawal> withdraw({
    required int amount,
    required String method,
    required String accountNumber,
    required String accountHolder,
    bool brand = false,
  }) async =>
      Withdrawal.fromJson(await _obj('POST', brand ? '/brand/withdrawals' : '/withdrawals', body: {
        'amount': amount,
        'method': method,
        'account_number': accountNumber,
        'account_holder': accountHolder,
      }));

  // ---------------------------------------------------------------------------
  //  Brand
  // ---------------------------------------------------------------------------

  Future<BrandStats> brandStats() async => BrandStats.fromJson(await _obj('GET', '/brand/stats'));

  Future<List<Campaign>> brandCampaigns() => _list('/brand/campaigns', Campaign.fromJson);

  /// Buat campaign — budget langsung dipotong dari saldo brand.
  /// Error 400 "Saldo brand tidak cukup..." bila saldo kurang.
  Future<Campaign> createCampaign(CampaignInput input) async =>
      Campaign.fromJson(await _obj('POST', '/campaigns', body: input.toJson()));

  /// Jeda / lanjutkan / tutup campaign. Menutup campaign akan otomatis:
  /// menolak submission yang masih terbuka & mengembalikan sisa budget
  /// (budget - spent) ke saldo brand.
  /// Ubah status campaign. Return sisa budget yang dikembalikan ke saldo brand (hanya saat ditutup).
  Future<int> setCampaignStatus(String campaignId, CampaignStatus status) async {
    final data = await _obj('PATCH', '/campaigns/$campaignId/status', body: {'status': status.wire});
    return asInt(data['refund']);
  }

  Future<int> pauseCampaign(String id) => setCampaignStatus(id, CampaignStatus.paused);
  Future<int> resumeCampaign(String id) => setCampaignStatus(id, CampaignStatus.active);
  Future<int> closeCampaign(String id) => setCampaignStatus(id, CampaignStatus.closed);

  /// Review konten (status `direview`). approve → `menunggu_views`,
  /// reject → `ditolak`.
  Future<void> reviewContent(String submissionId, {required bool approve, String note = ''}) =>
      _ok('POST', '/submissions/$submissionId/review',
          body: {'action': approve ? 'approve' : 'reject', 'note': note});

  /// Verifikasi views yang diklaim (status `diproses`). Jika approve dan
  /// views ≥ min_views → `disetujui`, kreator dibayar
  /// `verified_views / 1000 * rate_per_1k` (dibatasi sisa budget).
  /// Mengembalikan jumlah payout.
  Future<int> verifyViews(
    String submissionId, {
    required bool approve,
    int verifiedViews = 0,
    String note = '',
  }) async {
    final res = await _obj('POST', '/submissions/$submissionId/verify', body: {
      'action': approve ? 'approve' : 'reject',
      'verified_views': verifiedViews,
      'note': note,
    });
    return asInt(res['payout']);
  }

  // ---------------------------------------------------------------------------
  //  Brand top up (Komerce sandbox)
  // ---------------------------------------------------------------------------

  Future<List<Topup>> topups() => _list('/brand/topups', Topup.fromJson);

  /// Status konfigurasi pembayaran (untuk banner "belum dikonfigurasi" / "sandbox").
  Future<PaymentsConfig> paymentsConfig() async =>
      PaymentsConfig.fromJson(await _obj('GET', '/payments/config'));

  /// Buat tagihan top up. QRIS → [Topup.qrString]; VA → [Topup.vaNumber].
  Future<Topup> createTopup({
    required int amount,
    required PaymentType paymentType,
    String channelCode = 'BCA',
    String? phone,
  }) async =>
      Topup.fromJson(await _obj('POST', '/brand/topups', body: {
        'amount': amount,
        'payment_type': paymentType.wire,
        if (paymentType == PaymentType.bankTransfer) 'channel_code': channelCode,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }));

  /// Tombol "Cek status pembayaran" — server sinkron ke Komerce lalu
  /// mengkredit saldo brand bila sudah lunas.
  Future<Topup> checkTopup(String topupId) async =>
      Topup.fromJson(await _obj('POST', '/brand/topups/$topupId/check'));

  // ---------------------------------------------------------------------------
  //  Admin
  // ---------------------------------------------------------------------------

  Future<AdminStats> adminStats() async => AdminStats.fromJson(await _obj('GET', '/admin/stats'));

  /// Semua penarikan (terbaru dulu), termasuk nama & email kreator.
  Future<List<Withdrawal>> adminWithdrawals() => _list('/admin/withdrawals', Withdrawal.fromJson);

  /// Setujui (dana sudah ditransfer; [reference] = no. referensi transfer) atau
  /// tolak (saldo dikembalikan ke kreator; [reference] = alasan).
  Future<void> adminWithdrawAction(String withdrawalId, {required bool approve, String reference = ''}) =>
      _ok('POST', '/admin/withdrawals/$withdrawalId',
          body: {'action': approve ? 'approve' : 'reject', 'reference': reference});

  // ---------------------------------------------------------------------------
  //  Notifikasi
  // ---------------------------------------------------------------------------

  Future<NotificationFeed> notifications() async =>
      NotificationFeed.fromJson(await _obj('GET', '/notifications'));

  Future<void> markAllNotificationsRead() => _ok('POST', '/notifications/read-all');

  void dispose() => _client.close();
}
