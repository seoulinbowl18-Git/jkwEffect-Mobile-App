import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Rincian biaya transparan sebelum konfirmasi (top up / tarik saldo).
/// Setiap baris: (label, nominal, minus?). Baris terakhir [total] ditebalkan.
class FeeBreakdown extends StatelessWidget {
  const FeeBreakdown({super.key, required this.rows, required this.totalLabel, required this.total});

  final List<(String, int, bool)> rows;
  final String totalLabel;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget line(String label, String value, {TextStyle? style, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(label, style: style ?? t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            const SizedBox(width: AppSpace.m),
            Text(value, key: key, style: style ?? t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
    return Container(
      key: key,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Column(children: [
        for (final (label, value, minus) in rows)
          line(label, '${minus && value > 0 ? '-' : ''}${rp(value)}'),
        const Divider(height: AppSpace.l),
        line(totalLabel, rp(total),
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900), key: const Key('fee-breakdown-total')),
      ]),
    );
  }
}
