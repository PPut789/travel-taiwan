import 'package:cloud_firestore/cloud_firestore.dart';

class VideoPost {
  final String id;
  final String videoUrl;
  final String storagePath;
  final String caption;
  final String placeMode;
  final String attractionId;
  final String attractionName;
  final String province;
  final String region;
  final String googleMapsUrl;
  final String uploadedByUid;
  final String uploadedByName;
  final String uploadedByEmail;
  final String uploadedByPhotoUrl;
  final String status;
  final DateTime? createdAt;

  const VideoPost({
    required this.id,
    required this.videoUrl,
    required this.storagePath,
    required this.caption,
    required this.placeMode,
    required this.attractionId,
    required this.attractionName,
    required this.province,
    required this.region,
    required this.googleMapsUrl,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.uploadedByEmail,
    required this.uploadedByPhotoUrl,
    required this.status,
    required this.createdAt,
  });

  factory VideoPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];

    return VideoPost(
      id: doc.id,
      videoUrl: data['videoUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      placeMode: data['placeMode'] as String? ?? '',
      attractionId: data['attractionId'] as String? ?? '',
      attractionName: data['attractionName'] as String? ?? '',
      province: data['province'] as String? ?? '',
      region: data['region'] as String? ?? '',
      googleMapsUrl: data['googleMapsUrl'] as String? ?? '',
      uploadedByUid: data['uploadedByUid'] as String? ?? '',
      uploadedByName: data['uploadedByName'] as String? ?? '',
      uploadedByEmail: data['uploadedByEmail'] as String? ?? '',
      uploadedByPhotoUrl: data['uploadedByPhotoUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'published',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
