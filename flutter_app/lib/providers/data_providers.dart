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

final brandWithdrawalsProvider = FutureProvider.autoDispose<List<Withdrawal>>(
  (ref) => ref.watch(apiServiceProvider).brandWithdrawals(),
);

/// Fee platform dari backend; bila gagal dimuat pakai nilai bawaan (10% / 15%).
final feesProvider = FutureProvider<FeesConfig>((ref) async {
  try {
    return await ref.watch(apiServiceProvider).fees();
  } catch (_) {
    return const FeesConfig();
  }
});

final ledgerProvider = FutureProvider.autoDispose<List<LedgerEntry>>(
  (ref) => ref.watch(apiServiceProvider).ledger(),
);

final topupsProvider = FutureProvider.autoDispose<List<Topup>>(
  (ref) => ref.watch(apiServiceProvider).topups(),
);

// ---------------------------- Umum ----------------------------

final notificationsProvider = FutureProvider.autoDispose<NotificationFeed>(
  (ref) => ref.watch(apiServiceProvider).notifications(),
);

final paymentsConfigProvider = FutureProvider.autoDispose<PaymentsConfig>(
  (ref) => ref.watch(apiServiceProvider).paymentsConfig(),
);

// ---------------------------- Admin ----------------------------

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(apiServiceProvider).adminStats(),
);

final adminWithdrawalsProvider = FutureProvider.autoDispose<List<Withdrawal>>(
  (ref) => ref.watch(apiServiceProvider).adminWithdrawals(),
);

/// Daftar lengkap campaign publik dengan urutan tertentu (halaman "Lihat Semua").
final campaignsBySortProvider = FutureProvider.autoDispose.family<List<Campaign>, CampaignSort>(
  (ref, sort) => ref.watch(apiServiceProvider).campaigns(sort: sort),
);

// ---------------------------- Akun sosial & komunitas ----------------------------

final socialAccountsProvider = FutureProvider.autoDispose<SocialAccounts>(
  (ref) => ref.watch(apiServiceProvider).socialAccounts(),
);

/// Link komunitas jarang berubah: disimpan selama aplikasi berjalan.
final communityProvider = FutureProvider<CommunityLinks>(
  (ref) => ref.watch(apiServiceProvider).community(),
);
