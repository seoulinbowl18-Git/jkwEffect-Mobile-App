import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/status_chip.dart';
import 'topup_payment_view.dart';
import 'topup_view.dart';

/// Saldo brand + riwayat top up. Top up yang masih pending bisa dibuka lagi
/// untuk melihat QR/VA dan cek status.
class BrandWalletView extends ConsumerWidget {
  const BrandWalletView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(brandStatsProvider);
    final topups = ref.watch(topupsProvider);
    final cs = Theme.of(context).colorScheme;

    Future<void> refresh() {
      ref.invalidate(topupsProvider);
      return ref.refresh(brandStatsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saldo', style: TextStyle(fontWeight: FontWeight.w900))),
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
                    style: TextStyle(color: cs.onPrimary, fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  if (stats.value != null)
                    Text('Terpakai di campaign: ${rp(stats.value!.spent)}',
                        style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('wallet-topup-button'),
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Top up saldo'),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TopupView())),
            ),
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
          title: Text(rp(t.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
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
