import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'platform_badge.dart';
import 'status_chip.dart';

/// Kartu submission. Kreator melihat judul campaign; brand melihat nama kreator.
class SubmissionCard extends StatelessWidget {
  const SubmissionCard({super.key, required this.submission, this.forBrand = false, this.actions = const []});

  final Submission submission;
  final bool forBrand;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final views = s.verifiedViews > 0 ? s.verifiedViews : s.claimedViews;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(s.platform.icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                forBrand ? s.creatorName : s.campaignTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            StatusChip(s.status.label, s.status.tone),
          ]),
          if (forBrand) Text(s.campaignTitle, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => launchUrl(Uri.parse(s.videoUrl), mode: LaunchMode.externalApplication),
            child: Text(
              s.videoUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: cs.primary, decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _Metric(s.verifiedViews > 0 ? 'Views terverifikasi' : 'Views diklaim', views > 0 ? fmtNum(views) : '-'),
            _Metric('Pendapatan', s.payout > 0 ? rp(s.payout) : '-'),
            _Metric('Dikirim', fmtDate(s.createdAt)),
          ]),
          if (s.proofs.isNotEmpty) ...[
            const SizedBox(height: AppSpace.m),
            ProofStrip(proofs: s.proofs, submissionId: s.submissionId),
          ],
          if (s.claimNote.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s),
            Text('Catatan kreator: ${s.claimNote}', style: t.bodySmall),
          ],
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan: ${s.note}', style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: actions[i]),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Deretan bukti analitik (screenshot / rekaman layar). Ketuk gambar untuk
/// memperbesar; video dibuka di pemutar bawaan HP/browser.
class ProofStrip extends StatelessWidget {
  const ProofStrip({super.key, required this.proofs, required this.submissionId});
  final List<SubmissionProof> proofs;
  final String submissionId;

  Future<void> _open(BuildContext context, SubmissionProof p) async {
    if (p.isVideo) {
      await launchUrl(Uri.parse(p.absoluteUrl), mode: LaunchMode.externalApplication);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpace.l),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          InteractiveViewer(
            child: Image.network(p.absoluteUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(AppSpace.xl),
                      child: Text('Bukti tidak bisa dimuat. Tarik ke bawah untuk memuat ulang.'),
                    )),
          ),
          Positioned(
            right: AppSpace.xs,
            top: AppSpace.xs,
            child: IconButton.filledTonal(
              tooltip: 'Tutup',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bukti analitik (${proofs.length})', style: t.labelSmall),
      const SizedBox(height: AppSpace.xs),
      Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
        for (var i = 0; i < proofs.length; i++)
          InkWell(
            key: Key('proof-$submissionId-$i'),
            borderRadius: BorderRadius.circular(AppRadius.s),
            onTap: () => _open(context, proofs[i]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: SizedBox.square(
                dimension: 56,
                child: ColoredBox(
                  color: AppTheme.softPink,
                  child: proofs[i].isVideo
                      ? const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary, size: 28)
                      : Image.network(
                          proofs[i].absoluteUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: AppTheme.primary),
                        ),
                ),
              ),
            ),
          ),
      ]),
    ]);
  }
}
