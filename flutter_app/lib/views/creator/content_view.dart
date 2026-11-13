import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/submission_card.dart';
import '../../widgets/app_header.dart';
import 'claim_proof_view.dart';

/// Filter status di halaman Konten. "Siap Diklaim" = konten sudah disetujui Admin Pusat dan
/// menunggu kreator mengirim klaim views + bukti analitik.
enum ContentFilter {
  all('Semua', {}),
  siapDiklaim('Siap Diklaim', {SubmissionStatus.menungguViews}),
  direview('Direview', {SubmissionStatus.direview}),
  dicek('Dicek views', {SubmissionStatus.diproses, SubmissionStatus.verifying}),
  selesai('Selesai', {SubmissionStatus.disetujui}),
  ditolak('Ditolak', {SubmissionStatus.ditolak});

  const ContentFilter(this.label, this.statuses);
  final String label;
  final Set<SubmissionStatus> statuses;

  bool matches(Submission s) => statuses.isEmpty || statuses.contains(s.status);
}

class ContentView extends ConsumerStatefulWidget {
  const ContentView({super.key});

  @override
  ConsumerState<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends ConsumerState<ContentView> {
  ContentFilter _filter = ContentFilter.all;

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(creatorSubmissionsProvider);
    return Scaffold(
      appBar: AppHeader(title: const Text('Konten saya')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final f in ContentFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('content-filter-${f.name}'),
                    label: Text(_chipLabel(f, subs.value)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(creatorSubmissionsProvider.future),
            child: AsyncView(
              value: subs,
              onRetry: () => ref.invalidate(creatorSubmissionsProvider),
              data: (all) {
                final items = all.where(_filter.matches).toList();
                final ready = all.where(ContentFilter.siapDiklaim.matches).toList();
                final banner = ready.isEmpty
                    ? null
                    : ReadyToClaimBanner(
                        items: ready,
                        onTap: _filter == ContentFilter.siapDiklaim
                            ? null
                            : () => setState(() => _filter = ContentFilter.siapDiklaim),
                      );
                if (items.isEmpty) {
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    ?banner,
                    EmptyState(
                      icon: Icons.video_library_outlined,
                      message: all.isEmpty
                          ? 'Belum ada konten. Cari campaign di tab Jelajah dan submit video pertamamu!'
                          : 'Tidak ada konten berstatus "${_filter.label}"',
                    ),
                  ]);
                }
                final offset = banner == null ? 0 : 1;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length + offset,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    if (i < offset) return banner!;
                    final s = items[i - offset];
                    return SubmissionCard(
                      key: Key('submission-${s.submissionId}'),
                      submission: s,
                      actions: [
                        if (s.status.canClaim)
                          FilledButton.icon(
                            key: Key('claim-views-button-${s.submissionId}'),
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Klaim'),
                            onPressed: () => _claim(s),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  String _chipLabel(ContentFilter f, List<Submission>? all) {
    if (all == null || f == ContentFilter.all) return f.label;
    final n = all.where(f.matches).length;
    return n == 0 ? f.label : '${f.label} ($n)';
  }

  Future<void> _claim(Submission s) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClaimProofView(submission: s)),
    );
    if (sent != true || !mounted) return;
    refreshCreatorData(ref);
    showAppSnack(context, 'Klaim & bukti terkirim. Brand akan mengecek secara manual.');
  }
}

/// Ringkasan konten yang siap diklaim + estimasi minimal rupiahnya
/// (views minimum campaign × rate; angka akhir mengikuti hasil verifikasi).
class ReadyToClaimBanner extends StatelessWidget {
  const ReadyToClaimBanner({super.key, required this.items, this.onTap});
  final List<Submission> items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final est = items.fold<int>(0, (sum, s) => sum + estimatePayout(s.minViews, s.ratePer1k));
    return Container(
      key: const Key('ready-to-claim-banner'),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.l),
          onTap: onTap,
          child: Padding(
            padding: AppSpace.card,
            child: Row(children: [
              const Icon(Icons.payments_rounded, color: AppTheme.onBrand, size: 32),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${items.length} video siap diklaim',
                      key: const Key('ready-to-claim-count'),
                      style: t.titleMedium?.copyWith(color: AppTheme.onBrand, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpace.xs),
                  Text('Estimasi min. ${rp(est)}',
                      key: const Key('ready-to-claim-total'),
                      style: t.titleSmall?.copyWith(color: AppTheme.onBrand, fontWeight: FontWeight.w700)),
                  Text('Kirim rekaman layar analitik untuk mencairkan.',
                      style: t.bodySmall?.copyWith(color: AppTheme.onBrand)),
                ]),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppTheme.onBrand),
            ]),
          ),
        ),
      ),
    );
  }
}
