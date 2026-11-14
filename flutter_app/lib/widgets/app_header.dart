import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Ornamen gelombang putih transparan di atas gradasi (header & kartu hero),
/// memberi kesan premium tanpa gambar.
class BrandWavePainter extends CustomPainter {
  const BrandWavePainter({this.strength = 1});

  /// Pengali opasitas (1 = header, lebih kecil untuk kartu).
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final low = Path()
      ..moveTo(w * 0.30, h)
      ..cubicTo(w * 0.55, h * 0.55, w * 0.78, h * 0.62, w, h * 0.18)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(low, Paint()..color = AppTheme.onBrandAlpha(0.10 * strength));
    final high = Path()
      ..moveTo(w * 0.52, 0)
      ..cubicTo(w * 0.66, h * 0.42, w * 0.86, h * 0.50, w, h * 0.40)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(high, Paint()..color = AppTheme.onBrandAlpha(0.07 * strength));
    // Garis kilau tipis mengikuti gelombang bawah.
    final shine = Path()
      ..moveTo(w * 0.38, h * 0.98)
      ..cubicTo(w * 0.60, h * 0.60, w * 0.80, h * 0.66, w, h * 0.26);
    canvas.drawPath(
      shine,
      Paint()
        ..color = AppTheme.onBrandAlpha(0.22 * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(BrandWavePainter old) => old.strength != strength;
}

/// Panel bergradasi merah → pink bersudut bawah melengkung + ornamen gelombang
/// (header semua halaman, Beranda, Login).
class GradientPanel extends StatelessWidget {
  const GradientPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.bottomRadius = AppRadius.header,
    this.ornament = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;
  final bool ornament;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
        ),
        child: CustomPaint(
          painter: ornament ? const BrandWavePainter() : null,
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// AppBar standar semua halaman: gradasi merah, judul & ikon putih, sudut bawah melengkung.
///
/// [tall] = header besar (halaman tab utama: Dompet, Profil) dengan judul lebih
/// besar dan ruang untuk avatar; [subtitle] = baris kecil di bawah judul.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, this.title, this.subtitle, this.actions, this.tall = false});

  final Widget? title;
  final Widget? subtitle;
  final List<Widget>? actions;
  final bool tall;

  static const double _base = kToolbarHeight + AppSpace.s;
  static const double _tallHeight = 92;

  double get _height => tall ? _tallHeight : _base;

  @override
  Size get preferredSize => Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBrand = theme.colorScheme.onPrimary;
    final titleStyle = tall
        ? theme.textTheme.headlineSmall?.copyWith(color: onBrand, fontWeight: FontWeight.w800, letterSpacing: -0.3)
        : theme.appBarTheme.titleTextStyle?.copyWith(color: onBrand);
    Widget? head = title;
    if (title != null && subtitle != null) {
      head = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        title!,
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.onBrandAlpha(0.88)),
          child: subtitle!,
        ),
      ]);
    }
    return AppBar(
      toolbarHeight: _height,
      title: head,
      actions: actions == null ? null : [...actions!, const SizedBox(width: AppSpace.m)],
      backgroundColor: Colors.transparent,
      foregroundColor: onBrand,
      titleTextStyle: titleStyle,
      systemOverlayStyle: SystemUiOverlayStyle.light, // ikon status bar putih di atas gradasi
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.header))),
      clipBehavior: Clip.antiAlias,
      flexibleSpace: const GradientPanel(child: SizedBox.expand()),
    );
  }
}
