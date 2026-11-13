# Aset branding

Letakkan dua file ini di folder ini, lalu jalankan generator (lihat `pubspec.yaml`):

| File | Ukuran disarankan | Isi |
|---|---|---|
| `icon.png` | 1024×1024, persegi penuh (tanpa sudut membulat/bayangan) | Ikon aplikasi: latar merah + logo putih |
| `icon_foreground.png` | 1024×1024, latar **transparan** | Logo putih saja untuk ikon adaptif Android 8+ (latar merah `#C8102E` diberi otomatis) |
| `splash.png` | 1152×1152, latar **transparan** | Logo putih saja; diletakkan di tengah layar merah `#C8102E`. Android 12+ memotongnya jadi lingkaran: jaga logo di dalam lingkaran diameter ~768 px di tengah |

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
