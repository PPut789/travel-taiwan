class ProvinceNotification {
  final String id;
  final String source;
  final String sourceId;
  final String province;
  final String generation;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const ProvinceNotification({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.province,
    required this.generation,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  bool get isVideo => source == 'videos';

  factory ProvinceNotification.fromJson(Map<String, dynamic> data) =>
      ProvinceNotification(
        id: data['id'] as String,
        source: data['source'] as String,
        sourceId: data['sourceId'] as String,
        province: data['province'] as String,
        generation: data['generation'] as String,
        title: data['title'] as String,
        message: data['message'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          data['createdAt'] as int,
          isUtc: true,
        ),
        isRead: data['isRead'] == true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'sourceId': sourceId,
    'province': province,
    'generation': generation,
    'title': title,
    'message': message,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isRead': isRead,
  };
}
