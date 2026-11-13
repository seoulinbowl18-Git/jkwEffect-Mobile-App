import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/app_header.dart';

/// Ringkasan platform untuk admin.
class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    return Scaffold(
      appBar: AppHeader(title: const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('PAGI Admin'))),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminStatsProvider.future),
        child: AsyncView(
          value: stats,
          onRetry: () => ref.invalidate(adminStatsProvider),
          data: (s) {
            final items = [
              ('Withdraw menunggu', fmtNum(s.pendingWithdrawals), Icons.payments_rounded),
              ('Submission menunggu', fmtNum(s.pendingSubmissions), Icons.fact_check_rounded),
              ('Kreator', fmtNum(s.creators), Icons.videocam_rounded),
              ('Brand', fmtNum(s.brands), Icons.campaign_rounded),
              ('Campaign aktif', fmtNum(s.activeCampaigns), Icons.local_fire_department_rounded),
              ('Total views', fmtNum(s.totalViews), Icons.visibility_rounded),
              ('Total dicairkan', rp(s.totalPaid), Icons.account_balance_rounded),
            ];
            return GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                for (final (label, value, icon) in items)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(icon, color: Theme.of(context).colorScheme.primary),
                        const Spacer(),
                        Text(label, style: Theme.of(context).textTheme.bodySmall),
                        FittedBox(
                          child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                      ]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
