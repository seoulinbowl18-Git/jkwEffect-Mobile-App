import '../core/config.dart';
import 'enums.dart';
import 'json_utils.dart';

class Submission {
  const Submission({
    required this.submissionId,
    required this.campaignId,
    required this.campaignTitle,
    required this.creatorName,
    required this.platform,
    required this.videoUrl,
    required this.status,
    required this.claimedViews,
    required this.verifiedViews,
    required this.payout,
    required this.ratePer1k,
    required this.minViews,
    required this.note,
    required this.createdAt,
    this.proofs = const [],
    this.claimNote = '',
  });

  final String submissionId;
  final String campaignId;
  final String campaignTitle;
  final String creatorName;
  final VideoPlatform platform;
  final String videoUrl;
  final SubmissionStatus status;
  final int claimedViews;
  final int verifiedViews;
  final int payout;
  final int ratePer1k;
  final int minViews;
  final String note;
  final String createdAt;

  /// Bukti analitik (screenshot / rekaman layar) yang dilampirkan saat klaim.
  final List<SubmissionProof> proofs;
  final String claimNote;

  factory Submission.fromJson(Json j) => Submission(
        submissionId: asStr(j['submission_id']),
        campaignId: asStr(j['campaign_id']),
        campaignTitle: asStr(j['campaign_title']),
        creatorName: asStr(j['creator_name']),
        platform: VideoPlatform.fromWire(j['platform'] as String?),
        videoUrl: asStr(j['video_url']),
        status: SubmissionStatus.fromWire(j['status'] as String?),
        claimedViews: asInt(j['claimed_views']),
        verifiedViews: asInt(j['verified_views']),
        payout: asInt(j['payout']),
        ratePer1k: asInt(j['rate_per_1k']),
        minViews: asInt(j['min_views']),
        note: asStr(j['note']),
        createdAt: asStr(j['created_at']),
        proofs: asList(j['proofs'], SubmissionProof.fromJson),
        claimNote: asStr(j['claim_note']),
      );
}

/// Satu file bukti klaim. [url] adalah link bertanda tangan sementara dari backend
/// (`/api/proofs/...?exp=..&sig=..`) sehingga bisa dibuka tanpa header login.
class SubmissionProof {
  const SubmissionProof({required this.proofId, required this.kind, required this.contentType, required this.size, required this.url});

  final String proofId;
  final String kind; // image | video
  final String contentType;
  final int size;
  final String url;

  bool get isVideo => kind == 'video';
  String get absoluteUrl => AppConfig.resolveUrl(url);

  factory SubmissionProof.fromJson(Json j) => SubmissionProof(
        proofId: asStr(j['proof_id']),
        kind: asStr(j['kind']),
        contentType: asStr(j['content_type']),
        size: asInt(j['size']),
        url: asStr(j['url']),
      );
}
