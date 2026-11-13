import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/form_helpers.dart';

/// Jeda / lanjutkan / tutup campaign dengan konfirmasi.
/// Return `true` bila status berhasil diubah.
Future<bool> changeCampaignStatus(
  BuildContext context,
  WidgetRef ref,
  Campaign c,
  CampaignStatus target,
) async {
  final (title, message, label) = switch (target) {
    CampaignStatus.paused => (
        'Jeda campaign?',
        'Campaign tidak akan tampil dan kreator tidak bisa submit sampai kamu melanjutkannya.',
        'Jeda',
      ),
    CampaignStatus.active => (
        'Lanjutkan campaign?',
        'Campaign akan tampil lagi di Cari Cuan.',
        'Lanjutkan',
      ),
    CampaignStatus.closed => (
        'Tutup campaign?',
        'Sisa budget ${rp(c.budgetLeft)} akan dikembalikan ke saldo brand. '
            'Submission yang belum selesai akan dibatalkan. Tindakan ini tidak bisa dibatalkan.',
        'Tutup campaign',
      ),
  };
  final ok = await confirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: label,
    destructive: target == CampaignStatus.closed,
  );
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(apiServiceProvider).setCampaignStatus(c.campaignId, target);
    refreshBrandData(ref);
    if (context.mounted) {
      showAppSnack(
        context,
        switch (target) {
          CampaignStatus.paused => 'Campaign dijeda',
          CampaignStatus.active => 'Campaign aktif kembali',
          CampaignStatus.closed => 'Campaign ditutup · ${rp(c.budgetLeft)} dikembalikan ke saldo',
        },
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return false;
  }
}

/// Tombol-tombol aksi sesuai status campaign saat ini.
class CampaignActionButtons extends ConsumerWidget {
  const CampaignActionButtons({super.key, required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (campaign.status == CampaignStatus.closed) {
      return const Text('Campaign sudah ditutup.');
    }
    final paused = campaign.status == CampaignStatus.paused;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          key: Key(paused ? 'campaign-resume-button' : 'campaign-pause-button'),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          label: Text(paused ? 'Lanjutkan' : 'Jeda'),
          onPressed: () =>
              changeCampaignStatus(context, ref, campaign, paused ? CampaignStatus.active : CampaignStatus.paused),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('campaign-close-button'),
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Tutup'),
          onPressed: () => changeCampaignStatus(context, ref, campaign, CampaignStatus.closed),
        ),
      ),
    ]);
  }
}
