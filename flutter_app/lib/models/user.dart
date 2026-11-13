import 'enums.dart';
import 'json_utils.dart';

class User {
  const User({
    required this.userId,
    required this.email,
    required this.name,
    this.picture,
    this.pictureCustom = false,
    this.role,
    this.balance = 0,
    this.totalEarned = 0,
    this.brandBalance = 0,
    this.profile = const {},
  });

  final String userId;
  final String email;
  final String name;
  final String? picture;

  /// `true` bila foto profil diunggah sendiri (bukan foto Google).
  final bool pictureCustom;

  /// `null` = belum pilih peran → tampilkan onboarding.
  final UserRole? role;

  /// Saldo kreator yang bisa ditarik.
  final int balance;
  final int totalEarned;

  /// Saldo brand untuk membiayai campaign (dari top up).
  final int brandBalance;

  /// tiktok, instagram, brand_name, bank_method, bank_account, bank_holder
  final Map<String, String> profile;

  bool get hasRole => role != null;
  bool get isCreator => role == UserRole.creator;
  bool get isBrand => role == UserRole.brand;
  String get firstName => name.split(' ').first;
  String get brandName => profile['brand_name']?.isNotEmpty == true ? profile['brand_name']! : name;

  factory User.fromJson(Json j) => User(
        userId: asStr(j['user_id']),
        email: asStr(j['email']),
        name: asStr(j['name']),
        picture: j['picture'] as String?,
        pictureCustom: j['picture_custom'] == true,
        role: UserRole.fromWire(j['role'] as String?),
        balance: asInt(j['balance']),
        totalEarned: asInt(j['total_earned']),
        brandBalance: asInt(j['brand_balance']),
        profile: asStrMap(j['profile']),
      );
}

/// Respons `POST /auth/session` = data user + `session_token` untuk Bearer auth.
class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final User user;

  factory AuthSession.fromJson(Json j) =>
      AuthSession(token: asStr(j['session_token']), user: User.fromJson(j));
}
