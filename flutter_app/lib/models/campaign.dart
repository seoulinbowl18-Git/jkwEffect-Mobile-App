import 'enums.dart';
import 'json_utils.dart';

class Campaign {
  const Campaign({
    required this.campaignId,
    required this.brandId,
    required this.brandName,
    required this.title,
    required this.category,
    required this.platforms,
    required this.ratePer1k,
    required this.minViews,
    required this.budget,
    required this.spent,
    required this.thumbnail,
    required this.instructions,
    required this.exclusive,
    required this.submissionCount,
    required this.totalViews,
    required this.status,
    required this.deadline,
    required this.createdAt,
    required this.budgetLeftPct,
  });

  final String campaignId;
  final String brandId;
  final String brandName;
  final String title;
  final String category;
  final List<VideoPlatform> platforms;
  final int ratePer1k;
  final int minViews;
  final int budget;
  final int spent;
  final String thumbnail;
  final String instructions;
  final bool exclusive;
  final int submissionCount;
  final int totalViews;
  final CampaignStatus status;
  final String deadline;
  final String createdAt;
  final int budgetLeftPct;

  int get budgetLeft => (budget - spent).clamp(0, budget);

  factory Campaign.fromJson(Json j) => Campaign(
        campaignId: asStr(j['campaign_id']),
        brandId: asStr(j['brand_id']),
        brandName: asStr(j['brand_name']),
        title: asStr(j['title']),
        category: asStr(j['category']),
        platforms: (j['platforms'] as List? ?? const [])
            .map((e) => VideoPlatform.fromWire('$e'))
            .toList(),
        ratePer1k: asInt(j['rate_per_1k']),
        minViews: asInt(j['min_views']),
        budget: asInt(j['budget']),
        spent: asInt(j['spent']),
        thumbnail: asStr(j['thumbnail']),
        instructions: asStr(j['instructions']),
        exclusive: asBool(j['exclusive']),
        submissionCount: asInt(j['submission_count']),
        totalViews: asInt(j['total_views']),
        status: CampaignStatus.fromWire(j['status'] as String?),
        deadline: asStr(j['deadline']),
        createdAt: asStr(j['created_at']),
        budgetLeftPct: asInt(j['budget_left_pct']),
      );
}

/// Body `POST /campaigns` — batasan sama dengan `CampaignIn` backend.
class CampaignInput {
  const CampaignInput({
    required this.title,
    required this.category,
    required this.platforms,
    required this.ratePer1k,
    required this.minViews,
    required this.budget,
    required this.instructions,
    this.thumbnail = '',
    this.exclusive = false,
    this.deadlineDays = 30,
  });

  final String title; // 3..120
  final String category; // salah satu kCategories
  final List<VideoPlatform> platforms; // min 1
  final int ratePer1k; // 500..1.000.000
  final int minViews; // 100..100.000.000
  final int budget; // >= 100.000, dipotong dari saldo brand
  final String instructions; // 10..5000
  final String thumbnail;
  final bool exclusive;
  final int deadlineDays; // 1..180

  Json toJson() => {
        'title': title,
        'category': category,
        'platforms': platforms.map((p) => p.wire).toList(),
        'rate_per_1k': ratePer1k,
        'min_views': minViews,
        'budget': budget,
        'thumbnail': thumbnail,
        'instructions': instructions,
        'exclusive': exclusive,
        'deadline_days': deadlineDays,
      };
}

/// Respons `GET /campaigns/sections` untuk halaman Cari Cuan.
class CampaignSections {
  const CampaignSections({
    required this.trending,
    required this.topRate,
    required this.newest,
    required this.closing,
    required this.total,
    required this.totalExclusive,
  });

  /// "Lagi rame"
  final List<Campaign> trending;

  /// "Rate tertinggi"
  final List<Campaign> topRate;

  /// "Campaign baru"
  final List<Campaign> newest;

  /// "Segera ditutup"
  final List<Campaign> closing;
  final int total;
  final int totalExclusive;

  factory CampaignSections.fromJson(Json j) => CampaignSections(
        trending: asList(j['trending'], Campaign.fromJson),
        topRate: asList(j['top_rate'], Campaign.fromJson),
        newest: asList(j['newest'], Campaign.fromJson),
        closing: asList(j['closing'], Campaign.fromJson),
        total: asInt(j['total']),
        totalExclusive: asInt(j['total_exclusive']),
      );
}

/// Parameter `sort` untuk `GET /campaigns`.
enum CampaignSort {
  newest('new'),
  rate('rate'),
  deadline('deadline');

  const CampaignSort(this.wire);
  final String wire;
}
