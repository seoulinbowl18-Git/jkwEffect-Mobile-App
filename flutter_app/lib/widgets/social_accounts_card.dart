import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/data_providers.dart';
import '../providers/service_providers.dart';
import 'app_snackbar.dart';
import 'form_helpers.dart';
import 'premium.dart';

/// Section "Akun Sosial Media" di Profil kreator: TikTok / Instagram / Threads
/// (+ Tambah, Ubah, Putuskan) dan "Hubungkan Telegram" untuk komunitas Gibran for 2029.
///
/// Hubungkan Telegram membuka bot resmi lewat deep link sekali pakai
/// (`https://t.me/<bot>?start=<kode>`) di aplikasi Telegram. Saat pengguna kembali
/// ke aplikasi, status akun dimuat ulang (bot sudah mencatat akunnya lewat webhook).
class SocialAccountsCard extends ConsumerStatefulWidget {
  const SocialAccountsCard({super.key});

  @override
  ConsumerState<SocialAccountsCard> createState() => _SocialAccountsCardState();
}

class _SocialAccountsCardState extends ConsumerState<SocialAccountsCard> with WidgetsBindingObserver {
  String _busy = '';
  bool _waitingTelegram = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_waitingTelegram) return;
    // Kembali dari Telegram: muat ulang status, lalu sekali lagi sebentar kemudian
    // (balasan bot ke backend bisa datang beberapa detik setelah START ditekan).
    ref.invalidate(socialAccountsProvider);
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 4), () {
      if (mounted) ref.invalidate(socialAccountsProvider);
    });
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _edit(SocialPlatform p, SocialAccount? current) async {
    final handle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _HandleSheet(platform: p, initial: current?.username ?? ''),
    );
    if (handle == null || handle.trim().isEmpty || !mounted) return;
    await _run(p.wire, () async {
      await ref.read(apiServiceProvider).linkSocial(p, handle);
      ref.invalidate(socialAccountsProvider);
      if (mounted) showAppSnack(context, 'Akun ${p.label} tersimpan');
    });
  }

  Future<void> _unlink(String wire, String label) async {
    final ok = await confirmDialog(context,
        title: 'Putuskan $label?', message: 'Akun $label tidak lagi terhubung ke Gibran for 2029.', confirmLabel: 'Putuskan', destructive: true);
    if (!ok || !mounted) return;
    await _run(wire, () async {
      await ref.read(apiServiceProvider).unlinkSocial(wire);
      ref.invalidate(socialAccountsProvider);
      if (mounted) showAppSnack(context, '$label diputuskan');
    });
  }

  Future<void> _connectTelegram() => _run('telegram', () async {
        final url = await ref.read(apiServiceProvider).telegramLinkUrl();
        _waitingTelegram = true;
        final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!opened) throw Exception('Tidak bisa membuka Telegram. Pasang aplikasi Telegram lalu coba lagi.');
        if (mounted) showAppSnack(context, 'Ketuk START di bot Gibran for 2029, lalu kembali ke aplikasi ini.');
      });

  Future<void> _openGroup(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && mounted) {
      showAppSnack(context, 'Tidak bisa membuka Telegram.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final social = ref.watch(socialAccountsProvider);
    final community = ref.watch(communityProvider).value ?? const CommunityLinks();
    final data = social.value;
    final tg = data?.telegram;

    return PremiumCard(
      key: const Key('social-accounts-card'),
      padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.l, AppSpace.l, AppSpace.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Akun Sosial Media', style: t.titleLarge),
        const SizedBox(height: AppSpace.xs),
        Text('Akun yang terhubung dipakai untuk semua submission. Telegram untuk komunitas dan info campaign terbaru.',
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        if (social.isLoading && data == null)
          const Padding(padding: EdgeInsets.all(AppSpace.l), child: Center(child: CircularProgressIndicator()))
        else if (social.hasError && data == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
            child: TextButton.icon(
              onPressed: () => ref.invalidate(socialAccountsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Gagal memuat. Coba lagi'),
            ),
          )
        else ...[
          for (final p in SocialPlatform.values) ...[
            _SocialRow(
              key: Key('social-${p.wire}'),
              platform: p,
              account: data?[p],
              busy: _busy == p.wire,
              onAdd: () => _edit(p, null),
              onEdit: () => _edit(p, data?[p]),
              onUnlink: () => _unlink(p.wire, p.label),
            ),
            const Divider(),
          ],
          // ---------------- Telegram ----------------
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
            child: Row(children: [
              const _BrandTile(color: AppTheme.telegram, icon: Icons.send_rounded),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpace.s, children: [
                  Text('Telegram', style: t.titleMedium),
                  if (tg != null)
                    Text('Terhubung · ${tg.display}',
                        key: const Key('social-telegram-status'),
                        style: t.bodyMedium?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w700)),
                ]),
              ),
              if (tg != null)
                _LinkAction(
                  key: const Key('social-telegram-unlink'),
                  icon: Icons.link_off_rounded,
                  label: 'Putuskan',
                  color: cs.primary,
                  onTap: _busy.isEmpty ? () => _unlink('telegram', 'Telegram') : null,
                ),
            ]),
          ),
          _TelegramButton(
            buttonKey: Key(tg != null ? 'social-telegram-group' : 'social-telegram-connect'),
            label: tg != null
                ? 'Buka grup komunitas'
                : community.connectEnabled
                    ? 'Hubungkan Telegram'
                    : community.telegramUrl.isNotEmpty
                        ? 'Gabung grup Telegram'
                        : 'Hubungkan Telegram (segera hadir)',
            busy: _busy == 'telegram',
            onPressed: tg != null
                ? (community.telegramUrl.isEmpty ? null : () => _openGroup(community.telegramUrl))
                : community.connectEnabled
                    ? _connectTelegram
                    : community.telegramUrl.isNotEmpty
                        ? () => _openGroup(community.telegramUrl)
                        : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, AppSpace.s, 0, AppSpace.s),
            child: Text(
              tg != null
                  ? 'Info campaign baru dan pengumuman Gibran for 2029 dikirim lewat Telegram.'
                  : 'Kamu otomatis diarahkan ke grup komunitas Telegram Gibran for 2029 lewat bot resmi kami.',
              style: t.bodySmall,
            ),
          ),
        ],
      ]),
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    super.key,
    required this.platform,
    required this.account,
    required this.busy,
    required this.onAdd,
    required this.onEdit,
    required this.onUnlink,
  });

  final SocialPlatform platform;
  final SocialAccount? account;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final acc = account;
    final tile = switch (platform) {
      SocialPlatform.tiktok => const _BrandTile(color: AppTheme.tiktok, icon: Icons.music_note_rounded),
      SocialPlatform.instagram => const _BrandTile(gradient: AppTheme.instagramGradient, icon: Icons.camera_alt_rounded),
      SocialPlatform.threads => const _BrandTile(color: AppTheme.threads, icon: Icons.alternate_email_rounded),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
      child: Row(children: [
        tile,
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(platform.label, style: t.titleMedium),
            if (acc != null)
              InkWell(
                onTap: () => launchUrl(Uri.parse(acc.url), mode: LaunchMode.externalApplication),
                child: Text('@${acc.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
              )
            else
              Text('Belum terhubung', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
        if (busy)
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else if (acc == null)
          _LinkAction(key: Key('social-${platform.wire}-add'), icon: Icons.add_rounded, label: 'Tambah', color: cs.primary, onTap: onAdd)
        else ...[
          _LinkAction(key: Key('social-${platform.wire}-edit'), icon: Icons.edit_rounded, label: 'Ubah', color: cs.onSurfaceVariant, onTap: onEdit),
          _LinkAction(key: Key('social-${platform.wire}-unlink'), icon: Icons.link_off_rounded, label: 'Putuskan', color: cs.primary, onTap: onUnlink),
        ],
      ]),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({super.key, required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.icon, this.color, this.gradient});
  final IconData icon;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(AppRadius.m)),
        child: Icon(icon, size: 22, color: AppTheme.onBrand),
      );
}

class _TelegramButton extends StatelessWidget {
  const _TelegramButton({required this.buttonKey, required this.label, required this.busy, required this.onPressed});
  final Key buttonKey;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        key: buttonKey,
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.telegram,
          foregroundColor: AppTheme.onBrand,
          disabledBackgroundColor: AppTheme.telegram.withValues(alpha: 0.5),
          disabledForegroundColor: AppTheme.onBrand,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        ),
        child: busy
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.onBrand))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.send_rounded, size: 20),
                const SizedBox(width: AppSpace.s),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
      );
}

/// Lembar input username / link profil.
class _HandleSheet extends StatefulWidget {
  const _HandleSheet({required this.platform, required this.initial});
  final SocialPlatform platform;
  final String initial;

  @override
  State<_HandleSheet> createState() => _HandleSheetState();
}

class _HandleSheetState extends State<_HandleSheet> {
  late final _c = TextEditingController(text: widget.initial.isEmpty ? '' : '@${widget.initial}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    if (_c.text.trim().isEmpty) return;
    Navigator.pop(context, _c.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, MediaQuery.viewInsetsOf(context).bottom + AppSpace.l),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.initial.isEmpty ? 'Tambah' : 'Ubah'} akun ${widget.platform.label}', style: t.titleLarge),
          const SizedBox(height: AppSpace.m),
          TextField(
            key: Key('social-${widget.platform.wire}-input'),
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: widget.platform.hint, hintText: '@username'),
          ),
          const SizedBox(height: AppSpace.l),
          GradientButton(
            buttonKey: Key('social-${widget.platform.wire}-save'),
            icon: Icons.check_rounded,
            label: 'Simpan',
            showChevron: false,
            onPressed: _submit,
          ),
        ]),
      ),
    );
  }
}
