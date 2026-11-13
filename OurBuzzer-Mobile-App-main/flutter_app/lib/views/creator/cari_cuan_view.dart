import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/bell_button.dart';
import '../../widgets/campaign_card.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/streak_banner.dart';
import '../campaign/campaign_detail_view.dart';

/// Halaman "Cari Cuan" (/bounty): tab Public/Exclusive, pencarian, filter
/// kategori, section banner, streak, saldo, dan lonceng notifikasi.
class CariCuanView extends ConsumerStatefulWidget {
  const CariCuanView({super.key});

  @override
  ConsumerState<CariCuanView> createState() => _CariCuanViewState();
}

class _CariCuanViewState extends ConsumerState<CariCuanView> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(campaignFilterProvider).query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(campaignFilterProvider.notifier).setQuery(v.trim());
    });
  }

  Future<void> _refresh() {
    ref
      ..invalidate(creatorStatsProvider)
      ..invalidate(notificationsProvider)
      ..invalidate(campaignSectionsProvider);
    return ref.refresh(campaignListProvider.future);
  }

  void _open(Campaign c) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => CampaignDetailView(campaignId: c.campaignId)));

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(campaignFilterProvider);
    final stats = ref.watch(creatorStatsProvider).value;
    final notifier = ref.read(campaignFilterProvider.notifier);
    final showSections = !filter.exclusive && filter.isDefault;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Cuan', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (stats != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Chip(
                key: const Key('balance-pill'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                label: Text(rp(stats.balance)),
              ),
            ),
          const BellButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.list(children: [
                if (stats != null) StreakBanner(streak: stats.streak),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Public'), icon: Icon(Icons.public)),
                    ButtonSegment(value: true, label: Text('Exclusive'), icon: Icon(Icons.workspace_premium)),
                  ],
                  selected: {filter.exclusive},
                  onSelectionChanged: (s) => notifier.setExclusive(s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('campaign-search-input'),
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari campaign...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              notifier.setQuery('');
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ]),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final cat in ['Semua', ...kCategories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('category-$cat'),
                          label: Text(cat),
                          selected: filter.category == cat,
                          onSelected: (_) => notifier.setCategory(cat),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showSections) const _Sections(),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _ListTitle()),
            ),
            _CampaignList(onOpen: _open),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ListTitle extends ConsumerWidget {
  const _ListTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(campaignFilterProvider);
    final n = ref.watch(campaignListProvider).value?.length;
    final title = f.isDefault ? (f.exclusive ? 'Campaign exclusive' : 'Semua campaign') : 'Hasil pencarian';
    return SectionTitle(n == null ? title : '$title ($n)');
  }
}

/// Empat baris section banner (hanya tab Public tanpa filter).
class _Sections extends ConsumerWidget {
  const _Sections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(campaignSectionsProvider);
    void open(Campaign c) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => CampaignDetailView(campaignId: c.campaignId)));

    return sections.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (s) => SliverList.list(children: [
        _Row(title: '🔥 Lagi rame', items: s.trending, onOpen: open),
        _Row(title: '⏰ Segera ditutup', items: s.closing, onOpen: open),
        _Row(title: '💰 Rate tertinggi', items: s.topRate, onOpen: open),
        _Row(title: '✨ Campaign baru', items: s.newest, onOpen: open),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.items, required this.onOpen});
  final String title;
  final List<Campaign> items;
  final void Function(Campaign) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SectionTitle(title)),
      SizedBox(
        height: 290,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => Align(
            alignment: Alignment.topCenter,
            child: CampaignCard(campaign: items[i], compact: true, onTap: () => onOpen(items[i])),
          ),
        ),
      ),
    ]);
  }
}

class _CampaignList extends ConsumerWidget {
  const _CampaignList({required this.onOpen});
  final void Function(Campaign) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(campaignListProvider);
    return list.when(
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: ErrorRetry(message: '$e', onRetry: () => ref.invalidate(campaignListProvider)),
      ),
      data: (items) => items.isEmpty
          ? const SliverToBoxAdapter(
              child: EmptyState(icon: Icons.search_off_rounded, message: 'Belum ada campaign yang cocok'),
            )
          : SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => CampaignCard(campaign: items[i], onTap: () => onOpen(items[i])),
              ),
            ),
    );
  }
}
