import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/loading_button.dart';
import '../../core/theme.dart';

/// Pemilihan peran setelah login pertama. Backend hanya mengizinkan sekali
/// (`POST /users/role` → 400 "Role sudah dipilih" jika diulang).
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  UserRole _role = UserRole.creator;
  final _brandName = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _brandName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).chooseRole(
            _role,
            brandName: _role == UserRole.brand ? _brandName.text : null,
          );
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text('Halo, ${user?.firstName ?? ''}!',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Kamu mau pakai jkwEffect sebagai apa? Pilihan ini tidak bisa diubah.',
                style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            _RoleOption(
              key: const Key('onboarding-role-creator'),
              icon: Icons.videocam_rounded,
              title: 'Kreator',
              desc: 'Cari campaign, posting video, dapat cuan dari views.',
              selected: _role == UserRole.creator,
              onTap: () => setState(() => _role = UserRole.creator),
            ),
            const SizedBox(height: 12),
            _RoleOption(
              key: const Key('onboarding-role-brand'),
              icon: Icons.campaign_rounded,
              title: 'Brand',
              desc: 'Buat campaign, bayar per views, review konten kreator.',
              selected: _role == UserRole.brand,
              onTap: () => setState(() => _role = UserRole.brand),
            ),
            if (_role == UserRole.brand) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('onboarding-brand-name-input'),
                controller: _brandName,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Nama brand', hintText: user?.name),
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(
              key: const Key('onboarding-continue-button'),
              label: 'Lanjutkan',
              loading: _loading,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            LoadingButton(
              label: 'Keluar',
              outlined: true,
              onPressed: _loading ? null : () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
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
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Icon(icon, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? cs.primary : cs.outline),
          ]),
        ),
      ),
    );
  }
}
