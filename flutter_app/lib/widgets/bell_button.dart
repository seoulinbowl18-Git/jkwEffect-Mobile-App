import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../views/common/notifications_view.dart';

/// Ikon lonceng dengan badge jumlah notifikasi belum dibaca.
class BellButton extends ConsumerWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.unread ?? 0;
    return IconButton(
      key: const Key('bell-button'),
      tooltip: 'Notifikasi',
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsView()));
        ref.invalidate(notificationsProvider);
      },
      // Ikon putih di atas header gradasi; titik notifikasi putih bertulisan merah (kontras di atas merah).
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        textColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.notifications_rounded, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
