import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ourbuzzer/models/models.dart';
import 'package:ourbuzzer/services/api_service.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  const base = 'https://api.test/api';

  test('mengirim Bearer token, body JSON, dan parse AuthSession', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: base,
      client: MockClient((req) async {
        captured = req;
        return _json({
          'user_id': 'user_1',
          'email': 'a@b.com',
          'name': 'Ani Kreator',
          'role': null,
          'balance': 0,
          'brand_balance': 0,
          'profile': {},
          'session_token': 'tok_123',
        });
      }),
    )..token = 'old';

    final s = await api.exchangeFirebaseToken('firebase-id-token');

    expect(captured.method, 'POST');
    expect(captured.url.toString(), '$base/auth/firebase');
    expect(captured.headers['Authorization'], 'Bearer old');
    expect(jsonDecode(captured.body), {'id_token': 'firebase-id-token'});
    expect(s.token, 'tok_123');
    expect(s.user.role, isNull);
    expect(s.user.hasRole, isFalse);
    expect(s.user.firstName, 'Ani');
  });

  test('query campaigns: buang nilai kosong, kirim exclusive & sort', () async {
    late Uri url;
    final api = ApiService(
      baseUrl: base,
      client: MockClient((req) async {
        url = req.url;
        return _json([
          {'campaign_id': 'cmp_1', 'title': 'Promo', 'platforms': ['tiktok', 'youtube'], 'rate_per_1k': 15000.0},
        ]);
      }),
    );

    final list = await api.campaigns(exclusive: true, sort: CampaignSort.rate);

    expect(url.path, '/api/campaigns');
    expect(url.queryParameters, {'exclusive': 'true', 'sort': 'rate'});
    expect(list.single.platforms, [VideoPlatform.tiktok, VideoPlatform.youtube]);
    expect(list.single.ratePer1k, 15000); // double dari Mongo → int
  });

  test('error detail string → ApiException dengan pesan backend', () async {
    final api = ApiService(
      baseUrl: base,
      client: MockClient((_) async => _json({'detail': 'Video ini sudah pernah didaftarkan'}, 400)),
    );
    expect(
      () => api.submitVideo(campaignId: 'c', platform: VideoPlatform.tiktok, videoUrl: 'https://tiktok.com/@a/video/1'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 400)
          .having((e) => e.message, 'message', 'Video ini sudah pernah didaftarkan')),
    );
  });

  test('error validasi 422 (list) digabung', () async {
    final api = ApiService(
      baseUrl: base,
      client: MockClient((_) async => _json({
            'detail': [
              {'msg': 'Input should be greater than or equal to 50000'},
            ]
          }, 422)),
    );
    expect(
      () => api.withdraw(amount: 1000, method: 'BCA', accountNumber: '12345', accountHolder: 'Ani'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('50000'))),
    );
  });

  test('401 dengan token memanggil onUnauthorized', () async {
    var called = false;
    final api = ApiService(baseUrl: base, client: MockClient((_) async => _json({'detail': 'Sesi kadaluarsa'}, 401)))
      ..token = 'tok'
      ..onUnauthorized = () => called = true;
    await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)));
    expect(called, isTrue);
  });

  test('gangguan jaringan → ApiException status 0', () async {
    final api = ApiService(baseUrl: base, client: MockClient((_) async => throw http.ClientException('down')));
    expect(api.me(), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', true)));
  });

  test('verifyViews mengembalikan payout; review mengirim action', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiService(
      baseUrl: base,
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return req.url.path.endsWith('/verify') ? _json({'ok': true, 'payout': 75000}) : _json({'ok': true});
      }),
    );
    await api.reviewContent('sub_1', approve: false, note: 'Tidak sesuai brief');
    final payout = await api.verifyViews('sub_1', approve: true, verifiedViews: 5000);

    expect(bodies[0], {'action': 'reject', 'note': 'Tidak sesuai brief'});
    expect(bodies[1], {'action': 'approve', 'verified_views': 5000, 'note': ''});
    expect(payout, 75000);
  });

  test('createTopup QRIS tidak mengirim channel_code; VA mengirim', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiService(
      baseUrl: base,
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return _json({'topup_id': 'TOP_1', 'amount': 100000, 'payment_type': 'qris', 'status': 'pending'});
      }),
    );
    final t = await api.createTopup(amount: 100000, paymentType: PaymentType.qris);
    await api.createTopup(amount: 100000, paymentType: PaymentType.bankTransfer, channelCode: 'BNI');

    expect(bodies[0], {'amount': 100000, 'payment_type': 'qris'});
    expect(bodies[1]['channel_code'], 'BNI');
    expect(t.isPending, isTrue);
  });

  test('closeCampaign → PATCH status closed', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: base,
      client: MockClient((req) async {
        captured = req;
        return _json({'ok': true});
      }),
    );
    await api.closeCampaign('cmp_9');
    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/campaigns/cmp_9/status');
    expect(jsonDecode(captured.body), {'status': 'closed'});
  });
}
