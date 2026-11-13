import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/platform_badge.dart';

/// Form submit link video ke campaign.
///
/// Validasi sisi klien (meniru backend): platform harus diterima campaign,
/// domain link harus sesuai platform, dan link yang sudah pernah kamu submit
/// ditolak. Backend tetap mengecek duplikat global (semua kreator).
class SubmitVideoView extends ConsumerStatefulWidget {
  const SubmitVideoView({super.key, required this.campaign});
  final Campaign campaign;

  @override
  ConsumerState<SubmitVideoView> createState() => _SubmitVideoViewState();
}

class _SubmitVideoViewState extends ConsumerState<SubmitVideoView> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  late VideoPlatform _platform = widget.campaign.platforms.first;
  bool _loading = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Auto-pilih platform dari link yang ditempel.
  void _onUrlChanged(String v) {
    final p = detectPlatform(v);
    if (p != null && p != _platform && widget.campaign.platforms.contains(p)) {
      setState(() => _platform = p);
    }
  }

  String? _validate(String? v) {
    final url = (v ?? '').trim();
    if (url.isEmpty) return 'Tempel link video kamu';
    final detected = detectPlatform(url);
    if (detected != null && !widget.campaign.platforms.contains(detected)) {
      return 'Campaign ini tidak menerima video ${detected.label}';
    }
    final err = validateVideoUrl(url, _platform);
    if (err != null) return err;
    final mine = ref.read(creatorSubmissionsProvider).value ?? const <Submission>[];
    final norm = normalizeVideoUrl(url);
    if (mine.any((s) => s.videoUrl == norm)) return 'Kamu sudah pernah submit video ini';
    return null;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _url.text = text;
    _onUrlChanged(text);
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(apiServiceProvider).submitVideo(
            campaignId: widget.campaign.campaignId,
            platform: _platform,
            videoUrl: _url.text,
          );
      refreshCreatorData(ref);
      if (!mounted) return;
      showAppSnack(context, 'Video terkirim! Status: Direview. Pantau di tab Konten.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan daftar submission sendiri dimuat untuk cek duplikat lokal.
    ref.watch(creatorSubmissionsProvider);
    final c = widget.campaign;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit video')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(c.title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${rp(c.ratePer1k)} / 1.000 views · minimal ${fmtNum(c.minViews)} views', style: t.bodyMedium),
            const SizedBox(height: 20),
            Text('Platform', style: t.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final p in c.platforms)
                ChoiceChip(
                  key: Key('submit-platform-${p.wire}'),
                  avatar: Icon(p.icon, size: 16),
                  label: Text(p.label),
                  selected: _platform == p,
                  onSelected: (_) => setState(() => _platform = p),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('submit-url-input'),
              controller: _url,
              keyboardType: TextInputType.url,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: _onUrlChanged,
              validator: _validate,
              decoration: InputDecoration(
                labelText: 'Link video ${_platform.label}',
                hintText: 'https://...',
                suffixIcon: IconButton(tooltip: 'Tempel', icon: const Icon(Icons.content_paste), onPressed: _paste),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '• Video harus publik dan sesuai brief campaign.\n'
                  '• Satu video hanya bisa didaftarkan sekali.\n'
                  '• Setelah disetujui brand, klaim views di tab Konten saat target tercapai.',
                  style: t.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              key: const Key('submit-video-button'),
              label: 'Kirim video',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
