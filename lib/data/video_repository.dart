import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/place_model.dart';
import '../models/video_post_model.dart';
import 'user_repository.dart';

class VideoRepository {
  static final _videos = FirebaseFirestore.instance.collection('videos');
  static final _storage = FirebaseStorage.instance;

  static Future<VideoPost?> loadPublishedVideo(String id) async {
    final snapshot = await _videos.doc(id).get();
    if (!snapshot.exists) return null;
    final video = VideoPost.fromFirestore(snapshot);
    return video.status == 'published' ? video : null;
  }

  static Stream<List<VideoPost>> watchPublishedVideos() {
    return _videos
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(VideoPost.fromFirestore)
              .where((video) => video.status == 'published')
              .toList(),
        );
  }

  static Stream<List<VideoPost>> watchMyVideos() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const <VideoPost>[]);

    return _videos.where('uploadedByUid', isEqualTo: user.uid).snapshots().map((
      snapshot,
    ) {
      final videos = snapshot.docs.map(VideoPost.fromFirestore).toList();
      videos.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return videos;
    });
  }

  static Future<void> uploadVideo({
    required XFile file,
    required String caption,
    required Place? selectedPlace,
    required String googleMapsUrl,
    required String googlePlaceName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in before uploading a video.');
    }

    final doc = _videos.doc();
    final bytes = await file.readAsBytes();
    final storagePath = 'user_videos/${user.uid}/${doc.id}.mp4';
    final videoUrl = await _uploadBytes(storagePath, bytes);
    final uploaderName = _displayName(user);
    final uploaderPhotoUrl = await UserRepository.loadProfilePhotoUrl();
    final isAttraction = selectedPlace != null;

    await doc.set({
      'videoUrl': videoUrl,
      'storagePath': storagePath,
      'caption': caption.trim(),
      'placeMode': isAttraction ? 'attraction' : 'google_maps',
      'attractionId': selectedPlace?.documentId ?? '',
      'attractionSourceId': selectedPlace?.id ?? '',
      'attractionName':
          selectedPlace?.name ??
          _googleMapsName(googleMapsUrl, fallback: googlePlaceName),
      'province': selectedPlace?.province ?? '',
      'region': selectedPlace?.region ?? '',
      'googleMapsUrl': googleMapsUrl.trim(),
      'uploadedByUid': user.uid,
      'uploadedByName': uploaderName,
      'uploadedByEmail': user.email ?? '',
      'uploadedByPhotoUrl': uploaderPhotoUrl,
      'status': 'published',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateVideoDetails({
    required VideoPost video,
    required String caption,
    required Place? selectedPlace,
    required String googleMapsUrl,
    required String googlePlaceName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || video.uploadedByUid != user.uid) {
      throw Exception('You can edit only your own videos.');
    }

    final isAttraction = selectedPlace != null;
    await _videos.doc(video.id).update({
      'caption': caption.trim(),
      'placeMode': isAttraction ? 'attraction' : 'google_maps',
      'attractionId': selectedPlace?.documentId ?? '',
      'attractionSourceId': selectedPlace?.id ?? '',
      'attractionName':
          selectedPlace?.name ??
          _googleMapsName(googleMapsUrl, fallback: googlePlaceName),
      'province': selectedPlace?.province ?? '',
      'region': selectedPlace?.region ?? '',
      'googleMapsUrl': googleMapsUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteVideo(VideoPost video) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || video.uploadedByUid != user.uid) {
      throw Exception('You can delete only your own videos.');
    }

    await _videos.doc(video.id).delete();

    if (video.storagePath.isNotEmpty) {
      try {
        await _storage.ref(video.storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  static Future<String> _uploadBytes(String path, Uint8List bytes) async {
    final ref = _storage.ref(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'video/mp4'),
    );
    return task.ref.getDownloadURL();
  }

  static String _displayName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return 'Traveler';
  }

  static String _googleMapsName(String url, {String fallback = ''}) {
    final fallbackName = fallback.trim();
    if (fallbackName.isNotEmpty) return fallbackName;

    final uri = Uri.tryParse(url.trim());
    final segments = uri?.pathSegments ?? const <String>[];
    final placeIndex = segments.indexWhere((segment) => segment == 'place');
    if (placeIndex >= 0 && placeIndex + 1 < segments.length) {
      final rawName = Uri.decodeComponent(
        segments[placeIndex + 1],
      ).replaceAll('+', ' ').trim();
      if (rawName.isNotEmpty) return rawName;
    }

    return 'Location from Google Maps';
  }
}
