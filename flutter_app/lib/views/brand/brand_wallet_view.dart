import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fees.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/status_chip.dart';
import '../common/ledger_view.dart';
import '../creator/withdraw_view.dart';
import '../creator/withdrawal_history_view.dart';
import 'topup_payment_view.dart';
import 'topup_view.dart';
import '../../widgets/app_header.dart';

/// Saldo brand: top up, tarik saldo (cairkan saldo mengendap / sisa budget), riwayat top up,
/// riwayat penarikan, dan riwayat mutasi. Top up pending bisa dibuka lagi untuk QR/VA.
class BrandWalletView extends ConsumerWidget {
  const BrandWalletView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(brandStatsProvider);
    final topups = ref.watch(topupsProvider);
    final wds = ref.watch(brandWithdrawalsProvider);
    final fees = ref.watch(feesProvider).value ?? const FeesConfig();
    final balance = stats.value?.brandBalance ?? 0;
    final cs = Theme.of(context).colorScheme;

    Future<void> refresh() {
      ref
        ..invalidate(topupsProvider)
        ..invalidate(brandWithdrawalsProvider);
      return ref.refresh(brandStatsProvider.future);
    }

    return Scaffold(
      appBar: AppHeader(title: const Text('Saldo')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              color: cs.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Saldo brand', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85))),
                  Text(
                    stats.value == null ? '…' : rp(stats.value!.brandBalance),
                    key: const Key('brand-balance'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: cs.onPrimary),
                  ),
                  if (stats.value != null) ...[
                    Text('Terkunci di campaign berjalan: ${rp(stats.value!.budgetLeft)}',
                        key: const Key('brand-escrow'), style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85))),
                    Text('Sudah dibayarkan ke kreator: ${rp(stats.value!.spent)}',
                        style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85))),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('wallet-topup-button'),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const FittedBox(child: Text('Top up saldo')),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TopupView())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('brand-withdraw-button'),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const FittedBox(child: Text('Tarik saldo')),
                  onPressed: balance >= fees.minWithdraw
                      ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => WithdrawView(balance: balance, forBrand: true)))
                      : null,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Budget campaign dikunci dari saldo saat campaign dibuat dan hanya terpakai saat klaim views disetujui. '
              'Sisa budget otomatis kembali ke saldo saat campaign ditutup atau masa berlakunya habis. '
              'Top up dikenai biaya layanan ${pctLabel(fees.brandTopupFeePct)}%.',
              key: const Key('brand-escrow-note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('brand-ledger-button'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Riwayat mutasi saldo'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LedgerView())),
              ),
            ),
            if (wds.value?.isNotEmpty ?? false) ...[
              const SectionTitle('Riwayat penarikan'),
              for (final w in wds.value!)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: WithdrawalTile(w)),
            ],
            const SectionTitle('Riwayat top up'),
            ...topups.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (e, _) => [ErrorRetry(message: '$e', onRetry: () => ref.invalidate(topupsProvider))],
              data: (list) => list.isEmpty
                  ? const [EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada top up')]
                  : [for (final t in list) _TopupTile(t)],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupTile extends ConsumerWidget {
  const _TopupTile(this.t);
  final Topup t;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          key: Key('topup-${t.topupId}'),
          title: Text('+${rp(t.amount)} saldo masuk', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            '${t.fee > 0 ? 'Dibayar ${rp(t.total)} (biaya layanan ${rp(t.fee)})\n' : ''}'
            '${t.paymentType == PaymentType.qris ? 'QRIS' : 'VA ${t.channelCode}'} · ${fmtDate(t.createdAt)}',
          ),
          trailing: StatusChip(t.status.label, t.status.tone),
          onTap: t.isPending
              ? () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => TopupPaymentView(topup: t)));
                  ref.invalidate(topupsProvider);
                }
              : null,
        ),
      );
}
