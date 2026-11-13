import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../brand/brand_home_view.dart';
import '../brand/brand_wallet_view.dart';
import '../brand/review_view.dart';
import '../common/profile_view.dart';
import '../creator/cari_cuan_view.dart';
import '../creator/content_view.dart';
import '../creator/wallet_view.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

/// Navigasi utama per peran — meniru `(tabs)` di versi Expo:
/// Kreator: Cari Cuan · Konten · Dompet · Profil
/// Brand:   Beranda · Review · Saldo · Profil
///
/// Tab dibangun saat pertama kali dibuka lalu dipertahankan (IndexedStack),
/// sehingga filter/scroll tidak hilang saat berpindah tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final User user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  late final List<_Tab> _tabs = widget.user.isBrand
      ? const [
          _Tab('Beranda', Icons.space_dashboard_rounded, BrandHomeView()),
          _Tab('Review', Icons.fact_check_rounded, ReviewView()),
          _Tab('Saldo', Icons.account_balance_wallet_rounded, BrandWalletView()),
          _Tab('Profil', Icons.person_rounded, ProfileView()),
        ]
      : const [
          _Tab('Cari Cuan', Icons.local_fire_department_rounded, CariCuanView()),
          _Tab('Konten', Icons.video_library_rounded, ContentView()),
          _Tab('Dompet', Icons.account_balance_wallet_rounded, WalletView()),
          _Tab('Profil', Icons.person_rounded, ProfileView()),
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++) _visited.contains(i) ? _tabs[i].page : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(key: Key('tab-${t.label}'), icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
