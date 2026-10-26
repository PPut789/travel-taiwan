import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/place_model.dart';
import '../utils/place_media.dart';
import '../data/favorites_repository.dart';
import '../models/favorite_place.dart';
import '../widgets/place_favorite_button.dart';
import '../widgets/selection_background.dart';
import '../widgets/resolved_place_image.dart';
import '../widgets/youtube_embed_view.dart';

const _detailBg = Color(0xFFEAF7FF);
const _detailInk = Color(0xFF19456B);
const _detailPrimary = Color(0xFF76ADD1);
const _detailPrimaryDark = Color(0xFF3A6384);
const _detailMuted = Color(0xFF7A93A7);
const _detailLine = Color(0xFFBFD1DF);

class DetailPage extends StatefulWidget {
  final Place place;
  final Stream<List<FavoritePlace>>? favorites;
  final Future<void> Function(Place, bool)? onFavoriteChanged;

  const DetailPage({
    super.key,
    required this.place,
    this.favorites,
    this.onFavoriteChanged,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  int currentImageIndex = 0;
  final Set<String> failedImageUrls = {};
  FavoritesRepository? _favoritesRepository;
  late final Stream<List<FavoritePlace>> _favorites;

  @override
  void initState() {
    super.initState();
    if (widget.favorites != null) {
      _favorites = widget.favorites!;
    } else {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _favoritesRepository = FavoritesRepository(
          firestore: FirebaseFirestore.instance,
          uid: uid,
        );
      }
      _favorites = _favoritesRepository?.watch() ?? Stream.value(const []);
    }
  }

  Future<void> _setFavorite(bool saved) async {
    if (widget.onFavoriteChanged != null) {
      await widget.onFavoriteChanged!(widget.place, saved);
      return;
    }
    final repository = _favoritesRepository;
    if (repository == null) {
      throw StateError('Sign in to save favorites');
    }
    await repository.setFavorite(widget.place, saved);
  }

  Widget _buildBackButton(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: _detailPrimary.withValues(alpha: .5)),
      boxShadow: [
        BoxShadow(
          color: _detailInk.withValues(alpha: .12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      color: _detailInk,
      iconSize: 24,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    ),
  );

  Widget _buildFavoriteButton() => StreamBuilder<List<FavoritePlace>>(
    stream: _favorites,
    builder: (context, snapshot) {
      final selected = (snapshot.data ?? []).any(
        (entry) =>
            FavoritePlace.keyFor(entry.place) ==
            FavoritePlace.keyFor(widget.place),
      );
      return PlaceFavoriteButton(
        selected: selected,
        onChanged: snapshot.hasData && !snapshot.hasError ? _setFavorite : null,
      );
    },
  );

  void _selectImage(int index, int imageCount) {
    setState(() {
      currentImageIndex = index.clamp(0, imageCount - 1);
    });
  }

  void _showPreviousImage(int imageCount) {
    if (imageCount <= 1) return;
    final nextIndex = currentImageIndex == 0
        ? imageCount - 1
        : currentImageIndex - 1;
    _selectImage(nextIndex, imageCount);
  }

  void _showNextImage(int imageCount) {
    if (imageCount <= 1) return;
    final nextIndex = currentImageIndex == imageCount - 1
        ? 0
        : currentImageIndex + 1;
    _selectImage(nextIndex, imageCount);
  }

  @override
  Widget build(BuildContext context) {
    final rawImages = placeImageCandidates(widget.place);
    final images = rawImages
        .where((image) => !failedImageUrls.contains(image))
        .toList();
    final youtubeUrls = widget.place.youtubeUrls.isNotEmpty
        ? widget.place.youtubeUrls
        : [if (widget.place.youtubeUrl.isNotEmpty) widget.place.youtubeUrl];
    final displayImages = images.isNotEmpty ? images : [''];

    if (currentImageIndex >= displayImages.length) {
      currentImageIndex = displayImages.length - 1;
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontFamily: 'NotoSansThai'),
      ),
      child: Scaffold(
        backgroundColor: _detailBg,
        body: Stack(
          children: [
            const Positioned.fill(child: SelectionBackground()),
            SafeArea(
              bottom: false,
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
                  stops: [0, (1 - 28 / bounds.height).clamp(0.0, 1.0), 1],
                ).createShader(bounds),
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: 36 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity < 0) {
                              _showNextImage(displayImages.length);
                            } else if (velocity > 0) {
                              _showPreviousImage(displayImages.length);
                            }
                          },
                          child: Stack(
                            children: [
                              Hero(
                                tag: _placeHeroTag(widget.place),
                                child: _PlaceImage(
                                  imagePath: displayImages[currentImageIndex],
                                  placeName: widget.place.name,
                                  height: 320,
                                  width: double.infinity,
                                  onLoadError: () {
                                    final imagePath =
                                        displayImages[currentImageIndex];
                                    if (!imagePath.startsWith('http')) {
                                      return;
                                    }
                                    setState(() {
                                      failedImageUrls.add(imagePath);
                                    });
                                  },
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 16,
                                child: _buildFavoriteButton(),
                              ),
                              if (displayImages.length > 1) ...[
                                Positioned(
                                  left: 12,
                                  top: 0,
                                  bottom: 0,
                                  child: _ImageNavButton(
                                    icon: Icons.chevron_left,
                                    onTap: () => _showPreviousImage(
                                      displayImages.length,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  top: 0,
                                  bottom: 0,
                                  child: _ImageNavButton(
                                    icon: Icons.chevron_right,
                                    onTap: () =>
                                        _showNextImage(displayImages.length),
                                  ),
                                ),
                                Positioned(
                                  right: 14,
                                  bottom: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${currentImageIndex + 1}/${displayImages.length}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          height: 76,

                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            scrollDirection: Axis.horizontal,

                            itemCount: displayImages.length,

                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  _selectImage(index, displayImages.length);
                                },

                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),

                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: currentImageIndex == index
                                          ? _detailPrimaryDark
                                          : Colors.transparent,

                                      width: 3,
                                    ),

                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),

                                    child: _PlaceImage(
                                      imagePath: displayImages[index],
                                      placeName: widget.place.name,

                                      width: 92,
                                      height: 70,
                                      onLoadError: () {
                                        final imagePath = displayImages[index];
                                        if (!imagePath.startsWith('http')) {
                                          return;
                                        }
                                        setState(() {
                                          failedImageUrls.add(imagePath);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: _detailPrimaryDark.withValues(alpha: 0.08),
                              blurRadius: 24,
                              spreadRadius: -8,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.place.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _detailInk,
                                          fontSize: 25,
                                          fontWeight: FontWeight.w900,
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${widget.place.province} • ${widget.place.region}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _detailMuted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _GoogleMapsButton(
                                  tone: _detailToneFor(widget.place.category),
                                  onPressed: () => _openGoogleMaps(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoPill(
                                  icon: Icons.category_outlined,
                                  text: widget.place.category,
                                ),
                                _InfoPill(
                                  icon: Icons.category_outlined,
                                  text: widget.place.type,
                                ),
                                _InfoPill(
                                  icon: Icons.explore_outlined,
                                  text: widget.place.activity,
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),
                            const Divider(color: _detailLine, height: 1),
                            const SizedBox(height: 24),

                            _DetailSection(
                              title: 'About this attraction',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (youtubeUrls.isNotEmpty) ...[
                                    _YouTubeSection(
                                      youtubeUrls: youtubeUrls,
                                      placeName: widget.place.name,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Text(
                                    widget.place.description,
                                    style: const TextStyle(
                                      color: _detailInk,
                                      fontSize: 16,
                                      height: 1.6,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: MediaQuery.paddingOf(context).top + 12,
              child: _buildBackButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final query = widget.place.name.isNotEmpty
        ? widget.place.name
        : widget.place.location;

    final Uri url;
    if (widget.place.latitude != null && widget.place.longitude != null) {
      url = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query':
            '${widget.place.name} ${widget.place.latitude},${widget.place.longitude}',
      });
    } else {
      url = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      });
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open Google Maps")));
    }
  }
}

String _placeHeroTag(Place place) {
  return 'place-image-${place.documentId.isNotEmpty ? place.documentId : place.id}';
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final tone = _detailToneFor(text);

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.accent.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: tone.accent.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tone.accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMapsButton extends StatelessWidget {
  final _DetailTone tone;
  final VoidCallback onPressed;

  const _GoogleMapsButton({required this.tone, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tone.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tone.accent.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _DetailTone {
  final Color background;
  final Color accent;
  final Color text;

  const _DetailTone({
    required this.background,
    required this.accent,
    required this.text,
  });
}

_DetailTone _detailToneFor(String label) {
  final accent = _detailAccentFor(label);
  final background = Color.lerp(Colors.white, accent, 0.16)!;

  return _DetailTone(
    background: background,
    accent: accent,
    text: Color.lerp(_detailInk, accent, 0.38)!,
  );
}

Color _detailAccentFor(String label) {
  if (label.contains("Nature")) {
    return const Color(0xFF3AA6C8);
  }
  if (label.contains("Mountains") ||
      label.contains("Hiking") ||
      label.contains("National parks")) {
    return const Color(0xFF3E9F83);
  }
  if (label.contains("Coast") ||
      label.contains("Beaches") ||
      label.contains("Island")) {
    return const Color(0xFF1FAEAF);
  }
  if (label.contains("Waterfalls") ||
      label.contains("Waterfalls") ||
      label.contains("Rivers") ||
      label.contains("Canals")) {
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
  if (label.contains("Historic sites")) {
    return const Color(0xFFC9903B);
  }
  if (label.contains("Cafes") ||
      label.contains("Food") ||
      label.contains("Markets") ||
      label.contains("Shop")) {
    return const Color(0xFF54BFA9);
  }
  if (label.contains("Relaxation") ||
      label.contains("Spas") ||
      label.contains("Wellness")) {
    return const Color(0xFF72A94B);
  }
  if (label.contains("Photography") ||
      label.contains("Activities") ||
      label.contains("Theme parks")) {
    return const Color(0xFFD76FA2);
  }
  return const Color(0xFF4A8FBD);
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _detailPrimaryDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _YouTubeSection extends StatefulWidget {
  final List<String> youtubeUrls;
  final String placeName;

  const _YouTubeSection({required this.youtubeUrls, required this.placeName});

  @override
  State<_YouTubeSection> createState() => _YouTubeSectionState();
}

class _YouTubeSectionState extends State<_YouTubeSection> {
  int currentVideoIndex = 0;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void _showVideo(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _showPreviousVideo() {
    if (widget.youtubeUrls.length <= 1) return;
    final nextIndex = currentVideoIndex == 0
        ? widget.youtubeUrls.length - 1
        : currentVideoIndex - 1;
    _showVideo(nextIndex);
  }

  void _showNextVideo() {
    if (widget.youtubeUrls.length <= 1) return;
    final nextIndex = currentVideoIndex == widget.youtubeUrls.length - 1
        ? 0
        : currentVideoIndex + 1;
    _showVideo(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: pageController,
            itemCount: widget.youtubeUrls.length,
            onPageChanged: (index) {
              setState(() {
                currentVideoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final url = widget.youtubeUrls[index];

              return _YouTubeCard(
                url: url,
                index: index,
                total: widget.youtubeUrls.length,
                placeName: widget.placeName,
              );
            },
          ),
        ),
        if (widget.youtubeUrls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _VideoNavButton(
                icon: Icons.chevron_left,
                onTap: _showPreviousVideo,
              ),
              const SizedBox(width: 10),
              Text(
                "${currentVideoIndex + 1} / ${widget.youtubeUrls.length}",
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              ...List.generate(widget.youtubeUrls.length, (index) {
                final isSelected = currentVideoIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isSelected ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _detailPrimary
                        : const Color(0xFFEAF7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
              const SizedBox(width: 10),
              _VideoNavButton(icon: Icons.chevron_right, onTap: _showNextVideo),
            ],
          ),
        ],
      ],
    );
  }
}

class _VideoNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _VideoNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.filled(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: _detailPrimary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _YouTubeCard extends StatefulWidget {
  final String url;
  final int index;
  final int total;
  final String placeName;

  const _YouTubeCard({
    required this.url,
    required this.index,
    required this.total,
    required this.placeName,
  });

  @override
  State<_YouTubeCard> createState() => _YouTubeCardState();
}

class _YouTubeCardState extends State<_YouTubeCard> {
  String? videoId;
  bool isPlayerVisible = false;

  @override
  void initState() {
    super.initState();
    videoId = YoutubePlayerController.convertUrlToId(widget.url);
  }

  @override
  void didUpdateWidget(covariant _YouTubeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      videoId = YoutubePlayerController.convertUrlToId(widget.url);
      isPlayerVisible = false;
    }
  }

  void _showPlayer() {
    if (videoId == null) return;
    setState(() {
      isPlayerVisible = true;
    });
  }

  void _hidePlayer() {
    setState(() {
      isPlayerVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = videoId == null
        ? ''
        : YoutubePlayerController.getThumbnail(videoId: videoId!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: videoId == null
            ? const _YouTubeUnavailableCard()
            : isPlayerVisible
            ? _EmbeddedYouTubePlayer(url: widget.url, onClose: _hidePlayer)
            : _YouTubeFallbackThumbnail(
                thumbnailUrl: thumbnailUrl,
                title: '${widget.placeName}: full travel video',
                onTap: _showPlayer,
              ),
      ),
    );
  }
}

class _EmbeddedYouTubePlayer extends StatelessWidget {
  final String url;
  final VoidCallback onClose;

  const _EmbeddedYouTubePlayer({required this.url, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        YouTubeEmbedView(key: ValueKey(url), url: url),
        Positioned(
          right: 10,
          top: 10,
          child: Material(
            color: Colors.black.withValues(alpha: 0.52),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Close video',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white,
              iconSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _YouTubeUnavailableCard extends StatelessWidget {
  const _YouTubeUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No videos available',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _YouTubeFallbackThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final String title;
  final VoidCallback? onTap;

  const _YouTubeFallbackThumbnail({
    required this.thumbnailUrl,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(color: Colors.black87);
              },
            ),
          const DecoratedBox(decoration: BoxDecoration(color: Colors.black38)),
          const Center(child: _YouTubePlayButton()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 15,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onTap != null)
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Play in app',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YouTubePlayButton extends StatelessWidget {
  const _YouTubePlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 42,
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  final String imagePath;
  final String placeName;
  final double height;
  final double width;
  final VoidCallback? onLoadError;

  const _PlaceImage({
    required this.imagePath,
    required this.placeName,
    required this.height,
    required this.width,
    this.onLoadError,
  });

  @override
  Widget build(BuildContext context) {
    return ResolvedPlaceImage(
      imagePath: imagePath,
      placeName: placeName,
      height: height,
      width: width,
      onLoadError: onLoadError,
    );
  }
}

class _ImageNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ImageNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
