import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/premium.dart';
import '../../widgets/status_chip.dart';

/// Daftar lengkap riwayat penarikan ("Lihat Semua" dari Dompet).
class WithdrawalHistoryView extends ConsumerWidget {
  const WithdrawalHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wds = ref.watch(withdrawalsProvider);
    return Scaffold(
      appBar: const AppHeader(title: Text('Riwayat penarikan')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(withdrawalsProvider.future),
        child: AsyncView(
          value: wds,
          onRetry: () => ref.invalidate(withdrawalsProvider),
          data: (list) => list.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada penarikan')])
              : ListView.separated(
                  padding: AppSpace.page,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpace.m),
                  itemBuilder: (_, i) => WithdrawalTile(list[i]),
                ),
        ),
      ),
    );
  }
}

/// Kartu satu penarikan: nominal, rekening, tanggal, referensi, dan status.
class WithdrawalTile extends StatelessWidget {
  const WithdrawalTile(this.w, {super.key});
  final Withdrawal w;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const IconBadge(Icons.payments_rounded),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rp(w.netAmount), key: Key('withdrawal-net-${w.withdrawalId}'),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (w.fee > 0)
              Text('Ditarik ${rp(w.amount)} · biaya platform ${rp(w.fee)}', style: t.bodySmall),
            const SizedBox(height: 2),
            Text('${w.method} · ${w.accountNumber} a.n. ${w.accountHolder}', style: t.bodySmall),
            Text(fmtDate(w.createdAt), style: t.bodySmall),
            if (w.reference.isNotEmpty) Text('Ref: ${w.reference}', style: t.bodySmall),
          ]),
        ),
        const SizedBox(width: AppSpace.s),
        StatusChip(w.status.label, w.status.tone),
      ]),
    );
  }
}
