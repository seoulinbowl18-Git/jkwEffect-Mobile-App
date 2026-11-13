import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/firebase_google_auth_service.dart';
import '../services/image_picker_service.dart';
import '../services/token_storage.dart';

/// Instance tunggal [ApiService]. Override di test dengan
/// `ProviderScope(overrides: [apiServiceProvider.overrideWithValue(fake)])`.
final apiServiceProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  ref.onDispose(api.dispose);
  return api;
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Login Google via Firebase. Dibuat saat pertama dipakai (bukan saat app start),
/// dan bisa di-override di test dengan implementasi tiruan.
final firebaseGoogleAuthProvider = Provider<GoogleFirebaseAuth>((ref) => FirebaseGoogleAuthService());

final imagePickerServiceProvider = Provider<ImagePickerService>((ref) => const ImagePickerService());
