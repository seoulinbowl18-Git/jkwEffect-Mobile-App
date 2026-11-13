import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token sesi terenkripsi (Keychain di iOS, EncryptedSharedPreferences
/// / Keystore di Android).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // Data keystore rusak (mis. setelah restore backup) → anggap belum login.
      await clear();
      return null;
    }
  }

  Future<void> save(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
