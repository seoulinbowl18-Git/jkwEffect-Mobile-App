import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
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
import '../../widgets/app_header.dart';

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
      appBar: AppHeader(
        title: const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('jkwEffect')),
        actions: const [BellButton()],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: AsyncView(
          value: stats,
          onRetry: () => ref.invalidate(brandStatsProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.s, AppSpace.l, AppSpace.xl),
            children: [
              _StatsGrid(stats: s),
              const SizedBox(height: AppSpace.m),
              // Dua aksi utama sejajar di konten (bukan tombol mengambang yang
              // menutupi isi daftar di layar kecil).
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('home-topup-button'),
                    icon: const Icon(Icons.add_card_rounded),
                    label: const FittedBox(child: Text('Top up')),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TopupView())),
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('new-campaign-fab'),
                    icon: const Icon(Icons.add),
                    label: const FittedBox(child: Text('Buat campaign')),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const CreateCampaignView())),
                  ),
                ),
              ]),
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
      ('Sisa budget campaign', rp(stats.budgetLeft)),
      ('Campaign aktif', fmtNum(stats.active)),
      ('Kreator terdaftar', fmtNum(stats.creators)),
      ('Total views', fmtNum(stats.views)),
      ('Budget terpakai', rp(stats.spent)),
    ];
    Widget tile((String, String) item) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpace.xs),
              // scaleDown: nominal besar mengecil, tidak meluap; tinggi kartu ikut ukuran font.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(item.$2,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        );
    Widget row(int i) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tile(items[i])),
            const SizedBox(width: AppSpace.s),
            Expanded(child: tile(items[i + 1])),
          ]),
        );
    return Column(children: [
      row(0),
      const SizedBox(height: AppSpace.s),
      row(2),
      const SizedBox(height: AppSpace.s),
      row(4),
      const SizedBox(height: AppSpace.s),
      Text(
        'Review konten & verifikasi views kreator ditangani Admin Pusat jkwEffect.',
        key: const Key('brand-review-by-admin-note'),
        style: Theme.of(context).textTheme.bodySmall,
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
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: CampaignCard(
        campaign: c,
        showStatus: true,
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => CampaignDetailView(campaignId: c.campaignId))),
        trailing: c.status == CampaignStatus.closed
            ? null
            : SizedBox.square(
                dimension: 32,
                child: PopupMenuButton<CampaignStatus>(
                  key: Key('campaign-menu-${c.campaignId}'),
                  tooltip: 'Kelola campaign',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (s) => changeCampaignStatus(context, ref, c, s),
                  itemBuilder: (_) => [
                    if (c.status == CampaignStatus.active)
                      const PopupMenuItem(value: CampaignStatus.paused, child: Text('Jeda'))
                    else
                      const PopupMenuItem(value: CampaignStatus.active, child: Text('Lanjutkan')),
                    const PopupMenuItem(value: CampaignStatus.closed, child: Text('Hentikan / Tutup & kembalikan sisa budget')),
                  ],
                ),
              ),
      ),
    );
  }
}
