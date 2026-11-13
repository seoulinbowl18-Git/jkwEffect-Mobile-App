import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/enums.dart';

/// Nada warna status — sama dengan peta `STATUS` di versi Expo.
enum Tone { warning, info, primary, success, danger, muted }

extension ToneColor on Tone {
  Color color(BuildContext context) => switch (this) {
        Tone.warning => AppTheme.warning,
        Tone.info => AppTheme.info,
        Tone.primary => AppTheme.primary,
        Tone.success => AppTheme.success,
        Tone.danger => AppTheme.danger,
        Tone.muted => Theme.of(context).colorScheme.outline,
      };
}

extension SubmissionStatusTone on SubmissionStatus {
  Tone get tone => switch (this) {
        SubmissionStatus.direview => Tone.warning,
        SubmissionStatus.menungguViews => Tone.info,
        SubmissionStatus.diproses || SubmissionStatus.verifying => Tone.primary,
        SubmissionStatus.disetujui => Tone.success,
        SubmissionStatus.ditolak => Tone.danger,
      };
}

extension CampaignStatusTone on CampaignStatus {
  Tone get tone => this == CampaignStatus.active ? Tone.success : Tone.muted;
}

extension TopupStatusTone on TopupStatus {
  Tone get tone => switch (this) {
        TopupStatus.pending => Tone.warning,
        TopupStatus.paid => Tone.success,
        TopupStatus.failed => Tone.danger,
        TopupStatus.expired || TopupStatus.canceled => Tone.muted,
      };
}

extension WithdrawalStatusTone on WithdrawalStatus {
  Tone get tone => switch (this) {
        WithdrawalStatus.diproses => Tone.warning,
        WithdrawalStatus.disetujui => Tone.success,
        WithdrawalStatus.ditolak => Tone.danger,
      };
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.tone, {super.key});
  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = tone.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
