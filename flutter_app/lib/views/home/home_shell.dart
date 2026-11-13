import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../widgets/sync_watcher.dart';
import '../admin/admin_dashboard_view.dart';
import '../admin/admin_withdrawals_view.dart';
import '../brand/brand_home_view.dart';
import '../brand/brand_wallet_view.dart';
import '../common/profile_view.dart';
import '../creator/cari_cuan_view.dart';
import '../creator/creator_home_view.dart';
import '../creator/wallet_view.dart';

/// Tab aktif di [HomeShell]. Halaman lain (mis. Beranda) bisa pindah tab:
/// `ref.read(homeTabProvider.notifier).go(1)`.
class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void go(int index) => state = index;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

/// Indeks tab kreator (dipakai tombol pintasan di Beranda).
class CreatorTab {
  static const home = 0, explore = 1, wallet = 2, profile = 3;
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

/// Navigasi utama per peran (NavigationBar Material 3):
/// Kreator: Beranda · Jelajah · Dompet · Profil
/// Brand:   Beranda · Saldo · Profil (review konten ditangani Admin Pusat di web)
/// Admin:   Ringkasan · Withdraw · Profil
///
/// Tab dibangun saat pertama kali dibuka lalu dipertahankan (IndexedStack).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.user});
  final User user;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final Set<int> _visited = {0};

  late final List<_Tab> _tabs = switch (widget.user.role) {
    UserRole.admin => const [
      _Tab('Ringkasan', Icons.insights_outlined, Icons.insights_rounded, AdminDashboardView()),
      _Tab('Withdraw', Icons.payments_outlined, Icons.payments_rounded, AdminWithdrawalsView()),
      _Tab('Profil', Icons.person_outline_rounded, Icons.person_rounded, ProfileView()),
    ],
    UserRole.brand => const [
      _Tab('Beranda', Icons.home_outlined, Icons.home_rounded, BrandHomeView()),
      _Tab('Saldo', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, BrandWalletView()),
      _Tab('Profil', Icons.person_outline_rounded, Icons.person_rounded, ProfileView()),
    ],
    _ => const [
      _Tab('Beranda', Icons.home_outlined, Icons.home_rounded, CreatorHomeView()),
      _Tab('Jelajah', Icons.search_rounded, Icons.manage_search_rounded, CariCuanView()),
      _Tab('Dompet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, WalletView()),
      _Tab('Profil', Icons.person_outline_rounded, Icons.person_rounded, ProfileView()),
    ],
  };

  @override
  void initState() {
    super.initState();
    // Selalu mulai dari tab pertama setelah login / ganti akun.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(homeTabProvider.notifier).go(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabProvider).clamp(0, _tabs.length - 1);
    _visited.add(index);
    return SyncWatcher(
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _tabs.length; i++) _visited.contains(i) ? _tabs[i].page : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(homeTabProvider.notifier).go(i),
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                key: Key('tab-${t.label}'),
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}
