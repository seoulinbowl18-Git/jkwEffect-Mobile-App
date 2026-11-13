import 'package:flutter/material.dart';

import '../models/stats.dart';

/// Banner streak harian + 7 hari terakhir.
class StreakBanner extends StatelessWidget {
  const StreakBanner({super.key, required this.streak});
  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.local_fire_department_rounded, color: cs.primary, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${streak.streak} hari streak',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.onPrimaryContainer)),
                Text(
                  streak.postedToday ? 'Mantap! Kamu sudah posting hari ini.' : 'Submit video hari ini untuk jaga streak.',
                  style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13),
                ),
              ]),
            ),
          ]),
          if (streak.week.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in streak.week)
                  Column(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: d.posted ? cs.primary : cs.surface,
                      child: d.posted ? Icon(Icons.check, size: 14, color: cs.onPrimary) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(d.label == 'Hari ini' ? 'Ini' : d.label,
                        style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
                  ]),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}
