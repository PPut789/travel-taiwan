import 'history_repository.dart';

Future<HistoryPreferenceBoost> optionalHistoryBoost(
  Future<HistoryPreferenceBoost> Function() load, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    return await load().timeout(timeout);
  } catch (_) {
    // History enhances ranking, but is not required to show the catalog.
    return const HistoryPreferenceBoost.empty();
  }
}
