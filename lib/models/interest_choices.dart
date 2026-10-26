class InterestChoices {
  final List<String> categories;
  final List<String> types;
  final List<String> activities;

  const InterestChoices({
    required this.categories,
    required this.types,
    required this.activities,
  });

  factory InterestChoices.fromJson(Map<String, dynamic> json) {
    List<String> labels(String key) =>
        (json[key] as List? ?? const [])
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty && value != 'Other')
            .toSet()
            .toList()
          ..sort();
    return InterestChoices(
      categories: labels('categories'),
      types: labels('types'),
      activities: labels('activities'),
    );
  }
}
