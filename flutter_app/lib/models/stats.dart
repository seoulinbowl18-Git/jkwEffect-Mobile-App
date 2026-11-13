import 'json_utils.dart';

class StreakDay {
  const StreakDay({required this.date, required this.label, required this.posted});
  final String date;
  final String label; // "Sen".."Min" / "Hari ini"
  final bool posted;

  factory StreakDay.fromJson(Json j) =>
      StreakDay(date: asStr(j['date']), label: asStr(j['label']), posted: asBool(j['posted']));
}

/// Streak harian kreator (dihitung dalam zona WIB di backend).
class Streak {
  const Streak({required this.streak, required this.postedToday, required this.week});
  final int streak;
  final bool postedToday;
  final List<StreakDay> week; // 7 hari, terakhir = hari ini

  static const empty = Streak(streak: 0, postedToday: false, week: []);

  factory Streak.fromJson(Json j) => Streak(
        streak: asInt(j['streak']),
        postedToday: asBool(j['posted_today']),
        week: asList(j['week'], StreakDay.fromJson),
      );
}

class CreatorStats {
  const CreatorStats({
    required this.balance,
    required this.totalEarned,
    required this.pending,
    required this.videos,
    required this.campaigns,
    required this.streak,
  });

  final int balance;
  final int totalEarned;

  /// Estimasi pendapatan dari submission berstatus `diproses`.
  final int pending;
  final int videos;
  final int campaigns;
  final Streak streak;

  factory CreatorStats.fromJson(Json j) => CreatorStats(
        balance: asInt(j['balance']),
        totalEarned: asInt(j['total_earned']),
        pending: asInt(j['pending']),
        videos: asInt(j['videos']),
        campaigns: asInt(j['campaigns']),
        streak: j['streak'] is Map ? Streak.fromJson(Json.from(j['streak'] as Map)) : Streak.empty,
      );
}

class BrandStats {
  const BrandStats({
    required this.brandBalance,
    required this.active,
    required this.spent,
    required this.views,
    required this.creators,
    required this.budgetLeft,
  });

  final int brandBalance;
  final int active;
  final int spent;
  final int views;

  /// Kreator unik yang mendaftarkan video ke campaign brand ini.
  final int creators;

  /// Sisa budget di campaign yang belum ditutup.
  final int budgetLeft;

  factory BrandStats.fromJson(Json j) => BrandStats(
        brandBalance: asInt(j['brand_balance']),
        active: asInt(j['active']),
        spent: asInt(j['spent']),
        views: asInt(j['views']),
        creators: asInt(j['creators']),
        budgetLeft: asInt(j['budget_left']),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind; // info | success | error
  final bool read;
  final String createdAt;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: asStr(j['notification_id']),
        title: asStr(j['title']),
        body: asStr(j['body']),
        kind: asStr(j['kind']),
        read: asBool(j['read']),
        createdAt: asStr(j['created_at']),
      );
}

class NotificationFeed {
  const NotificationFeed({required this.items, required this.unread});
  final List<AppNotification> items;
  final int unread;

  factory NotificationFeed.fromJson(Json j) => NotificationFeed(
        items: asList(j['items'], AppNotification.fromJson),
        unread: asInt(j['unread']),
      );
}

class AdminStats {
  const AdminStats({
    required this.creators,
    required this.brands,
    required this.activeCampaigns,
    required this.pendingWithdrawals,
    required this.pendingSubmissions,
    required this.totalPaid,
    required this.totalViews,
  });

  final int creators;
  final int brands;
  final int activeCampaigns;
  final int pendingWithdrawals;
  final int pendingSubmissions;
  final int totalPaid;
  final int totalViews;

  factory AdminStats.fromJson(Json j) => AdminStats(
        creators: asInt(j['creators']),
        brands: asInt(j['brands']),
        activeCampaigns: asInt(j['active_campaigns']),
        pendingWithdrawals: asInt(j['pending_withdrawals']),
        pendingSubmissions: asInt(j['pending_submissions']),
        totalPaid: asInt(j['total_paid']),
        totalViews: asInt(j['total_views']),
      );
}
