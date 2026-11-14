import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Komponen baku "Premium Red" (dipakai Dompet, Profil, dan halaman berikutnya).

/// Tombol aksi utama: gradasi merah + pendar lembut, ikon + label di tengah, panah di kanan.
/// [buttonKey] dipasang di [FilledButton] di dalamnya agar test/aksesibilitas tetap
/// melihat tombol Material biasa (termasuk status nonaktif).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.showChevron = true,
  });

  final Key? buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(AppRadius.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.buttonGradient : null,
        color: enabled ? null : cs.surfaceContainerHigh,
        borderRadius: radius,
        boxShadow: enabled ? AppTheme.glowShadow : null,
      ),
      child: FilledButton(
        key: buttonKey,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: cs.onPrimary,
          disabledForegroundColor: cs.onSurfaceVariant,
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        onPressed: onPressed,
        child: _ButtonContent(icon: icon, label: label, showChevron: showChevron),
      ),
    );
  }
}

/// Tombol aksi kedua: putih, garis tepi merah, teks merah, panah di kanan.
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.showChevron = true,
  });

  final Key? buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      key: buttonKey,
      style: OutlinedButton.styleFrom(
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary, width: 1.4),
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      ),
      onPressed: onPressed,
      child: _ButtonContent(icon: icon, label: label, showChevron: showChevron),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.icon, required this.label, required this.showChevron});
  final IconData icon;
  final String label;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => Row(children: [
        // Penyeimbang kiri agar ikon + label tetap di tengah walau ada panah di kanan.
        if (showChevron) const SizedBox(width: 24),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 24),
            const SizedBox(width: AppSpace.m),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        if (showChevron) const Icon(Icons.chevron_right_rounded, size: 24),
      ]);
}

/// Ikon menu di kotak bersudut merah muda (soft pink) — gaya ikon baku semua menu.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.size = 46});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Icon(icon, size: size * 0.5, color: cs.primary),
    );
  }
}

/// Judul section dengan garis aksen merah di kiri + tombol pill "Lihat Semua" opsional.
class AccentSectionTitle extends StatelessWidget {
  const AccentSectionTitle(this.title, {super.key, this.actionLabel = 'Lihat Semua', this.onAction, this.actionKey});
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Container(
        width: 4,
        height: 24,
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      const SizedBox(width: AppSpace.m),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, maxLines: 1, style: t.titleLarge),
        ),
      ),
      const SizedBox(width: AppSpace.s),
      if (onAction != null)
        Material(
          color: cs.primaryContainer,
          shape: const StadiumBorder(),
          child: InkWell(
            key: actionKey,
            customBorder: const StadiumBorder(),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.m + 2, AppSpace.s, AppSpace.s, AppSpace.s),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel, style: t.labelLarge?.copyWith(color: cs.primary)),
                Icon(Icons.chevron_right_rounded, size: 20, color: cs.primary),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Kartu putih baku (sudut 24, bayangan lembut) untuk sekelompok baris menu/data.
class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppTheme.softShadow,
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
}
