// Konfigurasi Firebase per platform.
//
// Web     -> proyek `newourbuzzer` (292443509199). appId & apiKey Web App
//            dibaca dari --dart-define:
//
//   flutter run -d chrome --web-port 5000 //     --dart-define=BACKEND_URL=http://localhost:8001 //     --dart-define=FIREBASE_WEB_APP_ID=1:292443509199:web:... //     --dart-define=FIREBASE_WEB_API_KEY=AIza...
//
// Android -> SEMENTARA masih proyek `ourbuzzer-951b4` (283209495186),
//            sesuai android/app/google-services.json. Untuk menyamakan dengan
//            web, unduh google-services.json dari proyek `newourbuzzer`
//            (package com.ourbuzzer.app), ganti file tersebut, lalu perbarui
//            nilai `android` di bawah (atau jalankan
//            `flutterfire configure --project=newourbuzzer`).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const String _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');

  /// `true` bila Web App sudah dikonfigurasi lewat --dart-define.
  static bool get isWebConfigured => _webAppId.isNotEmpty && _webApiKey.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (!isWebConfigured) {
        throw UnsupportedError(
          'Firebase Web belum dikonfigurasi. Isi FIREBASE_WEB_APP_ID dan '
          'FIREBASE_WEB_API_KEY lewat --dart-define (lihat lib/firebase_options.dart).',
        );
      }
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk $defaultTargetPlatform. '
          'Jalankan `flutterfire configure` untuk menambah platform ini.',
        );
    }
  }

  /// Proyek `newourbuzzer`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: '292443509199',
    projectId: 'newourbuzzer',
    authDomain: 'newourbuzzer.firebaseapp.com',
  );

  /// Proyek `ourbuzzer-951b4` (sementara, lihat catatan di atas).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC__rMmB7sz-C5eIsFmw2amlPy6sHQX9G0',
    appId: '1:283209495186:android:2e264135c0c46702152c4b',
    messagingSenderId: '283209495186',
    projectId: 'ourbuzzer-951b4',
    storageBucket: 'ourbuzzer-951b4.firebasestorage.app',
  );
}
