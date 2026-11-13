/// Enum yang memetakan string status dari backend. Nilai `wire` adalah string
/// persis yang dikirim/diterima API — jangan diubah tanpa mengubah backend.
library;

T _parse<T extends Enum>(List<T> values, String? wire, String Function(T) toWire, T fallback) {
  for (final v in values) {
    if (toWire(v) == wire) return v;
  }
  return fallback;
}

enum UserRole {
  creator('creator'),
  brand('brand'),
  admin('admin');

  const UserRole(this.wire);
  final String wire;

  /// `null` berarti user belum memilih peran (harus ke onboarding).
  static UserRole? fromWire(String? w) {
    for (final r in values) {
      if (r.wire == w) return r;
    }
    return null;
  }
}

enum VideoPlatform {
  tiktok('tiktok', 'TikTok'),
  instagram('instagram', 'Instagram'),
  threads('threads', 'Threads'),
  youtube('youtube', 'YouTube');

  const VideoPlatform(this.wire, this.label);
  final String wire;
  final String label;

  static VideoPlatform fromWire(String? w) =>
      _parse(values, w, (v) => v.wire, VideoPlatform.tiktok);
}

/// Alur: direview → menunggu_views → diproses (→ verifying) → disetujui | ditolak
enum SubmissionStatus {
  direview('direview', 'Direview'),
  menungguViews('menunggu_views', 'Siap diklaim'),
  diproses('diproses', 'Dicek views'),
  verifying('verifying', 'Dicek views'),
  disetujui('disetujui', 'Selesai'),
  ditolak('ditolak', 'Ditolak');

  const SubmissionStatus(this.wire, this.label);
  final String wire;
  final String label;

  static SubmissionStatus fromWire(String? w) =>
      _parse(values, w, (v) => v.wire, SubmissionStatus.direview);

  /// Kreator boleh klaim views hanya di status ini.
  bool get canClaim => this == SubmissionStatus.menungguViews;

  /// Brand perlu menyetujui/menolak konten.
  bool get needsContentReview => this == SubmissionStatus.direview;

  /// Brand perlu cek & verifikasi views yang diklaim.
  bool get needsViewVerification => this == SubmissionStatus.diproses;

  bool get isFinal => this == SubmissionStatus.disetujui || this == SubmissionStatus.ditolak;
}

enum CampaignStatus {
  active('active', 'Aktif'),
  paused('paused', 'Dijeda'),
  closed('closed', 'Ditutup');

  const CampaignStatus(this.wire, this.label);
  final String wire;
  final String label;

  static CampaignStatus fromWire(String? w) =>
      _parse(values, w, (v) => v.wire, CampaignStatus.active);
}

enum PaymentType {
  qris('qris', 'QRIS'),
  bankTransfer('bank_transfer', 'Virtual Account');

  const PaymentType(this.wire, this.label);
  final String wire;
  final String label;

  static PaymentType fromWire(String? w) => _parse(values, w, (v) => v.wire, PaymentType.qris);
}

enum TopupStatus {
  pending('pending', 'Menunggu bayar'),
  paid('paid', 'Lunas'),
  expired('expired', 'Kadaluarsa'),
  canceled('canceled', 'Dibatalkan'),
  failed('failed', 'Gagal');

  const TopupStatus(this.wire, this.label);
  final String wire;
  final String label;

  static TopupStatus fromWire(String? w) {
    if (w == 'cancelled') return TopupStatus.canceled; // Komerce kadang pakai ejaan UK
    return _parse(values, w, (v) => v.wire, TopupStatus.pending);
  }
}

enum WithdrawalStatus {
  diproses('diproses', 'Diproses'),
  disetujui('disetujui', 'Berhasil'),
  ditolak('ditolak', 'Ditolak');

  const WithdrawalStatus(this.wire, this.label);
  final String wire;
  final String label;

  static WithdrawalStatus fromWire(String? w) =>
      _parse(values, w, (v) => v.wire, WithdrawalStatus.diproses);
}
