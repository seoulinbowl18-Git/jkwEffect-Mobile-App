import 'package:flutter/material.dart';

/// Logo PAGI: huruf "b" dengan tombol putar di lengkungnya (kreator video).
/// [onDark] = versi putih di atas header gradasi merah.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.showName = false, this.onDark = false});
  final double size;
  final bool showName;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onDark ? cs.onPrimary : cs.primary;
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(color)),
    );
    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAGI',
              style: TextStyle(
                color: onDark ? cs.onPrimary : null,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.6, // design-ok: logo proporsional
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
            SizedBox(height: size * 0.06),
            Text(
              'Pasukan Gibran Indonesia',
              style: TextStyle(
                color: onDark ? cs.onPrimary.withValues(alpha: 0.85) : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: (size * 0.3).clamp(10.0, 18.0), // design-ok: logo proporsional, min 10 agar terbaca
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final stroke = w * 0.19;
    final fill = Paint()..color = color;
    final center = Offset(w * 0.56, h * 0.6);
    final r = w * 0.3;
    // Batang "b".
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.07, h * 0.02, stroke, center.dy - h * 0.02), Radius.circular(stroke / 2)),
      fill,
    );
    // Lengkung "b".
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // Tombol putar di tengah lengkung.
    final t = r * 0.62;
    final tri = Path()
      ..moveTo(center.dx - t * 0.42, center.dy - t * 0.58)
      ..lineTo(center.dx + t * 0.62, center.dy)
      ..lineTo(center.dx - t * 0.42, center.dy + t * 0.58)
      ..close();
    canvas.drawPath(tri, fill);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
