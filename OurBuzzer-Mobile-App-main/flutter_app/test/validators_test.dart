import 'package:flutter_test/flutter_test.dart';
import 'package:ourbuzzer/core/validators.dart';
import 'package:ourbuzzer/models/enums.dart';
import 'package:ourbuzzer/services/google_auth_service.dart';

void main() {
  group('validateVideoUrl (meniru valid_url backend)', () {
    test('menerima domain & subdomain yang cocok', () {
      expect(validateVideoUrl('https://www.tiktok.com/@a/video/1', VideoPlatform.tiktok), isNull);
      expect(validateVideoUrl('https://vt.tiktok.com/ZS123/', VideoPlatform.tiktok), isNull);
      expect(validateVideoUrl('https://youtu.be/abc', VideoPlatform.youtube), isNull);
      expect(validateVideoUrl('https://www.threads.net/@a/post/1', VideoPlatform.threads), isNull);
    });

    test('menolak platform salah / domain palsu / tanpa path', () {
      expect(validateVideoUrl('https://instagram.com/reel/1', VideoPlatform.tiktok), isNotNull);
      expect(validateVideoUrl('https://faketiktok.com/x', VideoPlatform.tiktok), isNotNull);
      expect(validateVideoUrl('https://tiktok.com', VideoPlatform.tiktok), isNotNull);
      expect(validateVideoUrl('tiktok.com/@a/video/1', VideoPlatform.tiktok), isNotNull);
    });

    test('detectPlatform', () {
      expect(detectPlatform('https://www.instagram.com/reel/abc/'), VideoPlatform.instagram);
      expect(detectPlatform('https://example.com/x'), isNull);
    });
  });

  group('normalizeVideoUrl (meniru normalize_url backend → anti-duplikat)', () {
    test('link yang sama dengan variasi berbeda dinormalisasi sama', () {
      const a = 'https://www.tiktok.com/@ani/video/123/?is_from_webapp=1';
      const b = 'https://m.tiktok.com/@ani/video/123';
      expect(normalizeVideoUrl(a), 'https://tiktok.com/@ani/video/123');
      expect(normalizeVideoUrl(a), normalizeVideoUrl(b));
    });

    test('YouTube watch / youtu.be → shorts', () {
      expect(normalizeVideoUrl('https://www.youtube.com/watch?v=XyZ_1'), 'https://youtube.com/shorts/XyZ_1');
      expect(normalizeVideoUrl('https://youtu.be/XyZ_1'), 'https://youtube.com/shorts/XyZ_1');
    });
  });

  test('estimatePayout dibulatkan ke bawah seperti int() backend', () {
    expect(estimatePayout(12345, 10000), 123450);
    expect(estimatePayout(999, 1500), 1498);
  });

  test('pesan error login Google (Firebase) & kode batal', () {
    expect(GoogleAuthService.messageFor('popup-blocked'), contains('Popup'));
    expect(GoogleAuthService.messageFor('unauthorized-domain'), contains('Domain'));
    expect(GoogleAuthService.messageFor('kode-aneh'), contains('kode-aneh'));
    expect(GoogleAuthService.cancelCodes, containsAll(['popup-closed-by-user', 'web-context-canceled']));
  });
}
