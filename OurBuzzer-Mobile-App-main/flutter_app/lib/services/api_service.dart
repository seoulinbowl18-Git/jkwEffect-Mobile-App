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

  Future<dynamic> _send(String method, String path, {Object? body, _Query? query}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final sentToken = token;
    if (sentToken != null) headers['Authorization'] = 'Bearer $sentToken';

    final req = http.Request(method, _uri(path, query))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

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

  /// Tukar Firebase ID token (login Google via Firebase Auth) menjadi sesi.
  /// `POST /auth/firebase {id_token}` → user + `session_token` (berlaku 7 hari).
  /// Backend memverifikasi tanda tangan, `aud`/`iss` proyek Firebase, dan
  /// bahwa provider-nya Google dengan email terverifikasi.
  Future<AuthSession> loginWithFirebase(String idToken) async =>
      AuthSession.fromJson(await _obj('POST', '/auth/firebase', body: {'id_token': idToken}));

  /// Login email + password. `POST /auth/login {email, password}` → respons
  /// sama dengan `/auth/firebase` (user + `session_token`).
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
  Future<void> claimViews(String submissionId, int views) =>
      _ok('POST', '/submissions/$submissionId/claim', body: {'views': views});

  /// Riwayat penarikan.
  Future<List<Withdrawal>> withdrawals() => _list('/creator/withdrawals', Withdrawal.fromJson);

  /// Tarik saldo (min Rp 50.000). Saldo langsung ditahan; admin menyetujui manual.
  Future<Withdrawal> withdraw({
    required int amount,
    required String method,
    required String accountNumber,
    required String accountHolder,
  }) async =>
      Withdrawal.fromJson(await _obj('POST', '/withdrawals', body: {
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
  Future<void> setCampaignStatus(String campaignId, CampaignStatus status) =>
      _ok('PATCH', '/campaigns/$campaignId/status', body: {'status': status.wire});

  Future<void> pauseCampaign(String id) => setCampaignStatus(id, CampaignStatus.paused);
  Future<void> resumeCampaign(String id) => setCampaignStatus(id, CampaignStatus.active);
  Future<void> closeCampaign(String id) => setCampaignStatus(id, CampaignStatus.closed);

  /// Submission masuk ke campaign milik brand. [status] opsional untuk filter.
  Future<List<Submission>> brandSubmissions({SubmissionStatus? status}) =>
      _list('/brand/submissions', Submission.fromJson, query: {'status': status?.wire});

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
  //  Notifikasi
  // ---------------------------------------------------------------------------

  Future<NotificationFeed> notifications() async =>
      NotificationFeed.fromJson(await _obj('GET', '/notifications'));

  Future<void> markAllNotificationsRead() => _ok('POST', '/notifications/read-all');

  void dispose() => _client.close();
}
