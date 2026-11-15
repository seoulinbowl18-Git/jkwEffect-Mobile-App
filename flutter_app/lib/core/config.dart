/// Konfigurasi runtime. Nilai dibaca dari `--dart-define` agar tidak ada URL
/// atau kunci yang di-hardcode di source.
///
/// ```bash
/// flutter run --dart-define=BACKEND_URL=https://api.contoh.com
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL backend FastAPI (tanpa `/api` di belakang).
  /// Tanpa `--dart-define=BACKEND_URL`: build release memakai backend produksi GIBRAN2029,
  /// build debug memakai backend lokal dari emulator Android.
  static const String productionBackendUrl = 'https://jkweffect-mobile-app-production.up.railway.app';
  static const String _definedBackendUrl = String.fromEnvironment('BACKEND_URL');
  static const String backendUrl = _definedBackendUrl != ''
      ? _definedBackendUrl
      : (bool.fromEnvironment('dart.vm.product') ? productionBackendUrl : 'http://10.0.2.2:8001');

  /// Semua endpoint backend berada di bawah prefix `/api`.
  static String get apiBase => '$backendUrl/api';

  /// URL gambar dari backend bisa relatif (`/api/uploads/...`) → jadikan absolut.
  static String resolveUrl(String url) => url.startsWith('/') ? '$backendUrl$url' : url;

  /// Nomor WhatsApp admin untuk tombol "Hubungi Kami" (mode Saya Brand).
  /// `--dart-define=CONTACT_WHATSAPP=081234567890` (format bebas, dinormalisasi ke 62…).
  static const String _contactWhatsapp = String.fromEnvironment('CONTACT_WHATSAPP');

  static String get contactWhatsapp => normalizeWhatsapp(_contactWhatsapp);

  /// '0812-3456 7890' / '+62 812…' / '812…' → '62812…' ('' bila kosong).
  static String normalizeWhatsapp(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    if (d.startsWith('0')) return '62${d.substring(1)}';
    if (d.startsWith('8')) return '62$d';
    return d;
  }

  static const String brandContactMessage =
      'Halo Admin GIBRAN2029, saya dari brand ... dan ingin daftar & konsultasi untuk membuat campaign '
      'di GIBRAN2029. Mohon info lebih lanjut, terima kasih!';

  /// `https://wa.me/<nomor>?text=<pesan>`, atau `null` bila nomor belum diatur.
  static Uri? whatsappUri([String message = brandContactMessage]) => whatsappUriFor(contactWhatsapp, message);

  static Uri? whatsappUriFor(String number, [String message = brandContactMessage]) {
    final n = normalizeWhatsapp(number);
    return n.isEmpty ? null : Uri.https('wa.me', '/$n', {'text': message});
  }

  /// Versi aplikasi yang ditampilkan di Pengaturan (samakan dengan `version` di pubspec.yaml).
  static const String appVersion = '1.0.0';

  static const Duration httpTimeout = Duration(seconds: 30);
}
