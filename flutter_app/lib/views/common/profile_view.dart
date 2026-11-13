import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/premium.dart';
import '../../widgets/social_accounts_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/avatar_editor.dart';
import '../brand/brand_wallet_view.dart';
import '../brand/topup_view.dart';
import '../creator/wallet_view.dart';
import '../creator/withdraw_view.dart';
import 'edit_profile_view.dart';

/// Profil (Premium Red): header + avatar, ringkasan akun & rekening, Tarik saldo /
/// Top up, Riwayat, dan kartu menu akun. Dipakai kreator, brand, dan admin.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final canEdit = user.role != UserRole.admin;
    final roleLabel = switch (user.role) {
      UserRole.brand => 'Brand',
      UserRole.admin => 'Admin',
      _ => 'Kreator',
    };
    final bankAccount = user.profile['bank_account'] ?? '';

    return Scaffold(
      appBar: AppHeader(
        tall: true,
        title: const Text('Profil'),
        actions: [
          AvatarEditor(
            user: user,
            onEditProfile: canEdit ? () => _push(context, const EditProfileView()) : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.l, AppSpace.gutter, AppSpace.xl),
        children: [
          // ---------------- Akun & rekening ----------------
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Column(children: [
              _AccountRow(
                user: user,
                roleLabel: roleLabel,
                onTap: canEdit ? () => _push(context, const EditProfileView()) : null,
              ),
              if (user.isCreator) ...[
                const _RowDivider(),
                _BalanceRow(items: [('Saldo', rp(user.balance)), ('Total pendapatan', rp(user.totalEarned))]),
                const _RowDivider(),
                MenuRow(
                  key: const Key('profile-bank-info'),
                  icon: Icons.description_outlined,
                  label: 'Rekening pencairan',
                  subtitle: bankAccount.isEmpty
                      ? 'Belum diisi'
                      : '${user.profile['bank_method']} · $bankAccount a.n. ${user.profile['bank_holder']}',
                  onTap: () => _push(context, const EditProfileView()),
                ),
              ] else if (user.isBrand) ...[
                const _RowDivider(),
                _BalanceRow(items: [('Saldo brand', rp(user.brandBalance))]),
              ],
            ]),
          ),

          // ---------------- Akun sosial media & Telegram ----------------
          if (user.isCreator) ...[
            const SizedBox(height: AppSpace.l + 2),
            const SocialAccountsCard(),
          ],

          // ---------------- Aksi utama ----------------
          if (user.isCreator) ...[
            const SizedBox(height: AppSpace.l + 2),
            GradientButton(
              buttonKey: const Key('profile-withdraw-button'),
              icon: Icons.account_balance_wallet_outlined,
              label: 'Tarik saldo',
              onPressed: () => user.balance >= kMinWithdraw
                  ? _push(context, WithdrawView(balance: user.balance))
                  : showAppSnack(context,
                      'Minimal penarikan ${rp(kMinWithdraw)}. Kumpulkan ${rp(kMinWithdraw - user.balance)} lagi.'),
            ),
            const SizedBox(height: AppSpace.m),
            OutlineActionButton(
              buttonKey: const Key('profile-history-button'),
              icon: Icons.receipt_long_outlined,
              label: 'Riwayat',
              onPressed: () => _push(context, const WalletView()),
            ),
          ] else if (user.isBrand) ...[
            const SizedBox(height: AppSpace.l + 2),
            GradientButton(
              buttonKey: const Key('profile-topup-button'),
              icon: Icons.add_card_rounded,
              label: 'Top up saldo',
              onPressed: () => _push(context, const TopupView()),
            ),
            const SizedBox(height: AppSpace.m),
            OutlineActionButton(
              buttonKey: const Key('profile-history-button'),
              icon: Icons.receipt_long_outlined,
              label: 'Riwayat',
              onPressed: () => _push(context, const BrandWalletView()),
            ),
          ],
          const SizedBox(height: AppSpace.l + 2),

          // ---------------- Menu ----------------
          const AccountMenuCard(),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Divider(indent: AppSpace.l, endIndent: AppSpace.l);
}

/// Baris ringkas nominal (Saldo / Total pendapatan) berdampingan.
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.m),
      child: Row(children: [
        for (final (label, value) in items)
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Baris identitas: ikon, nama, email, dan label peran di bawahnya.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.user, required this.roleLabel, required this.onTap});
  final User user;
  final String roleLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      key: const Key('profile-account'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.m),
        child: Row(children: [
          const IconBadge(Icons.person_rounded),
          const SizedBox(width: AppSpace.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.isBrand ? user.brandName : user.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium),
              Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpace.xs + 2),
              StatusChip(roleLabel, Tone.primary),
            ]),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}
