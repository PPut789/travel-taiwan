import 'package:firebase_storage/firebase_storage.dart';

import '../models/place_model.dart';
import '../firebase_options.dart';

const _storageBucket = DefaultFirebaseOptions.storageBucket;
final Map<String, Future<String?>> _resolvedImageCache = {};

List<String> placeImageCandidates(Place place) {
  final candidates = place.images
      .map(normalizePlaceImageSource)
      .where(_isAllowedPlaceImageSource)
      .toList();

  final unique = <String>[];
  for (final candidate in candidates) {
    if (!unique.contains(candidate)) unique.add(candidate);
  }

  unique.sort((a, b) => _imagePriority(a).compareTo(_imagePriority(b)));
  return unique;
}

String normalizePlaceImageSource(String source) {
  final value = source.trim();
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  if (uri == null) return value;

  if (uri.scheme == 'gs') return value;

  if (uri.host == 'storage.cloud.google.com' ||
      uri.host == 'storage.googleapis.com') {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == _storageBucket) {
      final objectPath = segments.skip(1).join('/');
      return 'gs://$_storageBucket/$objectPath';
    }
  }

  if (value.startsWith('attraction_images/') ||
      value.startsWith('attraction_images_local_backup/')) {
    return 'gs://$_storageBucket/$value';
  }

  return value;
}

bool isAssetPlaceImage(String source) {
  final value = normalizePlaceImageSource(source);
  return value.isNotEmpty &&
      !value.startsWith('http://') &&
      !value.startsWith('https://') &&
      !value.startsWith('gs://');
}

Future<String?> resolvePlaceImageUrl(String source) {
  final value = normalizePlaceImageSource(source);
  if (value.isEmpty) return Future.value(null);
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Future.value(value);
  }
  if (!value.startsWith('gs://')) return Future.value(null);

  return _resolvedImageCache.putIfAbsent(value, () async {
    try {
      return FirebaseStorage.instance.refFromURL(value).getDownloadURL();
    } catch (_) {
      return null;
    }
  });
}

int _imagePriority(String source) {
  final value = source.toLowerCase();
  if (value.contains('firebasestorage.googleapis.com')) return 0;
  if (value.startsWith('gs://')) return 1;
  if (value.contains('storage.googleapis.com') ||
      value.contains('storage.cloud.google.com')) {
    return 2;
  }
  if (value.startsWith('http://') || value.startsWith('https://')) return 3;
  return 4;
}

bool _isAllowedPlaceImageSource(String source) {
  final value = source.trim().toLowerCase();
  if (value.isEmpty) return false;
  if (value.startsWith('assets/')) return false;
  if (value.contains('img.youtube.com') ||
      value.contains('youtube.com') ||
      value.contains('youtu.be')) {
    return false;
  }
  return true;
}
