import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/form_helpers.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 26,
              backgroundImage: user.picture != null ? NetworkImage(user.picture!) : null,
              child: user.picture == null ? Text(user.name.isEmpty ? '?' : user.name[0]) : null,
            ),
            title: Text(user.isBrand ? user.brandName : user.name,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(user.email),
            trailing: Chip(label: Text(user.isBrand ? 'Brand' : 'Kreator')),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: [
              if (user.isCreator) ...[
                ListTile(title: const Text('Saldo'), trailing: Text(rp(user.balance))),
                ListTile(title: const Text('Total pendapatan'), trailing: Text(rp(user.totalEarned))),
              ] else
                ListTile(title: const Text('Saldo brand'), trailing: Text(rp(user.brandBalance))),
            ]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('logout-button'),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Keluar?', message: 'Kamu perlu login lagi nanti.', confirmLabel: 'Keluar');
              if (ok) await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
