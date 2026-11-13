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

/// Riwayat mutasi saldo (kreator: saldo, brand: saldo brand) dari GET /ledger.
class LedgerView extends ConsumerWidget {
  const LedgerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ledgerProvider);
    return Scaffold(
      appBar: const AppHeader(title: Text('Riwayat mutasi saldo')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ledgerProvider.future),
        child: AsyncView(
          value: items,
          onRetry: () => ref.invalidate(ledgerProvider),
          data: (list) => list.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada mutasi saldo')])
              : ListView(
                  padding: AppSpace.page,
                  children: [
                    PremiumCard(
                      child: Column(children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          LedgerTile(list[i]),
                        ],
                      ]),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class LedgerTile extends StatelessWidget {
  const LedgerTile(this.e, {super.key});
  final LedgerEntry e;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final credit = e.isCredit;
    return ListTile(
      key: Key('ledger-${e.entryId}'),
      leading: CircleAvatar(
        backgroundColor: credit ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.softPink,
        child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: credit ? AppTheme.success : AppTheme.primary, size: 20),
      ),
      title: Text(e.label, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text([if (e.note.isNotEmpty) e.note, fmtDate(e.createdAt)].join(' · '),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${credit ? '+' : '-'}${rp(e.amount.abs())}',
        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: credit ? AppTheme.success : null),
      ),
    );
  }
}
