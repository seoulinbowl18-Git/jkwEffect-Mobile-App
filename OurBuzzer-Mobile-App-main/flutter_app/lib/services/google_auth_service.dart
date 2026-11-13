import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Error login Google yang pesannya aman ditampilkan ke user.
class GoogleSignInException implements Exception {
  const GoogleSignInException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Login Google lewat Firebase Auth (proyek di `lib/firebase_options.dart`).
///
/// - Web: popup Google (`signInWithPopup`).
/// - Android/iOS: alur Google bawaan Firebase (`signInWithProvider`).
///
/// Mengembalikan Firebase **ID token** untuk ditukar menjadi sesi jkwEffect
/// lewat `ApiService.loginWithFirebase`, atau `null` bila user membatalkan.
/// Sesi aplikasi dipegang backend, jadi user langsung di-sign-out dari
/// Firebase setelah token didapat (tidak ada dua sumber sesi).
class GoogleAuthService {
  GoogleAuthService([FirebaseAuth? auth]) : _auth = auth;

  final FirebaseAuth? _auth;

  /// Kode error Firebase yang berarti user menutup / membatalkan login.
  @visibleForTesting
  static const cancelCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'user-cancelled',
    'web-context-canceled',
    'canceled',
  };

  Future<String?> signIn() async {
    if (_auth == null && Firebase.apps.isEmpty) {
      throw const GoogleSignInException(
        'Login Google belum dikonfigurasi (Firebase belum diinisialisasi).',
      );
    }
    final auth = _auth ?? FirebaseAuth.instance;
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    try {
      final cred = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
      final token = await cred.user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw const GoogleSignInException('Login Google gagal: token tidak tersedia.');
      }
      return token;
    } on FirebaseAuthException catch (e) {
      if (cancelCodes.contains(e.code)) return null;
      throw GoogleSignInException(messageFor(e.code));
    } finally {
      // Abaikan error sign-out: tidak memengaruhi sesi backend.
      await auth.signOut().catchError((_) {});
    }
  }

  /// Pesan Bahasa Indonesia untuk kode error Firebase Auth yang umum.
  @visibleForTesting
  static String messageFor(String code) => switch (code) {
        'popup-blocked' => 'Popup login diblokir browser. Izinkan popup lalu coba lagi.',
        'network-request-failed' => 'Tidak ada koneksi internet. Coba lagi.',
        'unauthorized-domain' => 'Domain ini belum diizinkan untuk login Google di Firebase.',
        'operation-not-allowed' => 'Login Google belum diaktifkan di Firebase Console.',
        'account-exists-with-different-credential' =>
          'Email ini sudah terdaftar dengan metode login lain.',
        'user-disabled' => 'Akun Google ini dinonaktifkan.',
        _ => 'Login Google gagal ($code). Coba lagi.',
      };
}
