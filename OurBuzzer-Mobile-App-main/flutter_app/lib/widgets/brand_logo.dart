import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.showName = false});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text('B',
          style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w900, fontSize: size * 0.55)),
    );
    if (!showName) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 10),
      Text('jkwEffect',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.55, letterSpacing: -0.5)),
    ]);
  }
}
