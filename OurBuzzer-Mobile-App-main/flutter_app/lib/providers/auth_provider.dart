import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'service_providers.dart';

/// Sumber kebenaran sesi.
///
/// - `AsyncLoading`  → cek token tersimpan (splash)
/// - `AsyncData(null)` → belum login (LoginView)
/// - `AsyncData(user)` & `user.role == null` → OnboardingView (pilih peran)
/// - `AsyncData(user)` & punya peran → HomeShell sesuai peran
/// - `AsyncError` → gagal menghubungi server saat startup (tampilkan retry)
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<User?> build() async {
    final api = _api;
    // Token ditolak server (401) di request mana pun → logout lokal.
    api.onUnauthorized = () => unawaited(_clearLocal());

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || token.isEmpty) return null;
    api.token = token;
    try {
      return await api.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearLocal(updateState: false);
        return null;
      }
      rethrow; // jaringan / server error → AsyncError, token tetap disimpan
    }
  }

  /// Login Google via Firebase Auth. Return `false` bila user membatalkan.
  Future<bool> signInWithGoogle() async {
    final idToken = await ref.read(googleAuthServiceProvider).signIn();
    if (idToken == null) return false;
    await _startSession(await _api.loginWithFirebase(idToken));
    return true;
  }

  Future<void> signInWithEmail(String email, String password) async =>
      _startSession(await _api.loginWithEmail(email, password));

  Future<void> registerWithEmail(String name, String email, String password) async =>
      _startSession(await _api.registerWithEmail(name, email, password));

  /// Pilih peran setelah login pertama (Kreator / Brand). Tidak bisa diubah.
  Future<void> chooseRole(UserRole role, {String? brandName}) async {
    state = AsyncData(await _api.setRole(role, brandName: brandName));
  }

  /// Muat ulang data user (saldo dsb.) — panggil setelah transaksi.
  Future<void> refreshUser() async {
    try {
      state = AsyncData(await _api.me());
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
    }
  }

  /// Ganti data user lokal tanpa request (mis. hasil `updateProfile`).
  void setUser(User user) => state = AsyncData(user);

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Tetap logout lokal walau server tidak bisa dihubungi.
    }
    await _clearLocal();
  }

  /// Coba lagi setelah startup gagal karena jaringan.
  void retry() => ref.invalidateSelf();

  Future<void> _startSession(AuthSession session) async {
    if (session.token.isEmpty) {
      throw const ApiException(500, 'Server tidak mengirim token sesi');
    }
    await ref.read(tokenStorageProvider).save(session.token);
    _api.token = session.token;
    state = AsyncData(session.user);
  }

  Future<void> _clearLocal({bool updateState = true}) async {
    _api.token = null;
    await ref.read(tokenStorageProvider).clear();
    if (updateState && ref.mounted) state = const AsyncData(null);
  }
}

/// Shortcut user yang sedang login (null bila belum / sedang loading).
final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider).value);
