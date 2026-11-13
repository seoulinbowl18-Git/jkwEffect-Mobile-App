import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../services/token_storage.dart';

/// Instance tunggal [ApiService]. Override di test dengan
/// `ProviderScope(overrides: [apiServiceProvider.overrideWithValue(fake)])`.
final apiServiceProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  ref.onDispose(api.dispose);
  return api;
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Login Google via Firebase Auth. Override di test dengan service palsu.
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) => GoogleAuthService());
