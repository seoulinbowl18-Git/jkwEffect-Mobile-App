import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/brand_logo.dart';
import 'admin_login_view.dart';

/// Halaman login minimalis: satu-satunya cara masuk adalah Google Sign-In
/// (akun baru dibuat otomatis saat pertama kali masuk).
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  bool _busy = false;

  /// Mode tampilan (seperti halaman utama web): Saya Kreator / Saya Brand.
  bool _brandMode = false;

  Future<void> _open(Uri? uri, String unavailable) async {
    if (uri == null) {
      showAppSnack(context, unavailable);
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showAppSnack(context, 'Tidak bisa membuka tautan.', isError: true);
    }
  }

  /// "Hubungi Kami" → chat WhatsApp admin dengan pesan pendaftaran brand.
  Future<void> _contactAdmin() => _open(AppConfig.whatsappUri(), 'Kontak WhatsApp admin segera tersedia');

  /// "Gabung Komunitas" → grup Telegram GIBRAN2029 (link dari backend).
  Future<void> _joinCommunity() async {
    final url = (await ref.read(communityProvider.future).catchError((_) => const CommunityLinks())).telegramUrl;
    if (mounted) await _open(url.isEmpty ? null : Uri.parse(url), 'Link grup Telegram GIBRAN2029 segera tersedia');
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      // Sukses → AuthGate otomatis pindah ke onboarding / home.
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final pad = MediaQuery.paddingOf(context);

    Widget narrow(Widget child) => Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child),
        );

    final hero = GradientPanel(
      bottomRadius: AppRadius.header + AppSpace.s,
      padding: EdgeInsets.fromLTRB(AppSpace.xl, pad.top + AppSpace.xxl, AppSpace.xl, AppSpace.xxl + AppSpace.s),
      child: narrow(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BrandLogo(size: 38, showName: true, onDark: true),
        const SizedBox(height: AppSpace.xxl),
        Text(_brandMode ? 'Bikin brand kamu\nviral' : 'Satukan Barisan,\nKawal Masa Depan.',
            key: const Key('login-hero-title'), style: t.headlineLarge?.copyWith(color: cs.onPrimary, height: 1.15)),
        const SizedBox(height: AppSpace.m),
        Text(
          _brandMode
              ? 'Ratusan kreator TikTok, Instagram, YouTube, dan Threads siap posting konten brand kamu. '
                  'Bayar hanya untuk views yang benar-benar terverifikasi.'
              : 'Bergabunglah dalam barisan relawan dan member resmi GIBRAN2029. '
                  'Satu langkah nyata untuk gerakan perubahan Indonesia.',
          style: t.bodyLarge?.copyWith(color: AppTheme.onBrandAlpha(0.9)),
        ),
        const SizedBox(height: AppSpace.xl),
        _ModeToggle(brandMode: _brandMode, onChanged: (v) => setState(() => _brandMode = v)),
      ])),
    );

    final benefits = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, 0),
      child: narrow(Column(children: [
        for (final (icon, label) in _brandMode
            ? const [
                (Icons.campaign_rounded, 'Buat campaign, tentukan rate per 1.000 views'),
                (Icons.verified_rounded, 'Bayar hanya untuk views yang terverifikasi'),
                (Icons.insights_rounded, 'Pantau views & budget campaign secara real-time'),
              ]
            : const [
                (Icons.badge_rounded, 'Daftar member resmi & dapatkan KTA digital'),
                (Icons.hub_rounded, 'Terhubung dengan koordinasi wilayah hingga kelurahan'),
                (Icons.volunteer_activism_rounded, 'Ikut aksi, kegiatan, dan gerakan relawan'),
              ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.m),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.m)),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(child: Text(label, style: t.titleSmall)),
            ]),
          ),
      ])),
    );

    final signIn = Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, pad.bottom + AppSpace.xl),
      child: narrow(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _GoogleButton(busy: _busy, onPressed: _google),
        const SizedBox(height: AppSpace.m),
        OutlinedButton.icon(
          key: Key(_brandMode ? 'login-contact-button' : 'login-community-button'),
          onPressed: _busy ? null : (_brandMode ? _contactAdmin : _joinCommunity),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.primary, width: 1.4),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          ),
          icon: Icon(_brandMode ? Icons.chat_rounded : Icons.send_rounded, size: 20),
          label: Text(_brandMode ? 'Hubungi Kami' : 'Gabung Komunitas'),
        ),
        const SizedBox(height: AppSpace.m),
        Text('Belum punya akun? Akun dibuat otomatis saat pertama kali masuk.',
            textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: AppSpace.l),
        Text('Dengan masuk, kamu menyetujui Syarat & Ketentuan GIBRAN2029.',
            textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.outline)),
        // Pintu masuk khusus Owner (OTP WhatsApp); sengaja dibuat tidak menonjol.
        TextButton(
          key: const Key('login-admin-link'),
          onPressed: _busy
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdminLoginView())),
          child: Text('Admin Pusat', style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ])),
    );

    // Atas (hero + keunggulan) & bawah (tombol Google) dipisah spaceBetween: tombol menempel
    // di bawah layar bila muat; di layar kecil / huruf besar halaman tetap bisa digulir.
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Column(children: [hero, benefits]), signIn],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol "Masuk dengan Google": gradasi merah premium + lencana "G" putih.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.buttonGradient,
        borderRadius: radius,
        boxShadow: AppTheme.glowShadow,
      ),
      child: FilledButton(
        key: const Key('login-google-button'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: cs.onPrimary,
          disabledForegroundColor: cs.onPrimary,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                    child: Text(
                      'G',
                      style: t.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: AppSpace.m),
                  const Flexible(child: Text('Masuk dengan Google', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}


/// Pilihan mode di hero: "Saya Kreator" / "Saya Brand" (pill putih untuk yang aktif).
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.brandMode, required this.onChanged});
  final bool brandMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    Widget item(bool brand, IconData icon, String label) {
      final active = brand == brandMode;
      return Flexible(
        child: Material(
          color: active ? cs.surface : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            key: Key(brand ? 'login-mode-brand' : 'login-mode-creator'),
            customBorder: const StadiumBorder(),
            onTap: () => onChanged(brand),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.m - 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: active ? cs.primary : AppTheme.onBrand),
                const SizedBox(width: AppSpace.s),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelLarge?.copyWith(color: active ? cs.primary : AppTheme.onBrand)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(color: AppTheme.onBrandAlpha(0.15), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        item(false, Icons.person_rounded, 'Saya Kreator'),
        item(true, Icons.storefront_rounded, 'Saya Brand'),
      ]),
    );
  }
}
