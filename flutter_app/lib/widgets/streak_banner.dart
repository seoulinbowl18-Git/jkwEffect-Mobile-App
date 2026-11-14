import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/stats.dart';

/// Kartu "Streak Harian": progress horizontal dengan lingkaran centang hitam
/// untuk hari yang sudah posting, garis penghubung, dan label hari di bawahnya.
class StreakBanner extends StatelessWidget {
  const StreakBanner({super.key, required this.streak});
  final Streak streak;

  static const double _dot = 32;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final days = streak.week;

    Widget dot(bool on) => Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? cs.primary : cs.surfaceContainerHigh),
          child: Icon(Icons.check_rounded, size: 18, color: on ? cs.onPrimary : cs.onSurfaceVariant),
        );
    Widget line(bool on) => Expanded(
          child: Container(height: 3, color: on ? cs.primary : cs.surfaceContainerHigh),
        );
    // Label sebesar lingkaran; mengecil bila huruf diperbesar agar tidak meluap.
    Widget label(String text) => SizedBox(
          width: _dot,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text == 'Hari ini' ? 'Ini' : text, softWrap: false, style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Text('Streak Harian', style: t.titleLarge)),
            const SizedBox(width: AppSpace.s),
            Text('Progres', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: AppSpace.xs),
          Text(
            streak.postedToday
                ? '${streak.streak} hari berturut-turut. Mantap, kamu sudah posting hari ini!'
                : '${streak.streak} hari berturut-turut. Submit video hari ini untuk jaga streak.',
            key: const Key('streak-summary'),
            style: t.bodySmall,
          ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: AppSpace.l),
            Row(children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) line(days[i - 1].posted && days[i].posted),
                dot(days[i].posted),
              ],
            ]),
            const SizedBox(height: AppSpace.s),
            Row(children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const Spacer(),
                label(days[i].label),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}
