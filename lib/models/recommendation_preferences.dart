class RecommendationPreferences {
  final List<String> provinces;
  final List<String> categories;
  final List<String> types;
  final List<String> activities;
  final int? age;
  final String? gender;

  static const genderOptions = ['Female', 'Male', 'Other'];

  const RecommendationPreferences({
    required this.provinces,
    required this.categories,
    required this.types,
    required this.activities,
    this.age,
    this.gender,
  });

  factory RecommendationPreferences.fromJson(Map<String, dynamic> json) {
    return RecommendationPreferences(
      provinces: List<String>.from(json['provinces'] as List? ?? const []),
      categories: List<String>.from(json['categories'] as List? ?? const []),
      types: List<String>.from(json['types'] as List? ?? const []),
      activities: List<String>.from(json['activities'] as List? ?? const []),
      age: json['age'] is int ? json['age'] as int : null,
      gender: json['gender'] is String ? json['gender'] as String : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provinces': provinces,
      'categories': categories,
      'types': types,
      'activities': activities,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
    };
  }

  bool get isComplete {
    return categories.isNotEmpty && types.isNotEmpty && activities.isNotEmpty;
  }

  bool get hasDemographics =>
      age != null && age! > 0 && genderOptions.contains(gender);
}
