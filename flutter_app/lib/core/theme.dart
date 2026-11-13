import 'package:flutter/material.dart';

/// Skala spasi tunggal untuk seluruh aplikasi (kelipatan 4).
/// Desain ini "lega": antar section 24–32, isi kartu 16–20.
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Padding standar konten halaman (kiri/kanan 20 agar terasa lega).
  static const page = EdgeInsets.fromLTRB(20, l, 20, xl);
  static const double gutter = 20;

  /// Padding isi kartu.
  static const card = EdgeInsets.all(l);
}

/// Radius sudut seragam — Premium Red: kontrol 14, kartu 24, header 32.
class AppRadius {
  AppRadius._();
  static const double s = 8;
  static const double m = 14; // tombol, chip, input, thumbnail
  static const double l = 24; // kartu, container, dialog
  static const double xl = 28; // kartu hero (Saldo Aktif)
  static const double header = 32; // sudut bawah header gradasi
  static const double pill = 999;
}

/// Tema global PAGI — "Premium Red" (acuan: docs/DESIGN_SYSTEM.md).
/// Merah premium + kartu putih bersudut besar berbayangan lembut di atas latar abu-abu kebiruan.
class AppTheme {
  AppTheme._();

  // ---- Palet Premium Red ----
  static const primary = Color(0xFFC8102E); // Primary Red: tombol, tab aktif, tautan, aksen
  static const primaryDark = Color(0xFFA50021); // Deep Red: awal gradasi
  static const accent = Color(0xFFF21D43); // Accent Red: kilau gradasi tombol/kartu
  static const softPink = Color(0xFFFCE5EA); // latar ikon menu, pill tab aktif, badge
  static const background = Color(0xFFF8F9FC);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF171B2B);
  static const textSecondary = Color(0xFF777B86);
  static const border = Color(0xFFE9E9EF);
  static const navInactive = Color(0xFF5B5F6B); // abu-abu gelap tab tidak aktif
  static const onBrand = Color(0xFFFFFFFF);

  // ---- Warna merek platform (ikon akun sosial) ----
  static const telegram = Color(0xFF229ED9);
  static const tiktok = Color(0xFF000000);
  static const threads = Color(0xFF000000);
  static const instagramGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFEDA75), Color(0xFFD62976), Color(0xFF4F5BD5)],
  );

  /// Alias lama (dipakai komponen yang sudah ada).
  static const primaryLight = accent;
  static const gradientEnd = Color(0xFFF7A1B1); // ujung gradasi header (pink)
  static const shadow = Color(0x12171B2B); // bayangan lembut kartu (~7%)
  static const glow = Color(0x40C8102E); // pendar merah di bawah tombol/kartu merah
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);
  static const danger = Color(0xFFEF4444);

  /// Gradasi header: Deep Red → Primary → Accent → pink (kiri-atas → kanan-bawah).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, accent, gradientEnd],
    stops: [0, 0.38, 0.72, 1],
  );

  /// Gradasi kartu hero (Saldo Aktif): merah pekat dengan kilau merah terang di kanan.
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, accent],
    stops: [0, 0.55, 1],
  );

  /// Gradasi tombol utama premium (atas terang → bawah pekat).
  static const buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary, primaryDark],
    stops: [0, 0.5, 1],
  );

  /// Bayangan lembut pengganti garis tepi (dipakai Container yang berperan sebagai kartu).
  static const softShadow = [BoxShadow(color: shadow, blurRadius: 24, offset: Offset(0, 8))];

  /// Pendar merah lembut untuk elemen merah (kartu saldo, tombol utama).
  static const glowShadow = [BoxShadow(color: glow, blurRadius: 20, offset: Offset(0, 8))];

  /// Warna putih transparan untuk ornamen gelombang di atas gradasi.
  static Color onBrandAlpha(double a) => onBrand.withValues(alpha: a);

  /// [fontFamily] null = font sistem (Roboto di Android, SF di iOS).
  static ThemeData light({String? fontFamily}) => _build(Brightness.light, fontFamily);
  static ThemeData dark({String? fontFamily}) => _build(Brightness.dark, fontFamily);

  static ThemeData _build(Brightness b, String? fontFamily) {
    final light = b == Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primary, brightness: b).copyWith(
      // Netral murni (abu-abu), tanpa rona merah otomatis dari seed di kartu & input.
      surface: light ? card : const Color(0xFF16181D),
      onSurface: light ? textPrimary : const Color(0xFFF3F4F6),
      primaryContainer: light ? softPink : const Color(0xFF4A1020),
      onPrimaryContainer: light ? primaryDark : const Color(0xFFFFD9DF),
      surfaceContainerLowest: light ? const Color(0xFFFFFFFF) : const Color(0xFF0F1115),
      surfaceContainerLow: light ? background : const Color(0xFF1C1F25),
      surfaceContainer: light ? const Color(0xFFF1F3F5) : const Color(0xFF1C1F25),
      surfaceContainerHigh: light ? const Color(0xFFE9ECEF) : const Color(0xFF262A31),
      surfaceContainerHighest: light ? const Color(0xFFE9ECEF) : const Color(0xFF30353D),
      outlineVariant: light ? border : const Color(0xFF30353D),
      onSurfaceVariant: light ? textSecondary : const Color(0xFFA1A1AA),
    );
    final bg = light ? background : const Color(0xFF0F1115);
    final inactive = light ? navInactive : const Color(0xFFA1A1AA);

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: fontFamily);
    final t = base.textTheme;
    // Hierarki: judul Bold/SemiBold, konten Regular; teks utama hitam, sekunder abu-abu.
    final text = t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      bodyMedium: t.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      bodySmall: t.bodySmall?.copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
    );
    final buttonText = TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: fontFamily);
    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m));

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpace.gutter,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: controlShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: controlShape,
          textStyle: buttonText,
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: buttonText.copyWith(fontSize: 14),
          minimumSize: const Size(48, 40),
          shape: controlShape,
        ),
      ),
      // Kartu: putih, sudut 16, bayangan lembut — tanpa garis tepi.
      cardTheme: CardThemeData(
        elevation: 4,
        color: scheme.surface,
        shadowColor: shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      ),
      chipTheme: ChipThemeData(
        shape: controlShape,
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: controlShape, backgroundColor: scheme.surface),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.l))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: shadow,
        height: 72,
        // Aktif: ikon & label merah di atas pill merah muda; tidak aktif: abu-abu gelap.
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 26,
              color: s.contains(WidgetState.selected) ? scheme.primary : inactive,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelMedium?.copyWith(
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? scheme.primary : inactive,
            )),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      ),
    );
  }
}
