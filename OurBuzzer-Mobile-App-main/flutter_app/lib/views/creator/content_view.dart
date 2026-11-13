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

/// Filter status di halaman Konten (sama dengan versi Expo).
enum ContentFilter {
  all('Semua', {}),
  direview('Direview', {SubmissionStatus.direview}),
  disetujui('Disetujui', {SubmissionStatus.menungguViews}),
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
      appBar: AppBar(title: const Text('Konten saya', style: TextStyle(fontWeight: FontWeight.w900))),
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
                if (items.isEmpty) {
                  return ListView(children: [
                    EmptyState(
                      icon: Icons.video_library_outlined,
                      message: all.isEmpty
                          ? 'Belum ada konten. Cari campaign di tab Cari Cuan dan submit video pertamamu!'
                          : 'Tidak ada konten berstatus "${_filter.label}"',
                    ),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final s = items[i];
                    return SubmissionCard(
                      key: Key('submission-${s.submissionId}'),
                      submission: s,
                      actions: [
                        if (s.status.canClaim)
                          FilledButton.icon(
                            key: Key('claim-views-button-${s.submissionId}'),
                            icon: const Icon(Icons.visibility_rounded),
                            label: const Text('Klaim views'),
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
    final views = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ClaimViewsSheet(submission: s),
    );
    if (views == null || !mounted) return;
    try {
      await ref.read(apiServiceProvider).claimViews(s.submissionId, views);
      refreshCreatorData(ref);
      if (mounted) showAppSnack(context, 'Klaim ${fmtNum(views)} views terkirim. Brand akan mengecek.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }
}

/// Bottom sheet input jumlah views + estimasi pendapatan. Mengembalikan views.
class ClaimViewsSheet extends StatefulWidget {
  const ClaimViewsSheet({super.key, required this.submission});
  final Submission submission;

  @override
  State<ClaimViewsSheet> createState() => _ClaimViewsSheetState();
}

class _ClaimViewsSheetState extends State<ClaimViewsSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final views = parseAmount(_ctrl.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Klaim views', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Masukkan jumlah views video kamu saat ini. Minimal ${fmtNum(s.minViews)} views. '
              'Brand akan mengecek manual.'),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('claim-views-input'),
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digitsOnly,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Jumlah views', hintText: 'contoh: 25000'),
            validator: (v) {
              final n = parseAmount(v ?? '');
              if (n <= 0) return 'Isi jumlah views';
              if (n < s.minViews) return 'Views minimal ${fmtNum(s.minViews)}';
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (views > 0)
            Text(
              'Estimasi pendapatan: ${rp(estimatePayout(views, s.ratePer1k))}',
              key: const Key('claim-estimate'),
              style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('claim-submit-button'),
            onPressed: () {
              if (_formKey.currentState!.validate()) Navigator.pop(context, views);
            },
            child: const Text('Kirim klaim'),
          ),
        ]),
      ),
    );
  }
}
