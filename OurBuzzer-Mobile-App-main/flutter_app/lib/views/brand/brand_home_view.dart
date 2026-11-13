import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/bell_button.dart';
import '../../widgets/campaign_card.dart';
import '../../widgets/form_helpers.dart';
import '../campaign/campaign_detail_view.dart';
import 'campaign_actions.dart';
import 'create_campaign_view.dart';
import 'topup_view.dart';

/// Beranda brand: statistik, aksi cepat, dan daftar campaign milik brand.
class BrandHomeView extends ConsumerWidget {
  const BrandHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(brandStatsProvider);
    final campaigns = ref.watch(brandCampaignsProvider);

    Future<void> refresh() {
      ref
        ..invalidate(brandCampaignsProvider)
        ..invalidate(notificationsProvider);
      return ref.refresh(brandStatsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: const [BellButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-campaign-fab'),
        icon: const Icon(Icons.add),
        label: const Text('Buat campaign'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const CreateCampaignView())),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: AsyncView(
          value: stats,
          onRetry: () => ref.invalidate(brandStatsProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _StatsGrid(stats: s),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('home-topup-button'),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Top up saldo'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TopupView())),
              ),
              const SectionTitle('Campaign saya'),
              ...campaigns.when(
                loading: () => const [Center(child: CircularProgressIndicator())],
                error: (e, _) => [ErrorRetry(message: '$e', onRetry: () => ref.invalidate(brandCampaignsProvider))],
                data: (list) => list.isEmpty
                    ? const [
                        EmptyState(
                          icon: Icons.campaign_outlined,
                          message: 'Belum ada campaign. Top up saldo lalu buat campaign pertamamu.',
                        ),
                      ]
                    : [for (final c in list) _BrandCampaignItem(campaign: c)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final BrandStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Saldo brand', rp(stats.brandBalance)),
      ('Campaign aktif', fmtNum(stats.active)),
      ('Budget terpakai', rp(stats.spent)),
      ('Total views', fmtNum(stats.views)),
    ];
    return Column(children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.1,
        children: [
          for (final (label, value) in items)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  FittedBox(
                    child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
            ),
        ],
      ),
      if (stats.pendingReviews > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.fact_check_rounded),
              title: Text('${stats.pendingReviews} submission perlu direview'),
              subtitle: const Text('Buka tab Review'),
            ),
          ),
        ),
    ]);
  }
}

class _BrandCampaignItem extends ConsumerWidget {
  const _BrandCampaignItem({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = campaign;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(children: [
        CampaignCard(
          campaign: c,
          showStatus: true,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => CampaignDetailView(campaignId: c.campaignId))),
        ),
        if (c.status != CampaignStatus.closed)
          Positioned(
            right: 4,
            top: 4,
            child: PopupMenuButton<CampaignStatus>(
              key: Key('campaign-menu-${c.campaignId}'),
              icon: const CircleAvatar(radius: 16, child: Icon(Icons.more_vert, size: 18)),
              onSelected: (s) => changeCampaignStatus(context, ref, c, s),
              itemBuilder: (_) => [
                if (c.status == CampaignStatus.active)
                  const PopupMenuItem(value: CampaignStatus.paused, child: Text('Jeda'))
                else
                  const PopupMenuItem(value: CampaignStatus.active, child: Text('Lanjutkan')),
                const PopupMenuItem(value: CampaignStatus.closed, child: Text('Tutup & kembalikan sisa budget')),
              ],
            ),
          ),
      ]),
    );
  }
}
