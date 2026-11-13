// Provider data per fitur. Semua membaca lewat ApiService dan otomatis
// dibuang (autoDispose) saat layar ditutup. Untuk pull-to-refresh:
// `ref.refresh(xxxProvider.future)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'service_providers.dart';

// ---------------------------- Cari Cuan ----------------------------

/// Filter halaman Cari Cuan (tab, pencarian, kategori).
class CampaignFilter {
  const CampaignFilter({this.exclusive = false, this.query = '', this.category = 'Semua'});
  final bool exclusive;
  final String query;
  final String category;

  bool get isDefault => query.isEmpty && category == 'Semua';

  CampaignFilter copyWith({bool? exclusive, String? query, String? category}) => CampaignFilter(
        exclusive: exclusive ?? this.exclusive,
        query: query ?? this.query,
        category: category ?? this.category,
      );

  @override
  bool operator ==(Object other) =>
      other is CampaignFilter &&
      other.exclusive == exclusive &&
      other.query == query &&
      other.category == category;

  @override
  int get hashCode => Object.hash(exclusive, query, category);
}

class CampaignFilterNotifier extends Notifier<CampaignFilter> {
  @override
  CampaignFilter build() => const CampaignFilter();

  void setExclusive(bool v) => state = state.copyWith(exclusive: v);
  void setQuery(String v) => state = state.copyWith(query: v);
  void setCategory(String v) => state = state.copyWith(category: v);
}

final campaignFilterProvider =
    NotifierProvider<CampaignFilterNotifier, CampaignFilter>(CampaignFilterNotifier.new);

/// Section banner (Lagi rame / Segera ditutup / Rate tertinggi / Campaign baru).
final campaignSectionsProvider = FutureProvider.autoDispose<CampaignSections>(
  (ref) => ref.watch(apiServiceProvider).campaignSections(),
);

/// Hasil daftar campaign sesuai filter aktif.
final campaignListProvider = FutureProvider.autoDispose<List<Campaign>>((ref) {
  final f = ref.watch(campaignFilterProvider);
  return ref.watch(apiServiceProvider).campaigns(
        query: f.query,
        category: f.category == 'Semua' ? null : f.category,
        exclusive: f.exclusive,
      );
});

final campaignDetailProvider = FutureProvider.autoDispose.family<Campaign, String>(
  (ref, id) => ref.watch(apiServiceProvider).campaign(id),
);

// ---------------------------- Kreator ----------------------------

final creatorStatsProvider = FutureProvider.autoDispose<CreatorStats>(
  (ref) => ref.watch(apiServiceProvider).creatorStats(),
);

final creatorSubmissionsProvider = FutureProvider.autoDispose<List<Submission>>(
  (ref) => ref.watch(apiServiceProvider).creatorSubmissions(),
);

final withdrawalsProvider = FutureProvider.autoDispose<List<Withdrawal>>(
  (ref) => ref.watch(apiServiceProvider).withdrawals(),
);

// ---------------------------- Brand ----------------------------

final brandStatsProvider = FutureProvider.autoDispose<BrandStats>(
  (ref) => ref.watch(apiServiceProvider).brandStats(),
);

final brandCampaignsProvider = FutureProvider.autoDispose<List<Campaign>>(
  (ref) => ref.watch(apiServiceProvider).brandCampaigns(),
);

/// `null` = semua status.
final brandSubmissionsProvider = FutureProvider.autoDispose.family<List<Submission>, SubmissionStatus?>(
  (ref, status) => ref.watch(apiServiceProvider).brandSubmissions(status: status),
);

final topupsProvider = FutureProvider.autoDispose<List<Topup>>(
  (ref) => ref.watch(apiServiceProvider).topups(),
);

// ---------------------------- Umum ----------------------------

final notificationsProvider = FutureProvider.autoDispose<NotificationFeed>(
  (ref) => ref.watch(apiServiceProvider).notifications(),
);
