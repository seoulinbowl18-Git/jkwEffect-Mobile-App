import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/app_header.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  @override
  void initState() {
    super.initState();
    // Tandai semua sudah dibaca begitu halaman dibuka (sama dengan versi Expo).
    unawaited(ref.read(apiServiceProvider).markAllNotificationsRead().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppHeader(title: const Text('Notifikasi')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: AsyncView(
          value: feed,
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (f) => f.items.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.notifications_off_outlined, message: 'Belum ada notifikasi')])
              : ListView.separated(
                  itemCount: f.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _NotificationTile(f.items[i]),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n);
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (n.kind) {
      'success' => (Icons.check_circle_rounded, AppTheme.success),
      'error' => (Icons.error_rounded, AppTheme.danger),
      _ => (Icons.info_rounded, AppTheme.info),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
      subtitle: Text('${n.body}\n${fmtDate(n.createdAt)}'),
      isThreeLine: true,
    );
  }
}
