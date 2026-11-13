import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'data_providers.dart';

/// Muat ulang data user (saldo) tanpa melempar error ke UI.
void _refreshUser(WidgetRef ref) =>
    unawaited(ref.read(authProvider.notifier).refreshUser().catchError((Object _) {}));

/// Panggil setelah aksi kreator (submit, klaim, withdraw) agar semua layar sinkron.
void refreshCreatorData(WidgetRef ref) {
  ref
    ..invalidate(creatorStatsProvider)
    ..invalidate(creatorSubmissionsProvider)
    ..invalidate(withdrawalsProvider)
    ..invalidate(campaignSectionsProvider)
    ..invalidate(campaignListProvider)
    ..invalidate(campaignDetailProvider)
    ..invalidate(notificationsProvider);
  _refreshUser(ref);
}

/// Panggil setelah aksi brand (buat/ubah campaign, review, verifikasi, top up).
void refreshBrandData(WidgetRef ref) {
  ref
    ..invalidate(brandStatsProvider)
    ..invalidate(brandCampaignsProvider)
    ..invalidate(brandSubmissionsProvider)
    ..invalidate(topupsProvider)
    ..invalidate(campaignDetailProvider)
    ..invalidate(notificationsProvider);
  _refreshUser(ref);
}
