import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/platform_badge.dart';
import '../../widgets/status_chip.dart';
import '../brand/campaign_actions.dart';
import '../creator/submit_video_view.dart';

/// Detail campaign. Kreator → tombol "Submit video". Brand pemilik → jeda/lanjut/tutup.
class CampaignDetailView extends ConsumerWidget {
  const CampaignDetailView({super.key, required this.campaignId});
  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(campaignDetailProvider(campaignId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail campaign')),
      body: AsyncView(
        value: campaign,
        onRetry: () => ref.invalidate(campaignDetailProvider(campaignId)),
        data: (c) => RefreshIndicator(
          onRefresh: () => ref.refresh(campaignDetailProvider(campaignId).future),
          child: _Body(campaign: c, isOwner: user?.isBrand == true && user?.userId == c.brandId),
        ),
      ),
      bottomNavigationBar: switch (campaign.value) {
        final Campaign c when user?.isCreator == true => SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('open-submit-button'),
              icon: const Icon(Icons.upload_rounded),
              label: Text(c.status == CampaignStatus.active ? 'Submit video' : 'Campaign ${c.status.label.toLowerCase()}'),
              onPressed: c.status == CampaignStatus.active
                  ? () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => SubmitVideoView(campaign: c)))
                  : null,
            ),
          ),
        _ => null,
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.campaign, required this.isOwner});
  final Campaign campaign;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (c.thumbnail.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(c.thumbnail, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusChip(c.status.label, c.status.tone),
              Chip(label: Text(c.category), visualDensity: VisualDensity.compact),
              if (c.exclusive) const Chip(label: Text('Exclusive'), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 8),
            Text(c.brandName, style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            Text(c.title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _Info('Bayaran', '${rp(c.ratePer1k)} / 1.000 views', highlight: true),
                  _Info('Minimal views', fmtNum(c.minViews)),
                  _Info('Deadline', '${fmtDate(c.deadline)} (${daysLeft(c.deadline)} hari lagi)'),
                  _Info('Submission', fmtNum(c.submissionCount)),
                  _Info('Total views terverifikasi', fmtNum(c.totalViews)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: c.budgetLeftPct / 100, minHeight: 8),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('Sisa budget ${rp(c.budgetLeft)}', style: t.bodySmall)),
                    Text('dari ${rp(c.budget)}', style: t.bodySmall),
                  ]),
                ]),
              ),
            ),
            const SectionTitle('Platform'),
            Wrap(spacing: 8, children: [
              for (final p in c.platforms) Chip(avatar: Icon(p.icon, size: 16), label: Text(p.label)),
            ]),
            const SectionTitle('Brief & aturan'),
            Text(c.instructions, style: t.bodyMedium?.copyWith(height: 1.5)),
            if (isOwner) ...[
              const SectionTitle('Kelola campaign'),
              CampaignActionButtons(campaign: c),
            ],
          ]),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: highlight ? Theme.of(context).colorScheme.primary : null,
              )),
        ]),
      );
}
