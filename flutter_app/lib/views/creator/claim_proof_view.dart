import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/service_providers.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/platform_badge.dart';
import '../../widgets/premium.dart';

/// Batas sama dengan backend (`MAX_PROOF_*` di server.py).
const maxProofFiles = 3;
const maxProofImageBytes = 3 * 1024 * 1024;
const maxProofVideoBytes = 15 * 1024 * 1024;

/// Langkah membuka layar analitik per platform.
const proofGuides = <VideoPlatform, List<String>>{
  VideoPlatform.tiktok: [
    'Buka TikTok, masuk ke Profil, lalu buka video yang kamu daftarkan.',
    'Ketuk ikon tiga titik (•••) → "Analitik" (atau ketuk angka tayangan di bawah video).',
    'Tampilkan Total tayangan, Total waktu tonton, dan Rata-rata waktu tonton.',
    'Geser ke bawah supaya bagian Penonton & sumber trafik ikut terekam.',
  ],
  VideoPlatform.instagram: [
    'Buka Instagram, masuk ke Profil → tab Reels, lalu buka reel yang kamu daftarkan.',
    'Ketuk "Lihat insight" / "Lihat wawasan" di bawah reel.',
    'Tampilkan Tayangan (Views), Jangkauan akun, dan Waktu tonton.',
    'Geser ke bawah supaya detail interaksi ikut terekam.',
  ],
  VideoPlatform.threads: [
    'Buka Threads, masuk ke Profil, lalu buka postingan video yang kamu daftarkan.',
    'Ketuk ikon grafik / "Lihat insight" di bawah postingan.',
    'Tampilkan jumlah Tayangan (Views) dan interaksi postingan.',
  ],
  VideoPlatform.youtube: [
    'Buka aplikasi YouTube Studio → Konten → Shorts, lalu pilih video yang kamu daftarkan.',
    'Ketuk "Analytics" / "Analitik".',
    'Tampilkan Penayangan, Waktu tonton, dan Durasi rata-rata penayangan.',
  ],
};

const proofMustShow = [
  'Username akunmu (rekam mulai dari halaman profil)',
  'Video yang sama dengan link yang kamu daftarkan',
  'Total views / tayangan terbaru',
  'Waktu tonton (watch time) jika tersedia',
];

/// Halaman klaim: instruksi rekam layar analitik + form views & unggah bukti.
/// Mengembalikan `true` lewat [Navigator.pop] jika klaim terkirim.
class ClaimProofView extends ConsumerStatefulWidget {
  const ClaimProofView({super.key, required this.submission});
  final Submission submission;

  @override
  ConsumerState<ClaimProofView> createState() => _ClaimProofViewState();
}

class _ClaimProofViewState extends ConsumerState<ClaimProofView> {
  final _formKey = GlobalKey<FormState>();
  final _views = TextEditingController();
  final _note = TextEditingController();
  final _files = <PickedMedia>[];
  bool _sending = false;
  bool _picking = false;
  String? _fileError;

  @override
  void dispose() {
    _views.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _checkFile(PickedMedia f) {
    if (f.isVideo && f.size > maxProofVideoBytes) {
      return '${f.filename}: rekaman layar maksimal 15 MB. Potong videonya jadi lebih pendek.';
    }
    if (!f.isVideo && f.size > maxProofImageBytes) return '${f.filename}: screenshot maksimal 3 MB.';
    return null;
  }

  Future<void> _pick({bool videoOnly = false}) async {
    final left = maxProofFiles - _files.length;
    if (left <= 0) return;
    setState(() => _picking = true);
    try {
      final picker = ref.read(imagePickerServiceProvider);
      final picked = videoOnly
          ? [?await picker.pickProofVideo()]
          : await picker.pickProofMedia(limit: left);
      if (!mounted || picked.isEmpty) return;
      final errors = <String>[];
      for (final f in picked.take(left)) {
        final err = _checkFile(f);
        err == null ? _files.add(f) : errors.add(err);
      }
      if (picked.length > left) errors.add('Maksimal $maxProofFiles file bukti.');
      setState(() => _fileError = errors.isEmpty ? null : errors.join('\n'));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    if (_files.isEmpty) {
      setState(() => _fileError = 'Lampirkan minimal 1 screenshot atau rekaman layar analitik.');
    }
    if (!formOk || _files.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiServiceProvider).claimWithProof(
            widget.submission.submissionId,
            views: parseAmount(_views.text),
            files: List.of(_files),
            note: _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final views = parseAmount(_views.text);
    final steps = proofGuides[s.platform] ?? proofGuides[VideoPlatform.tiktok]!;

    return Scaffold(
      appBar: AppHeader(title: const Text('Klaim views')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(padding: AppSpace.page, children: [
            PremiumCard(
              padding: AppSpace.card,
              child: Row(children: [
                IconBadge(s.platform.icon),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.campaignTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpace.xs),
                    Text('Min. ${fmtNum(s.minViews)} views · ${rp(s.ratePer1k)}/1K views', style: t.bodySmall),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
            Text('1. Rekam layar analitik ${s.platform.label}',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpace.s),
            PremiumCard(
              key: const Key('claim-guide'),
              padding: AppSpace.card,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppTheme.softPink,
                        child: Text('${i + 1}',
                            style: t.labelSmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(child: Text(steps[i], style: t.bodyMedium)),
                    ]),
                  ),
                const Divider(height: AppSpace.xl),
                Text('Pastikan rekaman memperlihatkan:', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpace.s),
                for (final m in proofMustShow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.success),
                      const SizedBox(width: AppSpace.s),
                      Expanded(child: Text(m, style: t.bodySmall)),
                    ]),
                  ),
                const SizedBox(height: AppSpace.s),
                Text(
                  'Tips: pakai fitur Rekam Layar bawaan HP, rekam tanpa dipotong, durasi 15–60 detik. '
                  'Video maks. 15 MB, screenshot maks. 3 MB.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
            Text('2. Unggah bukti', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpace.xs),
            Text('1–$maxProofFiles file: rekaman layar (MP4/MOV) atau screenshot (JPG/PNG).', style: t.bodySmall),
            const SizedBox(height: AppSpace.s),
            for (var i = 0; i < _files.length; i++)
              _PickedTile(
                key: Key('proof-file-$i'),
                file: _files[i],
                onRemove: _sending ? null : () => setState(() => _files.removeAt(i)),
              ),
            if (_files.length < maxProofFiles)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('proof-pick-button'),
                    onPressed: _picking || _sending ? null : _pick,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_files.isEmpty ? 'Pilih dari galeri' : 'Tambah file'),
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('proof-pick-video-button'),
                    onPressed: _picking || _sending ? null : () => _pick(videoOnly: true),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Rekaman layar'),
                  ),
                ),
              ]),
            if (_fileError != null) ...[
              const SizedBox(height: AppSpace.s),
              Text(_fileError!, key: const Key('proof-file-error'), style: t.bodySmall?.copyWith(color: cs.error)),
            ],
            const SizedBox(height: AppSpace.xl),
            Text('3. Jumlah views', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpace.s),
            TextFormField(
              key: const Key('claim-views-input'),
              controller: _views,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Total views sesuai bukti',
                hintText: 'contoh: 25000',
                helperText: 'Minimal ${fmtNum(s.minViews)} views',
              ),
              validator: (v) {
                final n = parseAmount(v ?? '');
                if (n <= 0) return 'Isi jumlah views';
                if (n < s.minViews) return 'Views minimal ${fmtNum(s.minViews)}';
                return null;
              },
            ),
            if (views > 0) ...[
              const SizedBox(height: AppSpace.s),
              Text(
                'Estimasi pendapatan: ${rp(estimatePayout(views, s.ratePer1k))}',
                key: const Key('claim-estimate'),
                style: t.bodyMedium?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: AppSpace.l),
            TextFormField(
              key: const Key('claim-note-input'),
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan untuk brand (opsional)'),
            ),
            const SizedBox(height: AppSpace.l),
            LoadingButton(
              key: const Key('claim-submit-button'),
              label: 'Kirim klaim',
              icon: const Icon(Icons.send_rounded),
              loading: _sending,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpace.s),
            Text('Brand/admin akan mengecek bukti secara manual. Views yang dibayar mengikuti hasil verifikasi.',
                textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _PickedTile extends StatelessWidget {
  const _PickedTile({super.key, required this.file, required this.onRemove});
  final PickedMedia file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mb = (file.size / (1024 * 1024)).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: SizedBox.square(
              dimension: 48,
              child: file.isVideo
                  ? ColoredBox(
                      color: AppTheme.softPink,
                      child: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary),
                    )
                  : Image.memory(
                      Uint8List.fromList(file.bytes),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                    ),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${file.isVideo ? 'Rekaman layar' : 'Screenshot'} · $mb MB',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
      ),
    );
  }
}
