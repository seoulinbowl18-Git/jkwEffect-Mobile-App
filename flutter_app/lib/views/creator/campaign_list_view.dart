import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/campaign_card.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/app_header.dart';
import '../campaign/campaign_detail_view.dart';

/// Halaman "Lihat Semua" dari section Cari Cuan.
/// [sort] → daftar lengkap dari API dengan urutan itu; [items] → daftar tetap
/// (dipakai "Lagi rame", karena API tidak punya urutan trending).
class CampaignListView extends ConsumerWidget {
  const CampaignListView({super.key, required this.title, this.sort, this.items})
      : assert(sort != null || items != null);

  final String title;
  final CampaignSort? sort;
  final List<Campaign>? items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget list(List<Campaign> data) => data.isEmpty
        ? ListView(children: const [EmptyState(icon: Icons.search_off_rounded, message: 'Belum ada campaign')])
        : ListView.separated(
            padding: AppSpace.page,
            itemCount: data.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.m),
            itemBuilder: (_, i) => CampaignCard(
              campaign: data[i],
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => CampaignDetailView(campaignId: data[i].campaignId))),
            ),
          );

    final s = sort;
    return Scaffold(
      appBar: AppHeader(title: Text(title)),
      body: s == null
          ? list(items!)
          : RefreshIndicator(
              onRefresh: () => ref.refresh(campaignsBySortProvider(s).future),
              child: AsyncView(
                value: ref.watch(campaignsBySortProvider(s)),
                onRetry: () => ref.invalidate(campaignsBySortProvider(s)),
                data: list,
              ),
            ),
    );
  }
}
