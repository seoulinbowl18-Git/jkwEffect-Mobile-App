import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  // Wajib sebelum memanggil plugin native (Firebase, secure storage, dll.).
  WidgetsFlutterBinding.ensureInitialized();

  // Android: konfigurasi dibaca dari android/app/google-services.json melalui
  // plugin Gradle com.google.gms.google-services.
  // iOS: butuh ios/Runner/GoogleService-Info.plist, atau jalankan
  // `flutterfire configure` lalu ganti menjadi
  // `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
  await Firebase.initializeApp();

  await initializeDateFormatting('id_ID');

  runApp(
    // Retry otomatis Riverpod dimatikan: error API ditampilkan ke user
    // (dengan tombol "Coba lagi") alih-alih diulang diam-diam.
    ProviderScope(retry: (_, _) => null, child: const OurBuzzerApp()),
  );
}
