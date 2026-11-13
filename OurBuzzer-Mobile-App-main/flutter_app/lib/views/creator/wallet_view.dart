import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/status_chip.dart';
import 'withdraw_view.dart';

/// Dompet kreator: saldo, tombol tarik saldo, dan riwayat penarikan.
class WalletView extends ConsumerWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(creatorStatsProvider);
    final wds = ref.watch(withdrawalsProvider);

    Future<void> refresh() {
      ref.invalidate(withdrawalsProvider);
      return ref.refresh(creatorStatsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet', style: TextStyle(fontWeight: FontWeight.w900))),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: AsyncView(
          value: stats,
          onRetry: () => ref.invalidate(creatorStatsProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(stats: s),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('open-withdraw-button'),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Tarik saldo'),
                onPressed: s.balance >= kMinWithdraw
                    ? () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => WithdrawView(balance: s.balance)))
                    : null,
              ),
              if (s.balance < kMinWithdraw)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Minimal penarikan ${rp(kMinWithdraw)}. Kumpulkan ${rp(kMinWithdraw - s.balance)} lagi.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SectionTitle('Riwayat penarikan'),
              ...wds.when(
                loading: () => const [Center(child: CircularProgressIndicator())],
                error: (e, _) => [ErrorRetry(message: '$e', onRetry: () => ref.invalidate(withdrawalsProvider))],
                data: (list) => list.isEmpty
                    ? const [EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada penarikan')]
                    : [for (final w in list) _WithdrawalTile(w)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.stats});
  final CreatorStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saldo aktif', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          Text(rp(stats.balance),
              key: const Key('wallet-balance'),
              style: TextStyle(color: cs.onPrimary, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(children: [
            _Mini('Total pendapatan', rp(stats.totalEarned), cs.onPrimary),
            _Mini('Sedang dicek', rp(stats.pending), cs.onPrimary),
          ]),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile(this.w);
  final Withdrawal w;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(rp(w.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([
            '${w.method} · ${w.accountNumber} a.n. ${w.accountHolder}',
            fmtDate(w.createdAt),
            if (w.reference.isNotEmpty) 'Ref: ${w.reference}',
          ].join('\n')),
          isThreeLine: true,
          trailing: StatusChip(w.status.label, w.status.tone),
        ),
      );
}
