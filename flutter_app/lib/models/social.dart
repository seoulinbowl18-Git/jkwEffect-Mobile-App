import 'json_utils.dart';

/// Platform akun sosial yang bisa dihubungkan (sama dengan backend `SOCIAL_PLATFORMS`).
enum SocialPlatform {
  tiktok('tiktok', 'TikTok', '@username atau link profil TikTok'),
  instagram('instagram', 'Instagram', '@username atau link profil Instagram'),
  threads('threads', 'Threads', '@username atau link profil Threads');

  const SocialPlatform(this.wire, this.label, this.hint);
  final String wire;
  final String label;
  final String hint;
}

class SocialAccount {
  const SocialAccount({required this.username, required this.url});
  final String username;
  final String url;

  static SocialAccount? fromJson(Object? j) =>
      j is Map && asStr(j['username']).isNotEmpty ? SocialAccount(username: asStr(j['username']), url: asStr(j['url'])) : null;
}

class TelegramAccount {
  const TelegramAccount({required this.username, required this.name});
  final String username;
  final String name;

  /// "@username", atau nama bila akun Telegram tanpa username.
  String get display => username.isNotEmpty ? '@$username' : name;

  static TelegramAccount? fromJson(Object? j) =>
      j is Map ? TelegramAccount(username: asStr(j['username']), name: asStr(j['name'])) : null;
}

/// Respons `GET /users/social`.
class SocialAccounts {
  const SocialAccounts({this.accounts = const {}, this.telegram});
  final Map<SocialPlatform, SocialAccount> accounts;
  final TelegramAccount? telegram;

  SocialAccount? operator [](SocialPlatform p) => accounts[p];

  factory SocialAccounts.fromJson(Json j) => SocialAccounts(
        accounts: {
          for (final p in SocialPlatform.values) p: ?SocialAccount.fromJson(j[p.wire]),
        },
        telegram: TelegramAccount.fromJson(j['telegram']),
      );
}

/// Respons `GET /public/community`: link grup & bot Telegram GIBRAN2029.
class CommunityLinks {
  const CommunityLinks({this.telegramUrl = '', this.telegramBot = '', this.connectEnabled = false});
  final String telegramUrl;
  final String telegramBot;
  final bool connectEnabled;

  factory CommunityLinks.fromJson(Json j) => CommunityLinks(
        telegramUrl: asStr(j['telegram_url']),
        telegramBot: asStr(j['telegram_bot']),
        connectEnabled: j['telegram_connect_enabled'] == true,
      );
}
