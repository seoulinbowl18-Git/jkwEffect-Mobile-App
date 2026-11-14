# PAGI Mobile (Flutter)

Aplikasi mobile Flutter untuk platform creator marketing bayar-per-views.
Memakai **backend FastAPI yang sama** dengan versi web & Expo (`../backend/server.py`, prefix `/api`).

## Menjalankan

```bash
flutter pub get
flutter run --dart-define=BACKEND_URL=https://jkweffect-mobile-app-production.up.railway.app
```

`BACKEND_URL` default: build release → `https://jkweffect-mobile-app-production.up.railway.app` (backend produksi PAGI); build debug → `http://10.0.2.2:8001` (backend lokal dari emulator Android; http hanya diizinkan di build debug).

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
│   ├── config.dart           BACKEND_URL, URL Google auth, callback scheme `ourbuzzer://`
│   ├── constants.dart        Aturan bisnis (min withdraw 50rb, kategori, kanal VA)
│   ├── format.dart           rp(), fmtNum(), fmtDate(), daysLeft()
│   ├── validators.dart       Validasi link video & normalisasi anti-duplikat (meniru backend)
│   └── theme.dart            Tema Material 3 (#FF5500) — tempat poles styling
├── models/                   User, Campaign, Submission, Withdrawal, Topup, stats, enums status
├── services/
│   ├── api_service.dart      ★ SEMUA komunikasi HTTP ke backend (ganti di sini saat ke Supabase)
│   ├── token_storage.dart    flutter_secure_storage (Keychain / Keystore)
│   └── firebase_google_auth_service.dart  Google Sign-In → Firebase Auth → Firebase ID token
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
│   ├── admin/                    Ringkasan platform, persetujuan withdraw
│   └── common/                   Notifikasi, Profil, Edit profil & rekening
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

- **Google (Firebase)**: tombol *Masuk dengan Google* → `google_sign_in` (Credential Manager) →
  `FirebaseAuth.signInWithCredential` → **Firebase ID token** dikirim ke `POST /api/auth/firebase`.
  Backend memverifikasi token (RS256 + `aud`/`iss` = `FIREBASE_PROJECT_ID`, belum kedaluwarsa,
  provider `google.com`, email terverifikasi), membuat/menemukan user di MongoDB, lalu mengembalikan
  `session_token` yang disimpan di secure storage dan dikirim sebagai `Authorization: Bearer <token>`.
  Logout menghapus sesi backend dan keluar dari Firebase/Google.
- **Email**: `POST /api/auth/register` dan `POST /api/auth/login` (bcrypt, password 8–72 karakter,
  batas percobaan gagal → 429). Responsnya sama dengan login Google, jadi alur onboarding identik.
  Email yang terdaftar lewat Google harus tetap masuk dengan Google.

## Firebase

**Wajib agar Google Sign-In jalan di Android:**
1. Firebase Console → *Authentication* → *Sign-in method* → aktifkan **Google**.
2. Firebase Console → *Project settings* → aplikasi Android `com.ourbuzzer.app` → *Add fingerprint*:
   tambahkan **SHA-1** debug (`cd android && ./gradlew signingReport`) dan SHA-1 release / Play App Signing.
3. Unduh ulang `google-services.json` → ganti `android/app/google-services.json`
   (setelah SHA-1 ditambahkan, file berisi OAuth client Android `client_type: 1`).
4. Backend: env var `FIREBASE_PROJECT_ID=jkweffect`.


- Package Android: **`com.ourbuzzer.app`** (harus sama dengan yang didaftarkan di Firebase Console).
- Taruh file konfigurasi di **`android/app/google-services.json`**. Tanpa file ini build Android
  gagal dengan pesan `File google-services.json is missing`.
- Plugin Gradle `com.google.gms.google-services` dipasang di `android/settings.gradle.kts` dan
  `android/app/build.gradle.kts`; `Firebase.initializeApp()` dipanggil di `lib/main.dart`.
- iOS (nanti): daftarkan bundle ID `com.ourbuzzer.app`, taruh `ios/Runner/GoogleService-Info.plist`,
  atau jalankan `flutterfire configure` untuk membuat `lib/firebase_options.dart`.

## Backend: Komerce, upload & env

Salin `backend/.env.example` → `backend/.env` (atau isi sebagai env var di hosting) lalu **restart backend**:

| Variabel | Fungsi |
|---|---|
| `MONGO_URL`, `DB_NAME` | MongoDB Atlas |
| `KOMERCE_BASE_URL`, `KOMERCE_API_KEY` | Pembayaran Komerce. Kosong → top up ditolak "Pembayaran Komerce belum dikonfigurasi" dan aplikasi menampilkan banner. |
| `PUBLIC_BASE_URL` | URL publik backend. Dipakai untuk `callback_url` Komerce dan URL gambar upload. |
| `KOMERCE_RECONCILE_SECONDS` | Interval cek otomatis top up pending di server (default 60, 0 = mati). |

Saldo brand bertambah lewat tiga jalur yang semuanya mengonfirmasi ulang ke Komerce dan hanya mengkredit sekali:
callback Komerce, tombol/polling "Cek status" di aplikasi, dan rekonsiliasi berkala di server.

Thumbnail campaign diunggah ke `POST /api/uploads` (JPG/PNG/WebP, maks. 2 MB, disimpan di MongoDB)
dan disajikan dari `GET /api/uploads/{id}`.

## Desain & screenshot

**Acuan: [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md)** — Material 3 modern & clean: hitam `#121212`,
header gradasi hitam → abu gelap, kartu putih berbayangan lembut di atas `#F8F9FA`, radius 12–16.

- Beranda kreator vs gambar referensi: `docs/screenshots/beranda_vs_referensi.png`.
- Lembar screenshot: `docs/screenshots/` (6 halaman utama) dan `docs/screenshots/halaman_lain/`,
  di 360×640, 393×852, 430×932, dan 360×640 dengan huruf 130%.
- `flutter test` otomatis menjalankan design lint + cek overflow 20 halaman × 4 ukuran.

  ```bash
  flutter test test/screenshots --dart-define=SCREENSHOT_DIR=build/screenshots
  ```

## Tahap berikutnya

- Admin: verifikasi submission & tambah saldo brand manual (endpoint sudah ada).
- Poles styling di `core/theme.dart`.
