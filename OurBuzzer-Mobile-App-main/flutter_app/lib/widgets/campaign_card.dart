import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'platform_badge.dart';
import 'status_chip.dart';

/// Kartu campaign. [compact] = ukuran kartu di baris horizontal section banner.
class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.campaign, required this.onTap, this.compact = false, this.showStatus = false});

  final Campaign campaign;
  final VoidCallback onTap;
  final bool compact;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final left = daysLeft(c.deadline);

    final body = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: Text(c.brandName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
            if (showStatus) StatusChip(c.status.label, c.status.tone) else PlatformIcons(c.platforms),
          ]),
          const SizedBox(height: 4),
          Text(c.title,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${rp(c.ratePer1k)} / 1K views',
              style: t.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: c.budgetLeftPct / 100, minHeight: 6),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('Sisa budget ${c.budgetLeftPct}%', style: t.bodySmall)),
            Text(left == 0 ? 'Hari terakhir' : '$left hari lagi', style: t.bodySmall),
          ]),
        ],
      ),
    );

    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.thumbnail.isNotEmpty)
              AspectRatio(
                aspectRatio: compact ? 16 / 9 : 21 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(
                    c.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Wrap(spacing: 4, children: [
                      _Tag(c.category),
                      if (c.exclusive) const _Tag('Exclusive', highlight: true),
                    ]),
                  ),
                ]),
              ),
            body,
          ],
        ),
      ),
    );

    return compact ? SizedBox(width: 240, child: card) : card;
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? cs.primary : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
