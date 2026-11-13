import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/submission_card.dart';

/// Filter panel review (urutan sama dengan versi Expo). `null` = semua.
const _filters = <(String, SubmissionStatus?)>[
  ('Review konten', SubmissionStatus.direview),
  ('Cek views', SubmissionStatus.diproses),
  ('Menunggu klaim', SubmissionStatus.menungguViews),
  ('Selesai', SubmissionStatus.disetujui),
  ('Ditolak', SubmissionStatus.ditolak),
  ('Semua', null),
];

class ReviewView extends ConsumerStatefulWidget {
  const ReviewView({super.key});

  @override
  ConsumerState<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<ReviewView> {
  SubmissionStatus? _status = SubmissionStatus.direview;

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(brandSubmissionsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('Review', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final (label, status) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('review-filter-${status?.wire ?? 'all'}'),
                    label: Text(label),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(brandSubmissionsProvider(_status).future),
            child: AsyncView(
              value: subs,
              onRetry: () => ref.invalidate(brandSubmissionsProvider(_status)),
              data: (items) => items.isEmpty
                  ? ListView(children: const [
                      EmptyState(icon: Icons.inbox_outlined, message: 'Tidak ada submission di sini'),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => SubmissionCard(
                        key: Key('review-${items[i].submissionId}'),
                        submission: items[i],
                        forBrand: true,
                        actions: _actionsFor(items[i]),
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _actionsFor(Submission s) {
    if (s.status.needsContentReview) {
      return [
        OutlinedButton(
          key: Key('reject-content-${s.submissionId}'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
          onPressed: () => _reviewContent(s, approve: false),
          child: const Text('Tolak'),
        ),
        FilledButton(
          key: Key('approve-content-${s.submissionId}'),
          onPressed: () => _reviewContent(s, approve: true),
          child: const Text('Setujui'),
        ),
      ];
    }
    if (s.status.needsViewVerification) {
      return [
        FilledButton.icon(
          key: Key('verify-views-${s.submissionId}'),
          icon: const Icon(Icons.visibility_rounded),
          label: const Text('Cek views'),
          onPressed: () => _verify(s),
        ),
      ];
    }
    return const [];
  }

  Future<void> _reviewContent(Submission s, {required bool approve}) async {
    String note = '';
    if (!approve) {
      final n = await noteDialog(context, title: 'Tolak konten?', confirmLabel: 'Tolak');
      if (n == null) return;
      note = n;
    }
    try {
      await ref.read(apiServiceProvider).reviewContent(s.submissionId, approve: approve, note: note);
      refreshBrandData(ref);
      if (mounted) {
        showAppSnack(context, approve ? 'Konten disetujui. Kreator bisa klaim views.' : 'Konten ditolak');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _verify(Submission s) async {
    final result = await showModalBottomSheet<VerifyResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VerifyViewsSheet(submission: s),
    );
    if (result == null || !mounted) return;
    try {
      final payout = await ref.read(apiServiceProvider).verifyViews(
            s.submissionId,
            approve: result.approve,
            verifiedViews: result.views,
            note: result.note,
          );
      refreshBrandData(ref);
      if (!mounted) return;
      showAppSnack(
        context,
        result.approve && payout > 0
            ? 'Views terverifikasi · ${rp(payout)} dibayarkan ke kreator'
            : 'Klaim views ditolak',
      );
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }
}

class VerifyResult {
  const VerifyResult({required this.approve, required this.views, required this.note});
  final bool approve;
  final int views;
  final String note;
}

/// Sheet verifikasi views: brand mengisi views hasil cek manual.
class VerifyViewsSheet extends StatefulWidget {
  const VerifyViewsSheet({super.key, required this.submission});
  final Submission submission;

  @override
  State<VerifyViewsSheet> createState() => _VerifyViewsSheetState();
}

class _VerifyViewsSheetState extends State<VerifyViewsSheet> {
  late final _views = TextEditingController(text: '${widget.submission.claimedViews}');
  final _note = TextEditingController();

  @override
  void dispose() {
    _views.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final views = parseAmount(_views.text);
    final belowMin = views < s.minViews;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Cek views', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${s.creatorName} mengklaim ${fmtNum(s.claimedViews)} views. Buka videonya, '
            'lalu isi jumlah views yang terlihat saat ini.'),
        const SizedBox(height: 16),
        TextField(
          key: const Key('verify-views-input'),
          controller: _views,
          keyboardType: TextInputType.number,
          inputFormatters: digitsOnly,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Views terverifikasi',
            helperText: 'Minimal ${fmtNum(s.minViews)} views',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
        ),
        Text(
          belowMin
              ? 'Di bawah minimum — klaim akan ditolak otomatis.'
              : 'Kreator dibayar ${rp(estimatePayout(views, s.ratePer1k))} '
                  '(maks. sisa budget campaign).',
          key: const Key('verify-payout-estimate'),
          style: TextStyle(fontWeight: FontWeight.w800, color: belowMin ? AppTheme.danger : AppTheme.success),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('verify-reject-button'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(
                context,
                VerifyResult(approve: false, views: views, note: _note.text.trim()),
              ),
              child: const Text('Tolak klaim'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('verify-approve-button'),
              onPressed: belowMin
                  ? null
                  : () => Navigator.pop(
                        context,
                        VerifyResult(approve: true, views: views, note: _note.text.trim()),
                      ),
              child: const Text('Setujui & bayar'),
            ),
          ),
        ]),
      ]),
    );
  }
}
