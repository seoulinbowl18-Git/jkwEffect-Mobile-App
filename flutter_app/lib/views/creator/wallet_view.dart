import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fees.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_view.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/premium.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/user_avatar.dart';
import '../common/ledger_view.dart';
import '../home/home_shell.dart';
import 'withdraw_view.dart';
import 'withdrawal_history_view.dart';

/// Dompet kreator (Premium Red): header brand + avatar, kartu Saldo Aktif bergradasi,
/// tombol Tarik saldo, timeline Riwayat Penarikan, dan menu akun.
class WalletView extends ConsumerWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(creatorStatsProvider);
    final wds = ref.watch(withdrawalsProvider);
    final fees = ref.watch(feesProvider).value ?? const FeesConfig();
    final minW = fees.minWithdraw;

    Future<void> refresh() {
      ref.invalidate(withdrawalsProvider);
      return ref.refresh(creatorStatsProvider.future);
    }

    void openHistory() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WithdrawalHistoryView()));

    return Scaffold(
      appBar: AppHeader(
        tall: true,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: BrandLogo(size: 34, showName: true, onDark: true),
        ),
        actions: [
          InkWell(
            key: const Key('wallet-avatar'),
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              ref.read(homeTabProvider.notifier).go(CreatorTab.profile);
            },
            child: UserAvatar(user: user, radius: 24, ring: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: AsyncView(
          value: stats,
          onRetry: () => ref.invalidate(creatorStatsProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.l, AppSpace.gutter, AppSpace.xl),
            children: [
              _BalanceCard(stats: s),
              const SizedBox(height: AppSpace.l + 2),
              GradientButton(
                buttonKey: const Key('open-withdraw-button'),
                icon: Icons.account_balance_wallet_outlined,
                label: 'Tarik saldo',
                onPressed: s.balance >= minW
                    ? () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => WithdrawView(balance: s.balance)))
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s),
                child: Text(
                  'Biaya platform ${pctLabel(fees.creatorWithdrawFeePct)}% dipotong saat penarikan. '
                  'Rinciannya tampil sebelum kamu konfirmasi.',
                  key: const Key('wallet-fee-note'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (s.balance < minW)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s),
                  child: Text(
                    'Minimal penarikan ${rp(minW)}. Kumpulkan ${rp(minW - s.balance)} lagi.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpace.xl),

              // ---------------- Riwayat Penarikan (timeline) ----------------
              AccentSectionTitle(
                'Riwayat Penarikan',
                actionKey: const Key('wallet-history-all'),
                onAction: (wds.value?.isNotEmpty ?? false) ? openHistory : null,
              ),
              const SizedBox(height: AppSpace.l),
              ...wds.when(
                loading: () => const [
                  Padding(padding: EdgeInsets.all(AppSpace.l), child: Center(child: CircularProgressIndicator())),
                ],
                error: (e, _) => [ErrorRetry(message: '$e', onRetry: () => ref.invalidate(withdrawalsProvider))],
                data: (list) => list.isEmpty
                    ? const [_EmptyHistory()]
                    : [_WithdrawalTimeline(items: list, onTap: openHistory)],
              ),
              const SizedBox(height: AppSpace.xl),

              TextButton.icon(
                key: const Key('wallet-ledger-button'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Riwayat mutasi saldo'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LedgerView())),
              ),
              const SizedBox(height: AppSpace.m),

              // ---------------- Menu ----------------
              const AccountMenuCard(showContent: false, keyPrefix: 'wallet-'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu Saldo Aktif: gradasi merah premium, ornamen gelombang + grafik naik,
/// nominal besar (bisa disembunyikan), Total Pendapatan & Sedang dicek.
class _BalanceCard extends StatefulWidget {
  const _BalanceCard({required this.stats});
  final CreatorStats stats;

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _hidden = false;

  String _money(int v) => _hidden ? 'Rp ••••••' : rp(v);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final s = widget.stats;
    return Container(
      key: const Key('wallet-balance-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppTheme.glowShadow,
      ),
      child: CustomPaint(
        painter: const BrandWavePainter(strength: 0.9),
        child: Stack(children: [
          // Grafik naik dekoratif di kanan atas.
          Positioned(
            right: AppSpace.l,
            top: AppSpace.m,
            child: Icon(Icons.trending_up_rounded, size: 64, color: AppTheme.onBrandAlpha(0.22)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.l, AppSpace.l, AppSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('Saldo Aktif', style: t.titleMedium?.copyWith(color: AppTheme.onBrandAlpha(0.92), fontWeight: FontWeight.w500))),
                IconButton(
                  key: const Key('wallet-toggle-balance'),
                  tooltip: _hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                      size: 22, color: AppTheme.onBrandAlpha(0.92)),
                ),
              ]),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money(s.balance),
                  key: const Key('wallet-balance'),
                  style: t.displaySmall?.copyWith(color: onBrand, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Stat(Icons.account_balance_wallet_outlined, 'Total Pendapatan', _money(s.totalEarned))),
                  VerticalDivider(width: AppSpace.l, thickness: 1, color: AppTheme.onBrandAlpha(0.3)),
                  Expanded(child: _Stat(Icons.hourglass_top_rounded, 'Sedang dicek', _money(s.pending))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppTheme.onBrandAlpha(0.18), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: AppTheme.onBrand),
      ),
      const SizedBox(width: AppSpace.s + 2),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1, style: t.bodySmall?.copyWith(color: AppTheme.onBrandAlpha(0.88))),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.titleSmall?.copyWith(color: AppTheme.onBrand, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    ]);
  }
}

/// Timeline horizontal: lingkaran ikon status dihubungkan garis, nominal & tanggal di bawah.
class _WithdrawalTimeline extends StatelessWidget {
  const _WithdrawalTimeline({required this.items, required this.onTap});
  final List<Withdrawal> items;
  final VoidCallback onTap;

  static const double _itemWidth = 120;
  static const double _circle = 60;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: _circle + 12 + 64 * scale,
      child: ListView.builder(
        key: const Key('wallet-history-timeline'),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        itemBuilder: (_, i) => _TimelineItem(
          w: items[i],
          first: i == 0,
          last: i == items.length - 1,
          width: _itemWidth,
          circle: _circle,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.w,
    required this.first,
    required this.last,
    required this.width,
    required this.circle,
    required this.onTap,
  });

  final Withdrawal w;
  final bool first;
  final bool last;
  final double width;
  final double circle;
  final VoidCallback onTap;

  IconData get _icon => switch (w.status) {
        WithdrawalStatus.diproses => Icons.history_rounded,
        WithdrawalStatus.disetujui => Icons.check_circle_outline_rounded,
        WithdrawalStatus.ditolak => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final line = Container(height: 2, color: cs.outlineVariant);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: onTap,
        child: Column(children: [
          SizedBox(
            height: circle,
            child: Stack(alignment: Alignment.center, children: [
              Row(children: [
                Expanded(child: first ? const SizedBox() : line),
                SizedBox(width: circle + AppSpace.s),
                Expanded(child: last ? const SizedBox() : line),
              ]),
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.softShadow,
                ),
                child: Icon(_icon, size: 30, color: cs.primary),
              ),
            ]),
          ),
          const SizedBox(height: AppSpace.s),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: Column(children: [
              Text(rp(w.netAmount), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
              Text(fmtDate(w.createdAt), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
              Text(w.status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(color: w.status.tone.color(context), fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Row(children: [
        const IconBadge(Icons.receipt_long_rounded),
        const SizedBox(width: AppSpace.l),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Belum ada penarikan', style: t.titleSmall),
            Text('Riwayat penarikan saldo kamu akan tampil di sini.', style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
