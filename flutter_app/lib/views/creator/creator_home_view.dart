import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bell_button.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/campaign_tile.dart';
import '../../widgets/streak_banner.dart';
import '../campaign/campaign_detail_view.dart';
import '../home/home_shell.dart';
import 'content_view.dart';

/// Beranda kreator (desain referensi): header gradasi + Streak Harian yang
/// menumpuk di bawahnya, Campaign (horizontal), Jelajahi Produk, Dompet Kamu
/// (kartu gradasi), dan Profil Saya.
class CreatorHomeView extends ConsumerWidget {
  const CreatorHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(creatorStatsProvider).value;
    final sections = ref.watch(campaignSectionsProvider);
    final subs = ref.watch(creatorSubmissionsProvider).value;
    final toClaim = subs?.where((s) => s.status.canClaim).length ?? 0;
    final tab = ref.read(homeTabProvider.notifier);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Future<void> refresh() {
      ref
        ..invalidate(creatorSubmissionsProvider)
        ..invalidate(notificationsProvider)
        ..invalidate(campaignSectionsProvider);
      return ref.refresh(creatorStatsProvider.future);
    }

    final campaigns = sections.value == null
        ? const <Campaign>[]
        : {for (final c in [...sections.value!.trending, ...sections.value!.newest]) c.campaignId: c}.values.toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---------------- Header + Streak Harian (menumpuk) ----------------
            _Header(
              user: user,
              onSearch: () => tab.go(CreatorTab.explore),
              onAvatar: () => tab.go(CreatorTab.profile),
              child: StreakBanner(streak: stats?.streak ?? Streak.empty),
            ),

            // ---------------- Campaign ----------------
            _SectionHeader('Campaign', onSeeAll: () => tab.go(CreatorTab.explore)),
            SizedBox(
              // Tinggi ikut skala huruf pengguna agar judul 2 baris + brand tidak terpotong.
              height: 178 + 56 * MediaQuery.textScalerOf(context).scale(1),
              child: sections.isLoading && campaigns.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : campaigns.isEmpty
                      ? Center(child: Text('Belum ada campaign aktif', style: t.bodyMedium))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xs, AppSpace.gutter, AppSpace.m),
                          itemCount: campaigns.length,
                          separatorBuilder: (_, _) => const SizedBox(width: AppSpace.l),
                          itemBuilder: (_, i) => Align(
                            alignment: Alignment.topCenter,
                            child: CampaignTile(
                              key: Key('home-campaign-${campaigns[i].campaignId}'),
                              campaign: campaigns[i],
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => CampaignDetailView(campaignId: campaigns[i].campaignId),
                              )),
                            ),
                          ),
                        ),
            ),

            // ---------------- Jelajahi Produk ----------------
            _SectionHeader('Jelajahi Produk', onSeeAll: () => tab.go(CreatorTab.explore)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: AppSpace.card,
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                      child: Icon(Icons.shopping_basket_outlined, color: cs.onSurface),
                    ),
                    const SizedBox(width: AppSpace.l),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Jelajahi Produk', style: t.titleMedium),
                        Text('Temukan campaign dari brand', style: t.bodySmall, maxLines: 2),
                      ]),
                    ),
                    const SizedBox(width: AppSpace.m),
                    FilledButton(
                      key: const Key('home-explore-button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                      ),
                      onPressed: () => tab.go(CreatorTab.explore),
                      child: const Text('Jelajah'),
                    ),
                  ]),
                ),
              ),
            ),

            // ---------------- Dompet Kamu ----------------
            const SizedBox(height: AppSpace.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Container(
                key: const Key('home-wallet-card'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Dompet Kamu', style: t.titleMedium?.copyWith(color: cs.onPrimary)),
                      const SizedBox(height: AppSpace.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rp(stats?.balance ?? user?.balance ?? 0),
                          key: const Key('home-wallet-balance'),
                          style: t.headlineMedium?.copyWith(color: cs.onPrimary),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: AppSpace.m),
                  FilledButton(
                    key: const Key('home-wallet-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.surface,
                      foregroundColor: cs.primary,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                    ),
                    onPressed: () => tab.go(CreatorTab.wallet),
                    child: const Text('Saldo'),
                  ),
                ]),
              ),
            ),

            // ---------------- Profil Saya ----------------
            _SectionHeader('Profil Saya'),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.xxl),
              child: Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    key: const Key('home-profile-tile'),
                    leading: _Avatar(user: user, radius: 22),
                    title: Text(user?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                    subtitle: Text('Kreator · ${user?.email ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    onTap: () => tab.go(CreatorTab.profile),
                  ),
                  const Divider(indent: AppSpace.l, endIndent: AppSpace.l),
                  ListTile(
                    key: const Key('home-content-tile'),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.video_library_rounded, color: cs.primary),
                    ),
                    title: Text('Konten saya', style: t.titleSmall),
                    subtitle: Text(toClaim > 0 ? '$toClaim konten siap klaim views' : 'Pantau status video kamu'),
                    trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ContentView())),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header gradasi; [child] (kartu streak) menggantung setengah di bawah gradasi.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onSearch, required this.onAvatar, required this.child});
  final User? user;
  final VoidCallback onSearch;
  final VoidCallback onAvatar;
  final Widget child;

  static const double _overhang = 56;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(children: [
      const Positioned(left: 0, right: 0, top: 0, bottom: _overhang, child: GradientPanel(child: SizedBox.expand())),
      Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.gutter, top + AppSpace.l, AppSpace.gutter, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: const BrandLogo(size: 30, showName: true, onDark: true),
              ),
            ),
            const BellButton(),
            IconButton(
              key: const Key('home-search-button'),
              tooltip: 'Cari campaign',
              onPressed: onSearch,
              icon: Icon(Icons.search_rounded, color: cs.onPrimary),
            ),
            const SizedBox(width: AppSpace.xs),
            InkWell(
              key: const Key('home-avatar'),
              customBorder: const CircleBorder(),
              onTap: onAvatar,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                child: _Avatar(user: user, radius: 18),
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.xl),
          child,
        ]),
      ),
    ]);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.radius});
  final User? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pic = user?.picture;
    final name = user?.name ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      backgroundImage: pic != null ? NetworkImage(pic) : null,
      child: pic == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary))
          : null,
    );
  }
}

/// Judul section (Semi-Bold) + "Lihat Semua" merah di kanan.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.m, AppSpace.s),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (onSeeAll != null)
            TextButton(
              key: Key('see-all-$title'),
              onPressed: onSeeAll,
              child: const Text('Lihat Semua'),
            ),
        ]),
      );
}
