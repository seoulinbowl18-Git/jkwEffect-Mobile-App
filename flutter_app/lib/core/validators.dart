import '../models/enums.dart';

/// Validasi sisi klien yang meniru `valid_url()` di backend. Backend tetap
/// menjadi sumber kebenaran — ini hanya agar user mendapat pesan lebih cepat.
const Map<VideoPlatform, List<String>> _platformDomains = {
  VideoPlatform.tiktok: ['tiktok.com'],
  VideoPlatform.instagram: ['instagram.com'],
  VideoPlatform.threads: ['threads.net', 'threads.com'],
  VideoPlatform.youtube: ['youtube.com', 'youtu.be'],
  VideoPlatform.facebook: ['facebook.com', 'fb.com', 'fb.watch'],
};

final _urlRe = RegExp(r'^https?://([^/]+)/\S+$');

/// `null` jika valid, selain itu pesan error (Bahasa Indonesia).
String? validateVideoUrl(String url, VideoPlatform platform) {
  final m = _urlRe.firstMatch(url.trim());
  if (m == null) return 'Masukkan link video lengkap (https://...)';
  final host = m.group(1)!.toLowerCase().split(':').first;
  final ok = _platformDomains[platform]!
      .any((d) => host == d || host.endsWith('.$d'));
  return ok ? null : 'Link bukan link ${platform.label} yang valid';
}

/// Tebak platform dari link yang ditempel (untuk auto-select chip platform).
VideoPlatform? detectPlatform(String url) {
  for (final p in VideoPlatform.values) {
    if (validateVideoUrl(url, p) == null) return p;
  }
  return null;
}

/// Meniru `normalize_url()` backend — dipakai untuk mendeteksi duplikat lokal
/// (backend tetap menolak dengan "Video ini sudah pernah didaftarkan").
String normalizeVideoUrl(String url) {
  final m = RegExp(r'^(https?)://([^/?#]+)([^?#]*)').firstMatch(url.trim());
  if (m == null) return url.trim();
  var host = m.group(2)!.toLowerCase().split(':').first;
  for (final pre in ['www.', 'm.', 'vm.', 'vt.']) {
    if (host.startsWith(pre)) {
      host = host.substring(pre.length);
      break;
    }
  }
  var path = m.group(3)!;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (host == 'youtube.com' && path == '/watch') {
    final v = RegExp(r'[?&]v=([\w-]+)').firstMatch(url);
    if (v != null) return 'https://youtube.com/shorts/${v.group(1)}';
  }
  if (host == 'youtu.be') return 'https://youtube.com/shorts$path';
  return 'https://$host$path';
}

/// Estimasi pendapatan: `views / 1000 * rate_per_1k` (dibulatkan ke bawah,
/// sama dengan `int(...)` di backend).
int estimatePayout(int views, int ratePer1k) => (views / 1000 * ratePer1k).floor();
