import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/service_providers.dart';

/// Sinkron real-time dengan web & Owner: cek `GET /api/sync` tiap [interval] dan saat aplikasi
/// dibuka lagi. Bila nomor versinya berubah, data user (saldo dsb.) dan semua daftar dimuat ulang,
/// jadi perubahan dari web / Owner tampil di aplikasi dalam hitungan detik.
class SyncWatcher extends ConsumerStatefulWidget {
  const SyncWatcher({super.key, required this.child, this.interval = const Duration(seconds: 15)});
  final Widget child;
  final Duration interval;

  @override
  ConsumerState<SyncWatcher> createState() => _SyncWatcherState();
}

class _SyncWatcherState extends ConsumerState<SyncWatcher> with WidgetsBindingObserver {
  Timer? _timer;
  int? _version;
  bool _busy = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.interval, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _poll();
  }

  Future<void> _poll() async {
    if (_busy || !_foreground || !mounted) return;
    _busy = true;
    try {
      final v = await ref.read(apiServiceProvider).syncVersion();
      final changed = _version != null && v != _version;
      _version = v;
      if (changed && mounted) await _refreshAll();
    } catch (_) {
      // Offline / server sibuk: coba lagi di putaran berikutnya.
    } finally {
      _busy = false;
    }
  }

  Future<void> _refreshAll() async {
    ref
      ..invalidate(campaignSectionsProvider)
      ..invalidate(campaignListProvider)
      ..invalidate(campaignDetailProvider)
      ..invalidate(campaignsBySortProvider)
      ..invalidate(creatorStatsProvider)
      ..invalidate(creatorSubmissionsProvider)
      ..invalidate(withdrawalsProvider)
      ..invalidate(brandStatsProvider)
      ..invalidate(brandCampaignsProvider)
      ..invalidate(topupsProvider)
      ..invalidate(brandWithdrawalsProvider)
      ..invalidate(ledgerProvider)
      ..invalidate(notificationsProvider)
      ..invalidate(adminStatsProvider)
      ..invalidate(adminWithdrawalsProvider)
      ..invalidate(socialAccountsProvider);
    // Saldo & status akun; bila akun ditangguhkan, sesi ditolak dan aplikasi kembali ke login.
    await ref.read(authProvider.notifier).refreshUser();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
