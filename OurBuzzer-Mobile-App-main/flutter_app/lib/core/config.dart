/// Konfigurasi runtime. Nilai dibaca dari `--dart-define` agar tidak ada URL
/// atau kunci yang di-hardcode di source.
///
/// ```bash
/// flutter run --dart-define=BACKEND_URL=https://api.contoh.com
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL backend FastAPI (tanpa `/api` di belakang).
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8001', // localhost dari emulator Android
  );

  /// Semua endpoint backend berada di bawah prefix `/api`.
  static String get apiBase => '$backendUrl/api';

  // Login Google memakai Firebase Auth; konfigurasinya ada di
  // lib/firebase_options.dart (bukan di sini).

  static const Duration httpTimeout = Duration(seconds: 30);
}
