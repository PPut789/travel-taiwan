class Place {
  final String documentId;
  final int? sourceRow;
  final String id;
  final String name;
  final String nameEn;
  final String province;
  final String description;
  final String region;
  final String category;
  final String type;
  final String activity;
  final String location;
  final double? latitude;
  final double? longitude;
  final String youtubeUrl;
  final List<String> youtubeUrls;
  final List<String> tiktokUrls;
  final List<String> videoUrls;
  final List<String> assetImages;
  final List<String> images;
  final List<String> tags;

  Place({
    this.documentId = '',
    this.sourceRow,
    required this.id,
    required this.name,
    required this.nameEn,
    required this.province,
    required this.region,
    required this.description,
    required this.category,
    required this.type,
    required this.activity,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.youtubeUrl,
    required this.youtubeUrls,
    required this.tiktokUrls,
    required this.videoUrls,
    this.assetImages = const [],
    required this.images,
    required this.tags,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      documentId: json['documentId'] as String? ?? '',
      sourceRow: (json['sourceRow'] as num?)?.toInt(),
      id: json['id'] as String? ?? '',
      name:
          (json['nameZhTw'] ?? json['name'] ?? json['nameTh']) as String? ?? '',
      nameEn: json['nameEn'] as String? ?? '',
      province: json['province'] as String? ?? '',
      region: json['region'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      type: json['type'] as String? ?? '',
      activity: json['activity'] as String? ?? '',
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      youtubeUrls: List<String>.from(json['youtubeUrls'] as List? ?? const []),
      tiktokUrls: List<String>.from(json['tiktokUrls'] as List? ?? const []),
      videoUrls: List<String>.from(json['videoUrls'] as List? ?? const []),
      assetImages: List<String>.from(json['assetImages'] as List? ?? const []),
      images: List<String>.from(json['images'] as List? ?? const []),
      tags: List<String>.from(json['tags'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'sourceRow': sourceRow,
      'nameTh': name,
      'nameZhTw': name,
      'nameEn': nameEn,
      'province': province,
      'region': region,
      'description': description,
      'category': category,
      'type': type,
      'activity': activity,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'youtubeUrl': youtubeUrl,
      'youtubeUrls': youtubeUrls,
      'tiktokUrls': tiktokUrls,
      'videoUrls': videoUrls,
      'assetImages': assetImages,
      'images': images,
      'tags': tags,
    };
  }
}
