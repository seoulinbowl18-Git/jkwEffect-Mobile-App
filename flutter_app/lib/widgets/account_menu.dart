import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../views/common/faq_view.dart';
import '../views/common/settings_view.dart';
import '../views/creator/content_view.dart';
import 'app_snackbar.dart';
import 'form_helpers.dart';
import 'premium.dart';
import 'status_chip.dart';

/// Kartu menu akun baku (Konten saya · Voucher / Kupon · Ajak Teman · Bantuan & FAQ ·
/// Pengaturan · Keluar) — dipakai Profil dan Dompet agar fungsi & tampilannya sama.
///
/// [keyPrefix] membedakan key widget bila dua halaman tab memuat kartu ini sekaligus.
class AccountMenuCard extends ConsumerWidget {
  const AccountMenuCard({super.key, this.showContent = true, this.keyPrefix = ''});

  final bool showContent;
  final String keyPrefix;

  Key _k(String id) => Key('$keyPrefix$id');

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _comingSoon(BuildContext context, String what) =>
      showAppSnack(context, '$what segera hadir. Nantikan pembaruan berikutnya!');

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context, title: 'Keluar?', message: 'Kamu perlu login lagi nanti.', confirmLabel: 'Keluar');
    if (ok) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final items = <Widget>[
      if (showContent && user.isCreator)
        MenuRow(
          key: _k('profile-content'),
          icon: Icons.video_library_rounded,
          label: 'Konten saya',
          onTap: () => _push(context, const ContentView()),
        ),
      if (user.role != UserRole.admin) ...[
        MenuRow(
          key: _k('menu-voucher'),
          icon: Icons.confirmation_number_rounded,
          label: 'Voucher / Kupon',
          badge: 'Segera',
          onTap: () => _comingSoon(context, 'Voucher / Kupon'),
        ),
        MenuRow(
          key: _k('menu-referral'),
          icon: Icons.group_add_rounded,
          label: 'Ajak Teman',
          badge: 'Segera',
          onTap: () => _comingSoon(context, 'Ajak Teman'),
        ),
      ],
      MenuRow(
        key: _k('profile-faq'),
        icon: Icons.help_rounded,
        label: 'Bantuan & FAQ',
        onTap: () => _push(context, const FaqView()),
      ),
      MenuRow(
        key: _k('profile-settings'),
        icon: Icons.settings_rounded,
        label: 'Pengaturan',
        onTap: () => _push(context, const SettingsView()),
      ),
      MenuRow(
        key: _k('logout-button'),
        icon: Icons.logout_rounded,
        label: 'Keluar',
        destructive: true,
        showChevron: false,
        onTap: () => _logout(context, ref),
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(indent: AppSpace.l + 46 + AppSpace.l, endIndent: AppSpace.l),
          items[i],
        ],
      ]),
    );
  }
}

/// Baris menu baku: ikon di kotak abu muda + label + lencana opsional + panah.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? badge;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.m - 2),
        child: Row(children: [
          IconBadge(icon),
          const SizedBox(width: AppSpace.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(color: destructive ? cs.primary : cs.onSurface)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ]),
          ),
          if (badge != null) ...[const SizedBox(width: AppSpace.s), StatusChip(badge!, Tone.primary)],
          ?trailing,
          if (showChevron) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.7)),
          ],
        ]),
      ),
    );
  }
}
