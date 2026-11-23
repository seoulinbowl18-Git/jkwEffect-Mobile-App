import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/loading_button.dart';

/// Halaman setelah login untuk akun yang belum punya peran kreator/brand (member & relawan baru).
/// Tidak ada lagi pilihan Kreator/Brand: pengguna langsung diarahkan ke formulir pendaftaran
/// Relawan / Member atau halaman KTA digital di web Gibran for 2029.
class OnboardingView extends ConsumerWidget {
  const OnboardingView({super.key});

  Future<void> _open(BuildContext context, String path) async {
    final ok = await launchUrl(AppConfig.webPage(path), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showAppSnack(context, 'Tidak bisa membuka halaman pendaftaran.', isError: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text('Halo, ${user?.firstName ?? ''}!',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Ayo bergabung dengan Gibran for 2029. Pilih peranmu: daftar sebagai relawan atau member resmi.',
                style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            _JoinOption(
              key: const Key('onboarding-join-relawan'),
              icon: Icons.volunteer_activism_rounded,
              title: 'Daftar Relawan',
              desc: 'Ikut aksi sosial, kegiatan wilayah, dan misi konten kreator.',
              onTap: () => _open(context, '/daftar/relawan'),
            ),
            const SizedBox(height: 12),
            _JoinOption(
              key: const Key('onboarding-join-member'),
              icon: Icons.badge_rounded,
              title: 'Daftar Member',
              desc: 'Jadi member resmi & dapatkan KTA digital bernomor unik.',
              onTap: () => _open(context, '/daftar/anggota'),
            ),
            const SizedBox(height: 20),
            LoadingButton(
              key: const Key('onboarding-kta-button'),
              label: 'Lihat KTA Saya',
              outlined: true,
              onPressed: () => _open(context, '/kta'),
            ),
            const SizedBox(height: 12),
            Text('Formulir & KTA dibuka di browser. Masuk dengan akun Google yang sama.',
                textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            TextButton(
              key: const Key('onboarding-logout-button'),
              onPressed: () => ref.read(authProvider.notifier).logout(),
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinOption extends StatelessWidget {
  const _JoinOption({super.key, required this.icon, required this.title, required this.desc, required this.onTap});

  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.l),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(AppRadius.m)),
              child: Icon(icon, color: cs.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(desc, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            Icon(Icons.open_in_new_rounded, color: cs.primary),
          ]),
        ),
      ),
    );
  }
}
