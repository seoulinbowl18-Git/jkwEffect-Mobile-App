# jkwEffect Mobile (Flutter)

Aplikasi mobile Flutter untuk platform creator marketing bayar-per-views.
Memakai **backend FastAPI yang sama** dengan versi web & Expo (`../backend/server.py`, prefix `/api`).

## Menjalankan

```bash
flutter pub get
flutter run --dart-define=BACKEND_URL=https://<host-backend>
```

`BACKEND_URL` default: `http://10.0.2.2:8001` (backend lokal dari emulator Android; http hanya diizinkan di build debug).

Test & lint:

```bash
flutter analyze && flutter test
```

## Arsitektur

State management: **Riverpod 3** (`flutter_riverpod`, tanpa code-gen).

```
lib/
├── main.dart                 ProviderScope + init locale id_ID
├── app.dart                  MaterialApp + AuthGate (login → onboarding → home per peran)
├── core/
│   ├── config.dart           BACKEND_URL
│   ├── constants.dart        Aturan bisnis (min withdraw 50rb, kategori, kanal VA)
│   ├── format.dart           rp(), fmtNum(), fmtDate(), daysLeft()
│   ├── validators.dart       Validasi link video & normalisasi anti-duplikat (meniru backend)
│   └── theme.dart            Tema Material 3 (#FF5500) — tempat poles styling
├── models/                   User, Campaign, Submission, Withdrawal, Topup, stats, enums status
├── services/
│   ├── api_service.dart      ★ SEMUA komunikasi HTTP ke backend (ganti di sini saat ke Supabase)
│   ├── token_storage.dart    flutter_secure_storage (Keychain / Keystore)
│   └── google_auth_service.dart  Google login via Firebase Auth
├── providers/
│   ├── service_providers.dart    ApiService / storage (bisa di-override saat test)
│   ├── auth_provider.dart        AuthNotifier: sesi, login, pilih peran, logout, auto-logout 401
│   ├── data_providers.dart       FutureProvider per fitur (Cari Cuan, konten, dompet, brand, notif)
│   └── refresh.dart              refreshCreatorData / refreshBrandData setelah transaksi
├── views/
│   ├── auth/                     Login (Google + email), Onboarding (pilih peran)
│   ├── home/home_shell.dart      Bottom nav per peran (tab dipertahankan dgn IndexedStack)
│   ├── creator/                  Cari Cuan, Submit video, Konten (klaim views), Dompet, Withdraw
│   ├── brand/                    Beranda, Buat campaign, aksi jeda/lanjut/tutup, Review,
│   │                             Saldo, Top up + layar pembayaran QRIS/VA (polling 5 dtk)
│   ├── campaign/                 Detail campaign (dipakai kreator & brand)
│   └── common/                   Notifikasi, Profil
└── widgets/                  CampaignCard, SubmissionCard, StatusChip, StreakBanner, BellButton,
                              LoadingButton, AsyncView, dialog & helper form
```

## Alur status (sama dengan backend)

| Submission (`status`) | Label UI | Aksi |
|---|---|---|
| `direview` | Direview | Brand: `reviewContent(approve/reject)` |
| `menunggu_views` | Disetujui · Klaim views | Kreator: `claimViews(views ≥ min_views)` |
| `diproses` / `verifying` | Dicek views | Brand: `verifyViews(verifiedViews)` → bayar kreator |
| `disetujui` | Selesai | — |
| `ditolak` | Ditolak | — |

Campaign: `active` ⇄ `paused` → `closed` (sisa budget dikembalikan ke saldo brand, submission terbuka ditolak otomatis).

## Catatan auth

- **Google**: login lewat **Firebase Auth** (popup di web, `signInWithProvider` di Android/iOS).
  Firebase ID token dikirim ke `POST /api/auth/firebase {id_token}`; backend memverifikasi tanda tangan
  dan `aud`/`iss` sesuai `FIREBASE_PROJECT_ID`, lalu mengembalikan `session_token` yang disimpan di
  secure storage dan dikirim sebagai `Authorization: Bearer <token>`.
- **Email**: `POST /api/auth/register` dan `POST /api/auth/login` (bcrypt, password 8–72 karakter,
  batas percobaan gagal → 429). Responsnya sama dengan login Google, jadi alur onboarding identik.
  Email yang terdaftar lewat Google harus tetap masuk dengan Google.

## Firebase

- Package Android: **`com.ourbuzzer.app`** (harus sama dengan yang didaftarkan di Firebase Console).
- Taruh file konfigurasi di **`android/app/google-services.json`**. Tanpa file ini build Android
  gagal dengan pesan `File google-services.json is missing`.
- Plugin Gradle `com.google.gms.google-services` dipasang di `android/settings.gradle.kts` dan
  `android/app/build.gradle.kts`; `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  dipanggil di `lib/main.dart`.
- Web: proyek `newourbuzzer`. Isi `FIREBASE_WEB_APP_ID` dan `FIREBASE_WEB_API_KEY` lewat `--dart-define`
  (lihat `lib/firebase_options.dart`). Backend harus memakai `FIREBASE_PROJECT_ID` yang sama.
- iOS (nanti): daftarkan bundle ID `com.ourbuzzer.app`, lalu jalankan `flutterfire configure`.

## Tahap berikutnya

- Edit profil & data rekening (endpoint `PUT /users/profile` sudah ada di `ApiService.updateProfile`).
- Upload thumbnail campaign (sekarang berupa URL gambar).
- Admin (approve withdraw) tetap di versi web.
- Poles styling di `core/theme.dart`.
