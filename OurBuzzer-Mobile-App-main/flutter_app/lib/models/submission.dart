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
      );
}
