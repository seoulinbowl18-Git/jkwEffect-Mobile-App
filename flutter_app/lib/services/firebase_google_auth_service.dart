import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Error alur login (bukan dari backend) dengan pesan siap tampil.
class AuthFlowException implements Exception {
  const AuthFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Kontrak login Google → Firebase. Dipisah dari implementasi agar bisa
/// diganti tiruan di test (lihat `firebaseGoogleAuthProvider`).
abstract class GoogleFirebaseAuth {
  /// Tampilkan pemilih akun Google, masuk ke Firebase, dan kembalikan
  /// **Firebase ID token** untuk dikirim ke backend (`POST /api/auth/firebase`).
  /// `null` bila user membatalkan.
  Future<String?> signInAndGetIdToken();

  /// Keluar dari Firebase dan Google (agar pemilih akun muncul lagi).
  Future<void> signOut();
}

/// Implementasi nyata: google_sign_in v7 (Credential Manager di Android) +
/// firebase_auth.
///
/// Android: client ID dibaca otomatis dari `android/app/google-services.json`
/// (butuh entri OAuth client web — sudah ada — DAN sidik jari SHA-1 aplikasi
/// terdaftar di Firebase Console, kalau tidak login gagal/terbatal).
class FirebaseGoogleAuthService implements GoogleFirebaseAuth {
  FirebaseGoogleAuthService({FirebaseAuth? auth, GoogleSignIn? google})
      : _authOverride = auth,
        _googleOverride = google;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleOverride;

  // Diambil saat dipakai (bukan di constructor) agar tidak error bila Firebase
  // belum di-initialize, mis. saat logout di lingkungan test.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _google => _googleOverride ?? GoogleSignIn.instance;
  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _google.initialize();

  @override
  Future<String?> signInAndGetIdToken() async {
    try {
      await _ensureInitialized();
      final account = await _google.authenticate();
      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null) {
        throw const AuthFlowException('Google tidak mengirim token login. Coba lagi.');
      }
      final result = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: googleIdToken));
      final firebaseIdToken = await result.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const AuthFlowException('Firebase tidak mengirim token login. Coba lagi.');
      }
      return firebaseIdToken;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const AuthFlowException(
            'Login Google belum dikonfigurasi untuk aplikasi ini '
            '(periksa SHA-1 di Firebase Console).',
          );
        default:
          throw AuthFlowException('Login Google gagal: ${e.description ?? e.code.name}');
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(switch (e.code) {
        'network-request-failed' => 'Tidak ada koneksi internet',
        'user-disabled' => 'Akun ini dinonaktifkan',
        'operation-not-allowed' => 'Login Google belum diaktifkan di Firebase Authentication',
        _ => 'Login Firebase gagal: ${e.message ?? e.code}',
      });
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _ensureInitialized();
      await _google.signOut();
    } catch (_) {}
  }
}
