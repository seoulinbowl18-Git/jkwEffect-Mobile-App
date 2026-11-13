import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Avatar pengguna: foto Google bila ada, inisial bila tidak. [ring] = bingkai putih
/// (dipakai di atas header gradasi), [badge] = lencana kecil di kanan bawah.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 22, this.ring = false, this.badge});
  final User? user;
  final double radius;
  final bool ring;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final pic = user?.picture;
    final u = user;
    final name = u == null ? '' : (u.isBrand && u.brandName.isNotEmpty ? u.brandName : u.name);
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      backgroundImage: pic != null ? NetworkImage(AppConfig.resolveUrl(pic)) : null,
      onBackgroundImageError: pic != null ? (_, _) {} : null,
      child: pic == null
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: (radius >= 24 ? t.titleLarge : t.titleSmall)?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
            )
          : null,
    );
    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
        child: avatar,
      );
    }
    if (badge == null) return avatar;
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(right: -2, bottom: -2, child: badge!),
    ]);
  }
}
