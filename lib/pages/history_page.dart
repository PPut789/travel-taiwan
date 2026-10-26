import 'package:flutter/material.dart';

import '../data/history_repository.dart';
import '../models/place_model.dart';
import '../utils/app_routes.dart';
import '../utils/place_media.dart';
import '../widgets/app_chrome.dart';
import '../widgets/resolved_place_image.dart';
import '../widgets/selection_background.dart';
import 'detail_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  Future<void> _clearHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const AppConfirmDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Clear history?',
        message: 'Remove all attractions from your viewing history',
        confirmLabel: 'Clear history',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;
    await HistoryRepository.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'NotoSansThai',
          bodyColor: const Color(0xFF19456B),
          displayColor: const Color(0xFF19456B),
        ),
        primaryTextTheme: Theme.of(
          context,
        ).primaryTextTheme.apply(fontFamily: 'NotoSansThai'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF7FF),
        body: Stack(
          children: [
            const Positioned.fill(child: SelectionBackground()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<HistoryItem>>(
                      stream: HistoryRepository.watchHistory(),
                      builder: (context, snapshot) {
                        final items = snapshot.data ?? const <HistoryItem>[];

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Column(
                            children: [
                              _HistoryHeader(title: 'Viewing history'),
                              Expanded(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ],
                          );
                        }

                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              const _HistoryHeader(title: 'Viewing history'),
                              Expanded(
                                child: EmptyStateCard(
                                  icon: Icons.error_outline,
                                  title: 'Could not load history',
                                  message: '${snapshot.error}',
                                ),
                              ),
                            ],
                          );
                        }

                        if (items.isEmpty) {
                          return const Column(
                            children: [
                              _HistoryHeader(title: 'Viewing history'),
                              Expanded(
                                child: EmptyStateCard(
                                  icon: Icons.history_rounded,
                                  title: 'No viewing history yet',
                                  message: 'Attractions you view appear here',
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _HistoryHeader(
                              title: 'Viewing history',
                              actions: [
                                IconButton(
                                  tooltip: 'Clear history',
                                  onPressed: () => _clearHistory(context),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: const [
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: [
                                    0,
                                    (1 - 28 / bounds.height).clamp(0.0, 1.0),
                                    1,
                                  ],
                                ).createShader(bounds),
                                child: ListView.separated(
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    20,
                                    36 + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  itemCount: items.length + 1,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _HistorySummary(
                                        count: items.length,
                                      );
                                    }
                                    return _HistoryTile(item: items[index - 1]);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const _HistoryHeader({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: const Color(0xFF19456B),
          style: IconButton.styleFrom(backgroundColor: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF19456B),
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class _HistorySummary extends StatelessWidget {
  final int count;

  const _HistorySummary({required this.count});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: appSkySoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: appBorder),
        ),
        child: Text(
          '$count attractions viewed',
          style: const TextStyle(
            fontFamily: 'NotoSansThai',
            color: appSky,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final place = item.place;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(context, smoothRoute(DetailPage(place: place)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _HistoryImage(place: place),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansThai',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${place.province} • ${place.region}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansThai',
                        color: Color(0xFF557FA2),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatViewedAt(item.viewedAt),
                      style: const TextStyle(
                        fontFamily: 'NotoSansThai',
                        color: Color(0xFF557FA2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF3785BB)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatViewedAt(DateTime? value) {
    if (value == null) return 'Recent';
    final now = DateTime.now();
    final date = DateTime(value.year, value.month, value.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${value.day}/${value.month}/${value.year}';
  }
}

class _HistoryImage extends StatelessWidget {
  final Place place;

  const _HistoryImage({required this.place});

  @override
  Widget build(BuildContext context) {
    final imageCandidates = placeImageCandidates(place);
    final imagePath = imageCandidates.isNotEmpty ? imageCandidates.first : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ResolvedPlaceImage(
        imagePath: imagePath,
        placeName: place.name,
        width: 96,
        height: 104,
      ),
    );
  }
}
