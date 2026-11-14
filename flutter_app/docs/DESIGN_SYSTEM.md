# PAGI — Design System

Gaya: **Sleek Black — modern, elegant & professional.** Header gradasi hitam → abu gelap bersudut
bawah melengkung dengan ornamen gelombang, kartu putih bersudut besar berbayangan lembut di atas
latar abu-abu kebiruan, ikon di kotak abu muda. Acuan visual: referensi halaman Dompet & Profil.

**Semua nilai visual berasal dari `lib/core/theme.dart`.** Jangan menulis warna, ukuran font, atau
radius langsung di halaman (dijaga otomatis oleh `test/design_lint_test.dart`).

## Warna

| Token | Nilai | Dipakai untuk |
|---|---|---|
| `AppTheme.primary` | `#121212` Sleek Black | Tombol, tab aktif, tautan, ikon menu, aksen |
| `AppTheme.primaryDark` | `#0A0A0A` Jet Black | Awal gradasi |
| `AppTheme.accent` | `#1E1E1E` Charcoal | Kilau gradasi tombol & kartu |
| `AppTheme.softPink` | `#FCE5EA` (`colorScheme.primaryContainer`) | Latar ikon menu, pill tab aktif, badge "Segera", "Lihat Semua" |
| `AppTheme.background` | `#F8F9FC` | Latar semua halaman |
| `AppTheme.card` | `#FFFFFF` | Kartu, input, nav bar |
| `AppTheme.textPrimary` / `textSecondary` | `#171B2B` / `#777B86` | `onSurface` / `onSurfaceVariant` |
| `AppTheme.border` | `#E9E9EF` | Garis tepi & pemisah (`outlineVariant`) |
| `AppTheme.navInactive` | `#5B5F6B` | Tab bawah tidak aktif |
| Gradasi | `brandGradient` (header), `cardGradient` (kartu Saldo Aktif), `buttonGradient` (tombol utama) | |
| Bayangan | `softShadow` (kartu), `glowShadow` (bayangan gelap elemen hitam) | |
| Status | success `#10B981`, warning `#F59E0B`, info `#0EA5E9`, danger `#EF4444` | `StatusChip` |

## Bentuk, bayangan, spasi

- Radius (`AppRadius`): **14** kontrol/chip/input/ikon menu · **24** kartu/tombol besar/dialog ·
  **28** kartu hero (Saldo Aktif) · **32** sudut bawah header · pill untuk badge & tab aktif.
- Kartu: putih, radius 24, bayangan lembut, tanpa border.
- Spasi (`AppSpace`, kelipatan 4): gutter halaman **20**, isi kartu 16, antar blok 16–24.

## Tipografi

| Peran | Gaya |
|---|---|
| Judul header tab utama (Profil) | `headlineSmall` ExtraBold, putih (`AppHeader(tall: true)`) |
| Judul header halaman biasa | `titleLarge` 22 Bold, putih |
| Judul section | `titleLarge` Bold + garis aksen hitam (`AccentSectionTitle`) |
| Baris menu | `titleMedium` SemiBold |
| Nominal besar (saldo) | `displaySmall` ExtraBold |
| Keterangan | `bodySmall` / `bodyMedium`, abu-abu `#777B86` |

## Komponen baku (reusable)

| Komponen | File | Kegunaan |
|---|---|---|
| `AppHeader` (`tall`, `subtitle`, `actions`) | `lib/widgets/app_header.dart` | AppBar gradasi + gelombang, semua halaman |
| `GradientPanel`, `BrandWavePainter` | `lib/widgets/app_header.dart` | Header kustom & ornamen kartu hero |
| `BrandLogo` | `lib/widgets/brand_logo.dart` | Logo "P" + play, putih di atas gradasi |
| `UserAvatar` (`ring`, `badge`) | `lib/widgets/user_avatar.dart` | Avatar foto/inisial di header & kartu |
| `GradientButton` | `lib/widgets/premium.dart` | Aksi utama: gradasi hitam, ikon + label, panah |
| `OutlineActionButton` | `lib/widgets/premium.dart` | Aksi kedua: putih, garis hitam, panah |
| `IconBadge` | `lib/widgets/premium.dart` | Ikon hitam di kotak abu muda |
| `AccentSectionTitle` | `lib/widgets/premium.dart` | Judul section + pill "Lihat Semua" |
| `PremiumCard` | `lib/widgets/premium.dart` | Kartu putih radius 24 + bayangan lembut |
| `AccountMenuCard`, `MenuRow` | `lib/widgets/account_menu.dart` | Menu akun (Konten saya, Voucher, Ajak Teman, FAQ, Pengaturan, Keluar) |
| `StreakBanner`, `CampaignTile` | `lib/widgets/` | Beranda kreator |

- **Navigasi bawah** (`NavigationBar` M3): putih; aktif = ikon & label hitam tebal di atas
  **pill abu muda**; tidak aktif = abu-abu gelap. Kreator **Beranda · Jelajah · Dompet · Profil**.
- **Dompet**: header logo + avatar → kartu Saldo Aktif (gradasi, sembunyikan saldo, Total
  Pendapatan & Sedang dicek) → `GradientButton` Tarik saldo → timeline Riwayat Penarikan
  (data asli, "Lihat Semua" → daftar lengkap) → `AccountMenuCard`.
- **Profil**: header judul + avatar (ketuk = Edit profil) → kartu akun, saldo & Rekening pencairan
  → Tarik saldo / Top up → Riwayat → `AccountMenuCard`.

## Aturan responsif

- Teks panjang di `Row` → `Expanded`/`Flexible` + `maxLines`/`ellipsis`.
- Nominal & judul → `FittedBox(fit: BoxFit.scaleDown)`.
- Tinggi daftar horizontal mengikuti skala huruf (`MediaQuery.textScalerOf`).
- Wajib aman di 360×640, 393×852, 430×932, dan 360×640 dengan huruf 130%.

## Pengaman otomatis (ikut `flutter test`)

| Test | Menjaga |
|---|---|
| `test/design_lint_test.dart` | Tidak ada `Color(0x…)`, `Colors.x`, `fontSize:`, atau radius angka di luar `theme.dart` (pengecualian: `// design-ok: alasan`) |
| `test/screenshots/screenshot_test.dart` | 20 halaman × 4 ukuran layar; gagal bila ada overflow / error layout |

```bash
flutter test test/screenshots --dart-define=SCREENSHOT_DIR=build/screenshots
```
