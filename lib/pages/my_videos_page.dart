import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/place_repository.dart';
import '../data/video_repository.dart';
import '../models/place_model.dart';
import '../models/video_post_model.dart';
import '../utils/app_routes.dart';
import '../widgets/app_chrome.dart';
import '../widgets/video_manage_sheet.dart';
import 'detail_page.dart';

class MyVideosPage extends StatelessWidget {
  const MyVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FCFF),
      body: SafeArea(
        child: AppPastelBackground(
          child: Column(
            children: [
              const MinimalHeader(title: 'My videos'),
              Expanded(
                child: FutureBuilder<List<Place>>(
                  future: PlaceRepository.loadPlaces(),
                  builder: (context, placesSnapshot) {
                    if (placesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final places = placesSnapshot.data ?? const <Place>[];
                    return StreamBuilder<List<VideoPost>>(
                      stream: VideoRepository.watchMyVideos(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Cannot load videos: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          );
                        }

                        final videos = snapshot.data ?? const <VideoPost>[];
                        if (videos.isEmpty) {
                          return const _EmptyMyVideosState();
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.62,
                              ),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            return _MyVideoGridTile(
                              video: videos[index],
                              places: places,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  smoothRoute(
                                    _MyVideoViewerPage(
                                      video: videos[index],
                                      places: places,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyVideoGridTile extends StatefulWidget {
  final VideoPost video;
  final List<Place> places;
  final VoidCallback onTap;

  const _MyVideoGridTile({
    required this.video,
    required this.places,
    required this.onTap,
  });

  @override
  State<_MyVideoGridTile> createState() => _MyVideoGridTileState();
}

class _MyVideoGridTileState extends State<_MyVideoGridTile> {
  VideoPlayerController? controller;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    final nextController = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );
    controller = nextController;
    nextController
      ..setVolume(0)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            nextController.pause();
            setState(() {});
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              hasError = true;
            });
          });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video.attractionName.isNotEmpty
        ? widget.video.attractionName
        : 'Travel video';
    final caption = widget.video.caption.trim();
    final player = controller;

    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasError)
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 34,
                ),
              )
            else if (player != null && player.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: player.value.size.width,
                  height: player.value.size.height,
                  child: VideoPlayer(player),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.58, 1],
                ),
              ),
            ),
            Positioned(
              left: 9,
              right: 9,
              bottom: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.play_arrow_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: _TileVideoMenu(video: widget.video, places: widget.places),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyVideoViewerPage extends StatefulWidget {
  final VideoPost video;
  final List<Place> places;

  const _MyVideoViewerPage({required this.video, required this.places});

  @override
  State<_MyVideoViewerPage> createState() => _MyVideoViewerPageState();
}

class _MyVideoViewerPageState extends State<_MyVideoViewerPage> {
  late final VideoPlayerController controller;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );
    controller
      ..setLooping(true)
      ..setVolume(1)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {});
            controller.play();
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              hasError = true;
            });
          });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Place? get linkedPlace {
    if (widget.video.attractionId.isEmpty) return null;
    for (final place in widget.places) {
      if (place.documentId == widget.video.attractionId) return place;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final place = linkedPlace;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () {
                if (!controller.value.isInitialized) return;
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: _ViewerVideoSurface(
                controller: controller,
                hasError: hasError,
              ),
            ),
            const _ViewerGradient(),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.34),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 10,
              right: 12,
              child: _TileVideoMenu(video: widget.video, places: widget.places),
            ),
            Positioned(
              left: 20,
              right: 92,
              bottom: 28,
              child: _MyVideoSummary(video: widget.video),
            ),
            Positioned(
              right: 16,
              bottom: 34,
              child: _ViewerActionRail(video: widget.video, place: place),
            ),
            if (controller.value.isInitialized && !controller.value.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 82,
                  shadows: [Shadow(blurRadius: 18, color: Colors.black54)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerVideoSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final bool hasError;

  const _ViewerVideoSurface({required this.controller, required this.hasError});

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white70),
      );
    }

    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _ViewerGradient extends StatelessWidget {
  const _ViewerGradient();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.10),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.82),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

class _MyVideoSummary extends StatelessWidget {
  final VideoPost video;

  const _MyVideoSummary({required this.video});

  @override
  Widget build(BuildContext context) {
    final locationText = video.placeMode == 'google_maps'
        ? 'Google Maps location'
        : [
            video.province,
            video.region,
          ].where((item) => item.isNotEmpty).join(', ');

    return DefaultTextStyle(
      style: const TextStyle(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            video.attractionName.isNotEmpty
                ? video.attractionName
                : 'Travel video',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          if (video.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              video.caption.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewerActionRail extends StatelessWidget {
  final VideoPost video;
  final Place? place;

  const _ViewerActionRail({required this.video, required this.place});

  @override
  Widget build(BuildContext context) {
    final linkedPlace = place;
    if (linkedPlace == null && video.googleMapsUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (linkedPlace != null)
          _RoundActionButton(
            icon: Icons.place_outlined,
            label: 'Place',
            onTap: () {
              Navigator.push(
                context,
                smoothRoute(DetailPage(place: linkedPlace)),
              );
            },
          )
        else
          _RoundActionButton(
            icon: Icons.map_outlined,
            label: 'Maps',
            onTap: () => _openMaps(context),
          ),
      ],
    );
  }

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.tryParse(video.googleMapsUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open Maps link')));
    }
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.22),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
          ),
        ),
      ],
    );
  }
}

enum _TileVideoAction { edit, delete }

class _TileVideoMenu extends StatelessWidget {
  final VideoPost video;
  final List<Place> places;

  const _TileVideoMenu({required this.video, required this.places});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TileVideoAction>(
      tooltip: 'Video options',
      color: Colors.white,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      onSelected: (action) {
        switch (action) {
          case _TileVideoAction.edit:
            showVideoManageSheet(
              context: context,
              video: video,
              places: places,
            );
          case _TileVideoAction.delete:
            _deleteVideo(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _TileVideoAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TileVideoAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteVideo(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const AppConfirmDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Delete video?',
        message: 'This video will be removed from your videos',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      await VideoRepository.deleteVideo(video);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video deleted')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot delete video: $error')));
    }
  }
}

class _EmptyMyVideosState extends StatelessWidget {
  const _EmptyMyVideosState();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateCard(
      icon: Icons.video_library_outlined,
      title: 'No videos yet',
      message: 'Your uploaded videos appear here',
    );
  }
}
