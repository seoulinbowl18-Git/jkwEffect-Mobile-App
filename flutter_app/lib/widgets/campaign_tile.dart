import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Kartu campaign ringkas untuk daftar horizontal di Beranda:
/// thumbnail bersudut melengkung, judul, dan nama brand.
class CampaignTile extends StatelessWidget {
  const CampaignTile({super.key, required this.campaign, required this.onTap, this.width = 200});

  final Campaign campaign;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Center(child: Icon(Icons.campaign_rounded, size: 44, color: cs.onPrimary)),
    );
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: campaign.thumbnail.isEmpty
                  ? placeholder
                  : Image.network(
                      AppConfig.resolveUrl(campaign.thumbnail),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.m, AppSpace.m, AppSpace.l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(campaign.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpace.xs),
                Text(campaign.brandName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
