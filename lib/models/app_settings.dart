class AppSettings {
  final bool autoplayVideos;
  final bool startVideosMuted;
  final bool saveViewingHistory;

  const AppSettings({
    this.autoplayVideos = true,
    this.startVideosMuted = false,
    this.saveViewingHistory = true,
  });

  AppSettings copyWith({
    bool? autoplayVideos,
    bool? startVideosMuted,
    bool? saveViewingHistory,
  }) {
    return AppSettings(
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      startVideosMuted: startVideosMuted ?? this.startVideosMuted,
      saveViewingHistory: saveViewingHistory ?? this.saveViewingHistory,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoplayVideos: json['autoplayVideos'] as bool? ?? true,
      startVideosMuted: json['startVideosMuted'] as bool? ?? false,
      saveViewingHistory: json['saveViewingHistory'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoplayVideos': autoplayVideos,
      'startVideosMuted': startVideosMuted,
      'saveViewingHistory': saveViewingHistory,
    };
  }
}
