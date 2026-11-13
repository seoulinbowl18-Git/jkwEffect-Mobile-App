import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Wajib sebelum memanggil plugin native (Firebase, secure storage, dll.).
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi proyek Firebase sendiri (lihat lib/firebase_options.dart).
  // Web dilewati bila FIREBASE_WEB_APP_ID / FIREBASE_WEB_API_KEY belum diisi
  // lewat --dart-define, supaya app tetap tampil (bukan layar putih).
  if (!kIsWeb || DefaultFirebaseOptions.isWebConfigured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      // Jangan sampai konfigurasi Firebase yang kurang membuat app tidak tampil.
      debugPrint('Firebase.initializeApp gagal: $e\n$st');
    }
  } else {
    debugPrint('Firebase Web dilewati: FIREBASE_WEB_APP_ID/FIREBASE_WEB_API_KEY belum diisi.');
  }

  await initializeDateFormatting('id_ID');

  runApp(
    // Retry otomatis Riverpod dimatikan: error API ditampilkan ke user
    // (dengan tombol "Coba lagi") alih-alih diulang diam-diam.
    ProviderScope(retry: (_, _) => null, child: const OurBuzzerApp()),
  );
}
