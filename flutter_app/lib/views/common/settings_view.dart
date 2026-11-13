import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/app_header.dart';
import 'edit_profile_view.dart';
import 'faq_view.dart';
import 'notifications_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: const AppHeader(title: Text('Pengaturan')),
      body: ListView(
        padding: AppSpace.page,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.person_rounded, color: cs.primary),
                title: const Text('Edit profil & rekening'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => push(const EditProfileView()),
              ),
              ListTile(
                leading: Icon(Icons.notifications_rounded, color: cs.primary),
                title: const Text('Notifikasi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => push(const NotificationsView()),
              ),
              ListTile(
                leading: Icon(Icons.help_rounded, color: cs.primary),
                title: const Text('Bantuan & FAQ'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => push(const FaqView()),
              ),
              ListTile(
                leading: Icon(Icons.info_rounded, color: cs.primary),
                title: const Text('Tentang aplikasi'),
                subtitle: Text('PAGI v${AppConfig.appVersion}'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
