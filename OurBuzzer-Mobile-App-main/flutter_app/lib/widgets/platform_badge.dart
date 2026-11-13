import 'package:flutter/material.dart';

import '../models/enums.dart';

extension VideoPlatformIcon on VideoPlatform {
  IconData get icon => switch (this) {
        VideoPlatform.tiktok => Icons.music_note_rounded,
        VideoPlatform.instagram => Icons.camera_alt_rounded,
        VideoPlatform.threads => Icons.alternate_email_rounded,
        VideoPlatform.youtube => Icons.play_circle_fill_rounded,
      };
}

/// Deretan ikon kecil platform yang diterima campaign.
class PlatformIcons extends StatelessWidget {
  const PlatformIcons(this.platforms, {super.key, this.size = 16});
  final List<VideoPlatform> platforms;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final p in platforms)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(message: p.label, child: Icon(p.icon, size: size, color: color)),
        ),
    ]);
  }
}
