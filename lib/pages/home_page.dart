import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/history_repository.dart';
import '../data/optional_history.dart';
import '../data/favorites_repository.dart';
import '../data/province_notification_repository.dart';
import '../data/video_repository.dart';
import '../data/local_recommendation_service.dart';
import '../data/place_repository.dart';
import '../data/place_search_service.dart';
import '../data/recommendation_repository.dart';
import '../data/recommendation_session.dart';
import '../data/user_repository.dart';
import '../models/place_model.dart';
import '../models/favorite_place.dart';
import '../models/province_notification.dart';
import '../models/recommendation_preferences.dart';
import '../utils/app_routes.dart';
import '../utils/place_media.dart';
import '../widgets/app_chrome.dart';
import '../widgets/place_favorite_button.dart';
import '../widgets/home_preference_cards.dart';
import '../widgets/home_notifications_button.dart';
import '../widgets/selection_background.dart';
import '../widgets/travel_bottom_nav.dart';
import '../widgets/resolved_place_image.dart';
import 'detail_page.dart';
import 'favorites_page.dart';
import 'location_page.dart';
import 'demographics_page.dart';
import 'profile_page.dart';
import 'tiktok_page.dart';
import 'upload_video_page.dart';

const _homeBg = Color(0xFFEAF7FF);
const _homeBlue = Color(0xFF76ADD1);
const _homeBlueDark = Color(0xFF3A6384);
const _homeMuted = Color(0xFF7A93A7);
const _homeLine = Color(0xFFBFD1DF);

class HomePage extends StatefulWidget {
  final RecommendationPreferences preferences;
  final int initialTabIndex;

  const HomePage({
    super.key,
    required this.preferences,
    this.initialTabIndex = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int currentTabIndex;
  Future<_HomeData>? homeDataFuture;
  late Future<String> profilePhotoFuture;
  ProvinceNotificationRepository? _notificationRepository;
  FavoritesRepository? _favoritesRepository;
  late final Stream<List<FavoritePlace>> _favorites;
  late final Stream<List<ProvinceNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    currentTabIndex = widget.initialTabIndex;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _favoritesRepository = FavoritesRepository(
        firestore: FirebaseFirestore.instance,
        uid: uid,
      );
      _notificationRepository = ProvinceNotificationRepository(
        firestore: FirebaseFirestore.instance,
        uid: uid,
      );
    }
    _notifications =
        _notificationRepository?.watch() ??
        const Stream<List<ProvinceNotification>>.empty();
    _favorites =
        _favoritesRepository?.watch() ??
        const Stream<List<FavoritePlace>>.empty();
    profilePhotoFuture = UserRepository.loadProfilePhotoUrl();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final username = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : user?.email ?? 'Username';
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontFamily: 'NotoSansThai', fontSizeDelta: 2),
      ),
      child: Scaffold(
        backgroundColor: _homeBg,
        body: currentTabIndex == 3
            ? const VideoPage(places: [])
            : FutureBuilder<_HomeData>(
                future: homeDataFuture ??= _loadHomeData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint('Home catalog failed: ${snapshot.error}');
                    return _CatalogLoadError(
                      onRetry: () {
                        setState(() {
                          homeDataFuture = _loadHomeData(refresh: true);
                        });
                      },
                    );
                  }

                  final homeData = snapshot.data ?? const _HomeData.empty();
                  final places = homeData.recommendedPlaces;
                  final allPlaces = homeData.allPlaces;
                  return HomeDashboard(
                    username: username,
                    profilePhotoFuture: profilePhotoFuture,
                    preferences: widget.preferences,
                    places: places,
                    favorites: _favorites,
                    onFavoriteChanged: _setFavorite,
                    onProfileTap: _openProfile,
                    notifications: _notifications,
                    selectedProvinces: widget.preferences.provinces,
                    onMarkNotificationsRead: _notificationRepository?.markRead,
                    onOpenNotification: (notification) =>
                        _openNotification(notification, allPlaces),
                    onOpenPlace: _openPlaceDetail,
                    onSelectLocation: () => Navigator.push(
                      context,
                      smoothRoute(
                        LocationPage(initialPreferences: widget.preferences),
                      ),
                    ),
                    onSelectInterests: () => Navigator.push(
                      context,
                      smoothRoute(
                        DemographicsPage(
                          selectedProvinces: widget.preferences.provinces,
                          initialPreferences: widget.preferences,
                        ),
                      ),
                    ),
                    onViewAll: () => Navigator.push(
                      context,
                      smoothRoute(
                        AdditionalPlacesPage(
                          title: 'More places to explore',
                          places: places.length > 1
                              ? places.sublist(1)
                              : <Place>[],
                          onOpenPlace: _openPlaceDetail,
                        ),
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: TravelBottomNav(
          selectedIndex: currentTabIndex,
          onSelected: (index) {
            if (index == 1) {
              _openFavorites();
              return;
            }

            if (index == 2) {
              Navigator.push(context, smoothRoute(const UploadVideoPage()));
              return;
            }

            if (index == 4) {
              _openProfile();
              return;
            }

            setState(() {
              currentTabIndex = index;
            });
          },
        ),
      ),
    );
  }

  Future<void> _setFavorite(Place place, bool saved) async {
    final repository = _favoritesRepository;
    if (repository == null) {
      throw StateError('Sign in to save favorites');
    }
    await repository.setFavorite(place, saved);
  }

  void _openFavorites() {
    final repository = _favoritesRepository;
    if (repository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to view favorites')),
      );
      return;
    }
    Navigator.push(
      context,
      smoothRoute(
        FavoritesPage(
          favorites: repository.watch(),
          onFavoriteChanged: _setFavorite,
          onOpenPlace: (saved) async {
            try {
              Place? place;
              if (saved.documentId.isNotEmpty) {
                place = await PlaceRepository.loadPlaceByDocumentId(
                  saved.documentId,
                );
              } else {
                for (final candidate in await PlaceRepository.loadPlaces()) {
                  if (candidate.id == saved.id) {
                    place = candidate;
                    break;
                  }
                }
              }
              if (!mounted) return;
              if (place == null) throw StateError('unavailable');
              await _openPlaceDetail(place);
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not open this attraction. Check your connection.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _openNotification(
    ProvinceNotification notification,
    List<Place> allPlaces,
  ) async {
    try {
      if (notification.isVideo) {
        final video = await VideoRepository.loadPublishedVideo(
          notification.sourceId,
        );
        if (!mounted) return;
        if (video == null) throw StateError('unavailable');
        Navigator.push(
          context,
          smoothRoute(VideoPage(places: allPlaces, initialVideoId: video.id)),
        );
      } else {
        final place = await PlaceRepository.loadPlaceByDocumentId(
          notification.sourceId,
        );
        if (!mounted) return;
        if (place == null) throw StateError('unavailable');
        await _openPlaceDetail(place);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This item is unavailable or your connection was lost.',
          ),
        ),
      );
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, smoothRoute(const ProfilePage()));
    if (!mounted) return;
    setState(() {
      profilePhotoFuture = UserRepository.loadProfilePhotoUrl();
    });
  }

  Future<_HomeData> _loadHomeData({bool refresh = false}) async {
    final snapshot = await RecommendationSession.shared.load(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      preferences: widget.preferences,
      loader: () async {
        final watch = Stopwatch()..start();
        final historyFuture = optionalHistoryBoost(
          HistoryRepository.loadPreferenceBoost,
        );
        final allPlaces = await (refresh
            ? PlaceRepository.refreshPlaces(
                provinces: widget.preferences.provinces,
              )
            : PlaceRepository.loadPlaces(
                provinces: widget.preferences.provinces,
              ));
        final historyBoost = await historyFuture;
        RecommendationSnapshot fallback() {
          debugPrint(
            'Home ready: ${allPlaces.length} candidates, ${watch.elapsedMilliseconds}ms (local ranking)',
          );
          return RecommendationSnapshot(
            allPlaces: allPlaces,
            recommendedPlaces:
                LocalRecommendationService.fallbackRecommendation(
                  places: allPlaces,
                  preferences: widget.preferences,
                  historyBoost: historyBoost,
                ),
          );
        }

        if (!RecommendationRepository.isConfigured) return fallback();
        final recommendedPlaces =
            await RecommendationRepository.recommendPlaces(
              preferences: widget.preferences,
              places: allPlaces,
            );
        return RecommendationSnapshot(
          allPlaces: allPlaces,
          recommendedPlaces: recommendedPlaces,
        );
      },
    );
    assert(() {
      debugPrint(
        'Recommendation snapshot (${RecommendationRepository.isConfigured ? 'model-api' : 'local'}): '
        '${snapshot.recommendedPlaces.map((place) => place.id).join(',')}',
      );
      return true;
    }());
    return _HomeData(
      allPlaces: snapshot.allPlaces,
      recommendedPlaces: snapshot.recommendedPlaces,
    );
  }

  Future<void> _openPlaceDetail(Place place) async {
    Navigator.push(context, smoothRoute(DetailPage(place: place)));
    try {
      final settings = await UserRepository.loadAppSettings(
        refresh: true,
      ).timeout(const Duration(seconds: 3));
      if (settings.saveViewingHistory) {
        await HistoryRepository.addViewedPlace(
          place,
        ).timeout(const Duration(seconds: 3));
      }
    } catch (error) {
      debugPrint('Viewing history was not saved: $error');
    }
  }
}

class _CatalogLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _CatalogLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Could not load places. Check your connection.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class HomeDashboard extends StatelessWidget {
  final String username;
  final Future<String> profilePhotoFuture;
  final RecommendationPreferences preferences;
  final List<Place> places;
  final Stream<List<FavoritePlace>> favorites;
  final Future<void> Function(Place, bool)? onFavoriteChanged;
  final VoidCallback onProfileTap;
  final Stream<List<ProvinceNotification>> notifications;
  final List<String> selectedProvinces;
  final Future<void> Function(List<String>)? onMarkNotificationsRead;
  final Future<void> Function(ProvinceNotification)? onOpenNotification;
  final VoidCallback onSelectLocation;
  final VoidCallback onSelectInterests;
  final VoidCallback onViewAll;
  final Future<void> Function(Place) onOpenPlace;

  const HomeDashboard({
    super.key,
    required this.username,
    required this.profilePhotoFuture,
    required this.preferences,
    required this.places,
    this.favorites = const Stream<List<FavoritePlace>>.empty(),
    this.onFavoriteChanged,
    required this.onProfileTap,
    this.notifications = const Stream<List<ProvinceNotification>>.empty(),
    this.selectedProvinces = const [],
    this.onMarkNotificationsRead,
    this.onOpenNotification,
    required this.onSelectLocation,
    required this.onSelectInterests,
    required this.onViewAll,
    required this.onOpenPlace,
  });

  @override
  Widget build(BuildContext context) {
    final additional = places.length > 1 ? places.sublist(1) : <Place>[];
    return StreamBuilder<List<FavoritePlace>>(
      stream: favorites,
      builder: (context, snapshot) {
        final savedKeys = (snapshot.data ?? [])
            .map((entry) => FavoritePlace.keyFor(entry.place))
            .toSet();
        return Stack(
          fit: StackFit.expand,
          children: [
            const _HomeMainBackground(),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final width = constraints.maxWidth.clamp(380.0, 600.0);
                  final minimumHeight =
                      760 + (textScale - 1).clamp(0.0, 2.0) * 360;
                  final height = constraints.maxHeight < minimumHeight
                      ? minimumHeight
                      : constraints.maxHeight;
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Column(
                          children: [
                            _HomeHeader(
                              username: username,
                              profilePhotoFuture: profilePhotoFuture,
                              onProfileTap: onProfileTap,
                              notifications: notifications,
                              selectedProvinces: selectedProvinces,
                              onMarkNotificationsRead: onMarkNotificationsRead,
                              onOpenNotification: onOpenNotification,
                            ),
                            HomePreferenceCards(
                              preferences: preferences,
                              onSelectLocation: onSelectLocation,
                              onSelectInterests: onSelectInterests,
                            ),
                            const _HomeSectionHeader(
                              title: 'Recommended for you',
                              showViewAll: false,
                            ),
                            if (places.isNotEmpty) ...[
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: _FeaturedPlaceCard(
                                    place: places.first,
                                    isFavorite: savedKeys.contains(
                                      FavoritePlace.keyFor(places.first),
                                    ),
                                    onFavoriteChanged: onFavoriteChanged == null
                                        ? null
                                        : (saved) => onFavoriteChanged!(
                                            places.first,
                                            saved,
                                          ),
                                    onTap: () => onOpenPlace(places.first),
                                  ),
                                ),
                              ),
                              if (additional.isNotEmpty) ...[
                                _HomeSectionHeader(
                                  title: 'More places to explore',
                                  showViewAll: true,
                                  topPadding: 14,
                                  onViewAll: onViewAll,
                                ),
                                Expanded(
                                  flex: 6,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: additional.length,
                                    separatorBuilder: (_, index) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) =>
                                        _AdditionalPlaceCard(
                                          place: additional[index],
                                          isFavorite: savedKeys.contains(
                                            FavoritePlace.keyFor(
                                              additional[index],
                                            ),
                                          ),
                                          onFavoriteChanged:
                                              onFavoriteChanged == null
                                              ? null
                                              : (saved) => onFavoriteChanged!(
                                                  additional[index],
                                                  saved,
                                                ),
                                          onTap: () =>
                                              onOpenPlace(additional[index]),
                                        ),
                                  ),
                                ),
                              ],
                            ] else
                              const Expanded(
                                child: Center(
                                  child: _EmptyPlaceState(isSearching: false),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class AdditionalPlacesPage extends StatefulWidget {
  final String title;
  final List<Place> places;
  final Future<void> Function(Place place) onOpenPlace;

  const AdditionalPlacesPage({
    super.key,
    required this.title,
    required this.places,
    required this.onOpenPlace,
  });

  @override
  State<AdditionalPlacesPage> createState() => _AdditionalPlacesPageState();
}

class _AdditionalPlacesPageState extends State<AdditionalPlacesPage> {
  late final TextEditingController searchController;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Place> get filteredPlaces {
    final query = PlaceSearchService.normalizeSearchText(searchText);
    if (query.isEmpty) return widget.places;
    return PlaceSearchService.search(widget.places, query);
  }

  @override
  Widget build(BuildContext context) {
    final places = filteredPlaces;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      body: Stack(
        children: [
          const Positioned.fill(child: SelectionBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Row(
                    children: [
                      RoundBackButton(
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: Colors.white.withValues(alpha: 0.86),
                        foregroundColor: const Color(0xFF171817),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansThai',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.places.length} attractions',
                              style: const TextStyle(
                                fontFamily: 'NotoSansThai',
                                color: Color(0xFF6B7E8C),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                          child: _AdditionalSearchField(
                            controller: searchController,
                            onChanged: (value) {
                              setState(() {
                                searchText = value;
                              });
                            },
                            onClear: () {
                              searchController.clear();
                              setState(() {
                                searchText = '';
                              });
                            },
                          ),
                        ),
                      ),
                      if (places.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No matching attractions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NotoSansThai',
                                  color: Color(0xFF6B7E8C),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          sliver: SliverList.separated(
                            itemCount: places.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final place = places[index];
                              return _WideAdditionalPlaceCard(
                                place: place,
                                onTap: () async {
                                  await widget.onOpenPlace(place);
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
          ),
        ],
      ),
    );
  }
}

class _AdditionalSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _AdditionalSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7ECF7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontFamily: 'NotoSansThai'),
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search places, cities or types',
          hintStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            color: Color(0xFF7C8A94),
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF7EC8E3),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF6B7E8C),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _WideAdditionalPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _WideAdditionalPlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageCandidates = placeImageCandidates(place);
    final cardHeight =
        148 * (MediaQuery.textScalerOf(context).scale(15) / 15).clamp(1.0, 2.0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD7ECF7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: _PlaceImage(
                  imagePath: imageCandidates.isNotEmpty
                      ? imageCandidates.first
                      : '',
                  placeName: place.name,
                  width: 104,
                  height: cardHeight,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansThai',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFF6B7E8C),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${place.province} • ${place.region}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansThai',
                                color: Color(0xFF6B7E8C),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _SoftCategoryChip(
                            text: place.category,
                            fontSize: 12,
                            fontFamily: 'NotoSansThai',
                          ),
                          _SoftCategoryChip(
                            text: place.type,
                            fontSize: 12,
                            fontFamily: 'NotoSansThai',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMainBackground extends StatelessWidget {
  const _HomeMainBackground();

  @override
  Widget build(BuildContext context) {
    return const SelectionBackground();
  }
}

class _HomeHeader extends StatelessWidget {
  final String username;
  final Future<String> profilePhotoFuture;
  final VoidCallback onProfileTap;
  final Stream<List<ProvinceNotification>> notifications;
  final List<String> selectedProvinces;
  final Future<void> Function(List<String>)? onMarkNotificationsRead;
  final Future<void> Function(ProvinceNotification)? onOpenNotification;

  const _HomeHeader({
    required this.username,
    required this.profilePhotoFuture,
    required this.onProfileTap,
    required this.notifications,
    required this.selectedProvinces,
    this.onMarkNotificationsRead,
    this.onOpenNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Open profile',
                child: InkWell(
                  onTap: onProfileTap,
                  customBorder: const CircleBorder(),
                  child: FutureBuilder<String>(
                    future: profilePhotoFuture,
                    builder: (context, snapshot) => _WelcomeBadge(
                      username: username,
                      photoUrl: snapshot.data,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $username",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansThai',
                        color: _homeBlueDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Ready to discover somewhere new?",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansThai',
                        color: _homeBlueDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HomeNotificationsButton(
                notifications: notifications,
                selectedProvinces: selectedProvinces,
                onMarkRead: onMarkNotificationsRead,
                onOpenNotification: onOpenNotification,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeBadge extends StatelessWidget {
  final String username;
  final String? photoUrl;

  const _WelcomeBadge({required this.username, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final trimmed = username.trim();
    final initial = trimmed.isEmpty
        ? 'U'
        : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _homeBlue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _homeBlue.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl?.trim().isNotEmpty == true
            ? Image.network(
                photoUrl!,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initial(initial),
              )
            : _initial(initial),
      ),
    );
  }

  Widget _initial(String initial) => Center(
    child: Text(
      initial,
      style: const TextStyle(
        fontFamily: 'NotoSansThai',
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final bool showViewAll;
  final double topPadding;
  final VoidCallback? onViewAll;

  const _HomeSectionHeader({
    required this.title,
    required this.showViewAll,
    this.topPadding = 8,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 16),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 24,
            decoration: BoxDecoration(
              color: _homeBlue,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _homeBlue.withValues(alpha: 0.28),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoSansThai',
                color: _homeBlueDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.4,
              ),
            ),
          ),
          if (showViewAll) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onViewAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all',
                        style: TextStyle(
                          fontFamily: 'NotoSansThai',
                          color: _homeBlueDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _homeBlueDark,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedPlaceCard extends StatefulWidget {
  final Place place;
  final VoidCallback onTap;
  final bool isFavorite;
  final Future<void> Function(bool)? onFavoriteChanged;

  const _FeaturedPlaceCard({
    required this.place,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteChanged,
  });

  @override
  State<_FeaturedPlaceCard> createState() => _FeaturedPlaceCardState();
}

class _FeaturedPlaceCardState extends State<_FeaturedPlaceCard> {
  bool isPressed = false;

  void _setPressed(bool value) {
    if (isPressed == value) return;
    setState(() {
      isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final imageCandidates = placeImageCandidates(place);

    return AnimatedScale(
      scale: isPressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          _setPressed(false);
          widget.onTap();
        },
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _homeLine.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: _homeBlueDark.withValues(alpha: isPressed ? 0.08 : 0.16),
                blurRadius: isPressed ? 12 : 24,
                offset: Offset(0, isPressed ? 4 : 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: _placeHeroTag(place),
                  child: _PlaceImage(
                    imagePath: imageCandidates.isNotEmpty
                        ? imageCandidates.first
                        : '',
                    placeName: place.name,
                    height: 210,
                    width: double.infinity,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.16),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                      stops: const [0.42, 0.70, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansThai',
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${place.province} • ${place.region}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansThai',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _OverlayChip(text: place.category),
                          _OverlayChip(text: place.type),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: PlaceFavoriteButton(
                    key: ValueKey('favorite:${FavoritePlace.keyFor(place)}'),
                    selected: widget.isFavorite,
                    onChanged: widget.onFavoriteChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdditionalPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  final bool isFavorite;
  final Future<void> Function(bool)? onFavoriteChanged;

  const _AdditionalPlaceCard({
    required this.place,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final images = placeImageCandidates(place);
    return Material(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 176,
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PlaceImage(
                      imagePath: images.isEmpty ? '' : images.first,
                      placeName: place.name,
                      width: double.infinity,
                      height: 80,
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: PlaceFavoriteButton(
                        key: ValueKey(
                          'favorite:${FavoritePlace.keyFor(place)}',
                        ),
                        selected: isFavorite,
                        onChanged: onFavoriteChanged,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansThai',
                                fontSize: 15,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: _homeBlueDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.province,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansThai',
                                fontSize: 14,
                                color: _homeMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _SoftCategoryChip(
                                    text: place.category,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _SoftCategoryChip(text: place.type),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  final String text;

  const _OverlayChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = _preferenceToneFor(text);
    return Container(
      constraints: const BoxConstraints(maxWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.accent.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: tone.accent.withValues(alpha: 0.16),
            blurRadius: 6,
            spreadRadius: -1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'NotoSansThai',
          color: tone.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SoftCategoryChip extends StatelessWidget {
  final String text;
  final double fontSize;
  final String? fontFamily;

  const _SoftCategoryChip({
    required this.text,
    this.fontSize = 11.5,
    this.fontFamily = 'NotoSansThai',
  });

  @override
  Widget build(BuildContext context) {
    final tone = _preferenceToneFor(text);
    final isShortLabel = text.length <= 10;
    return Container(
      constraints: const BoxConstraints(maxWidth: 116),
      alignment: isShortLabel ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.accent.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: tone.accent.withValues(alpha: 0.20),
            blurRadius: 6,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: isShortLabel ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: tone.text,
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PreferenceTone {
  final Color background;
  final Color accent;
  final Color text;

  const _PreferenceTone({
    required this.background,
    required this.accent,
    required this.text,
  });
}

_PreferenceTone _preferenceToneFor(String label) {
  final accent = _preferenceAccentFor(label);

  return _PreferenceTone(
    background: Color.lerp(Colors.white, accent, 0.36)!,
    accent: accent,
    text: Color.lerp(_homeBlueDark, accent, 0.52)!,
  );
}

Color _preferenceAccentFor(String label) {
  if (label.contains("Nature")) {
    return const Color(0xFF3AA6C8);
  }
  if (label.contains("Mountains") ||
      label.contains("Hiking") ||
      label.contains("Parks")) {
    return const Color(0xFF3E9F83);
  }
  if (label.contains("Islands")) {
    return const Color(0xFF1FAEAF);
  }
  if (label.contains("Waterfalls") ||
      label.contains("Rivers") ||
      label.contains("Lakes") ||
      label.contains("Coast") ||
      label.contains("Beaches") ||
      label.contains("Island") ||
      label.contains("Swimming")) {
    return const Color(0xFF22A9D6);
  }
  if (label.contains("Viewpoints") || label.contains("Scenic viewing")) {
    return const Color(0xFFD6A431);
  }
  if (label.contains("Culture") ||
      label.contains("History") ||
      label.contains("Historic") ||
      label.contains("Temple") ||
      label.contains("Museums") ||
      label.contains("Worship and prayer")) {
    return const Color(0xFF8E78D6);
  }
  if (label.contains("Markets") || label.contains("Shop")) {
    return const Color(0xFFC9903B);
  }
  if (label.contains("Relaxation") ||
      label.contains("Spas") ||
      label.contains("Wellness")) {
    return const Color(0xFF54BFA9);
  }
  if (label.contains("Photography") ||
      label.contains("Activities") ||
      label.contains("Theme parks")) {
    return const Color(0xFFD76FA2);
  }
  if (label.contains("Zoos") ||
      label.contains("Farms") ||
      label.contains("Gardens")) {
    return const Color(0xFF72A94B);
  }
  if (label.contains("Communities")) {
    return const Color(0xFF4F9BD6);
  }
  if (label.contains("Hot springs")) {
    return const Color(0xFFD47A52);
  }
  return const Color(0xFF4A8FBD);
}

class _EmptyPlaceState extends StatelessWidget {
  final bool isSearching;

  const _EmptyPlaceState({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return EmptyStateCard(
      icon: isSearching ? Icons.search_off_rounded : Icons.explore_off_rounded,
      title: isSearching ? 'No results found' : 'No recommendations yet',
      message: isSearching
          ? 'Try another search, city or attraction type'
          : 'Update your interests to discover more places',
    );
  }
}

String _placeHeroTag(Place place) {
  return 'place-image-${place.documentId.isNotEmpty ? place.documentId : place.id}';
}

class _HomeData {
  final List<Place> allPlaces;
  final List<Place> recommendedPlaces;

  const _HomeData({required this.allPlaces, required this.recommendedPlaces});

  const _HomeData.empty() : allPlaces = const [], recommendedPlaces = const [];
}

class _PlaceImage extends StatelessWidget {
  final String imagePath;
  final String placeName;
  final double height;
  final double width;

  const _PlaceImage({
    required this.imagePath,
    required this.placeName,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ResolvedPlaceImage(
      imagePath: imagePath,
      placeName: placeName,
      height: height,
      width: width,
    );
  }
}
