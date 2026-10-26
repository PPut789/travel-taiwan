import 'package:flutter/material.dart';

import '../models/favorite_place.dart';
import '../models/place_model.dart';
import '../utils/place_media.dart';
import '../widgets/place_favorite_button.dart';
import '../widgets/resolved_place_image.dart';
import '../widgets/selection_background.dart';

class FavoritesPage extends StatelessWidget {
  final Stream<List<FavoritePlace>> favorites;
  final Future<void> Function(Place, bool) onFavoriteChanged;
  final Future<void> Function(Place) onOpenPlace;

  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.onFavoriteChanged,
    required this.onOpenPlace,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAF7FF),
    body: Stack(
      children: [
        const Positioned.fill(child: SelectionBackground()),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Favorites',
                        style: TextStyle(
                          fontFamily: 'NotoSansThai',
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF19456B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<FavoritePlace>>(
                  stream: favorites,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Could not load favorites. Please try again.',
                          style: TextStyle(fontFamily: 'NotoSansThai'),
                        ),
                      );
                    }
                    if (!snapshot.hasData &&
                        snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No favorites yet\nTap the heart on an attraction to save it here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansThai',
                              fontSize: 16,
                              color: Color(0xFF557FA2),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final place = items[index].place;
                        final images = placeImageCandidates(place);
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onOpenPlace(place),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ResolvedPlaceImage(
                                      imagePath: images.isEmpty
                                          ? ''
                                          : images.first,
                                      placeName: place.name,
                                      width: 72,
                                      height: 84,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'NotoSansThai',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF19456B),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          place.province,
                                          style: const TextStyle(
                                            fontFamily: 'NotoSansThai',
                                            fontSize: 14,
                                            color: Color(0xFF557FA2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PlaceFavoriteButton(
                                    selected: true,
                                    onChanged: (saved) =>
                                        onFavoriteChanged(place, saved),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
