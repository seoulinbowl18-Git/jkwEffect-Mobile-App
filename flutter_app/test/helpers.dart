import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ourbuzzer/providers/auth_provider.dart';
import 'package:ourbuzzer/providers/service_providers.dart';
import 'package:ourbuzzer/services/api_service.dart';
import 'package:ourbuzzer/services/token_storage.dart';

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> save(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

typedef Handler = Object? Function(http.Request req);

/// Backend tiruan: rute `"METHOD /path"` → handler (return body JSON, atau
/// [http.Response] untuk status khusus). Semua request dicatat di [calls].
class FakeBackend {
  FakeBackend(this.routes);
  final Map<String, Handler> routes;
  final List<http.Request> calls = [];

  ApiService api() => ApiService(
        baseUrl: 'https://x/api',
        client: MockClient((req) async {
          calls.add(req);
          final key = '${req.method} ${req.url.path.replaceFirst('/api', '')}';
          final h = routes[key];
          if (h == null) return jsonResponse({'detail': 'Not Found: $key'}, 404);
          final res = h(req);
          return res is http.Response ? res : jsonResponse(res ?? {'ok': true});
        }),
      );

  /// Request terakhir ke [method] [path] (tanpa prefix /api).
  http.Request last(String method, String path) =>
      calls.lastWhere((r) => r.method == method && r.url.path == '/api$path');

  Map<String, dynamic> lastBody(String method, String path) =>
      jsonDecode(last(method, path).body) as Map<String, dynamic>;

  bool called(String method, String path) => calls.any((r) => r.method == method && r.url.path == '/api$path');
}

Map<String, dynamic> userJson({String role = 'creator', int balance = 125000, int brandBalance = 0}) => {
      'user_id': role == 'brand' ? 'brand_1' : 'user_1',
      'email': 'ani@example.com',
      'name': 'Ani Kreator',
      'role': role,
      'balance': balance,
      'total_earned': 300000,
      'brand_balance': brandBalance,
      'profile': <String, String>{'bank_method': 'DANA', 'bank_account': '081234567', 'bank_holder': 'Ani'},
    };

Map<String, dynamic> campaignJson({
  String id = 'cmp_1',
  String title = 'Review Skincare Glowing',
  List<String> platforms = const ['tiktok', 'instagram'],
  String status = 'active',
  String brandId = 'brand_1',
  int budget = 1000000,
  int spent = 250000,
  bool exclusive = false,
}) =>
    {
      'campaign_id': id,
      'brand_id': brandId,
      'brand_name': 'Glow Co',
      'title': title,
      'category': 'Beauty',
      'platforms': platforms,
      'rate_per_1k': 10000,
      'min_views': 1000,
      'budget': budget,
      'spent': spent,
      'thumbnail': '',
      'instructions': 'Buat video 30 detik tentang produk.',
      'exclusive': exclusive,
      'submission_count': 3,
      'total_views': 5000,
      'status': status,
      'deadline': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'budget_left_pct': budget == 0 ? 0 : (100 * (budget - spent) / budget).round(),
    };

Map<String, dynamic> submissionJson({
  String id = 'sub_1',
  String status = 'direview',
  String url = 'https://tiktok.com/@ani/video/1',
  int claimed = 0,
}) =>
    {
      'submission_id': id,
      'campaign_id': 'cmp_1',
      'campaign_title': 'Review Skincare Glowing',
      'creator_name': 'Ani Kreator',
      'platform': 'tiktok',
      'video_url': url,
      'status': status,
      'claimed_views': claimed,
      'verified_views': 0,
      'payout': 0,
      'rate_per_1k': 10000,
      'min_views': 1000,
      'note': '',
      'created_at': DateTime.now().toIso8601String(),
    };

/// Pasang [child] dengan sesi login aktif (token + `/auth/me`).
Future<void> pumpWithSession(
  WidgetTester tester,
  FakeBackend backend,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  // Ukuran ponsel tinggi (logis 412×1000) agar form panjang muat tanpa banyak scroll.
  tester.view
    ..devicePixelRatio = 2.5
    ..physicalSize = const Size(1030, 2500);
  addTearDown(tester.view.reset);
  // Tap yang meleset (widget di luar layar) langsung gagal, bukan cuma warning.
  WidgetController.hitTestWarningShouldBeFatal = true;
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      apiServiceProvider.overrideWithValue(backend.api()),
      tokenStorageProvider.overrideWithValue(MemoryTokenStorage('tok')),
      ...overrides,
    ],
    child: MaterialApp(home: _WaitForAuth(child: child)),
  ));
  await tester.pumpAndSettle();
}

/// Menunggu sesi termuat sebelum menampilkan layar yang diuji.
class _WaitForAuth extends ConsumerWidget {
  const _WaitForAuth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    return user != null ? child : const SizedBox.shrink();
  }
}
