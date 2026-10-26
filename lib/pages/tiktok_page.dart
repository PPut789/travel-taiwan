import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/user_repository.dart';
import '../data/video_repository.dart';
import '../data/place_repository.dart';
import '../models/app_settings.dart';
import '../models/place_model.dart';
import '../models/video_post_model.dart';
import '../utils/app_routes.dart';
import '../widgets/app_chrome.dart';
import '../widgets/video_manage_sheet.dart';
import 'detail_page.dart';

class VideoPage extends StatelessWidget {
  final List<Place> places;
  final String? initialVideoId;

  const VideoPage({super.key, required this.places, this.initialVideoId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSettings>(
      future: UserRepository.loadAppSettings(),
      builder: (context, settingsSnapshot) {
        if (settingsSnapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final settings = settingsSnapshot.data ?? const AppSettings();
        return StreamBuilder<List<VideoPost>>(
          stream: VideoRepository.watchPublishedVideos(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _EmptyVideoState(message: 'Cannot load videos');
            }

            final videos = [...?snapshot.data];
            final initialIndex = videos.indexWhere(
              (video) => video.id == initialVideoId,
            );
            if (initialIndex > 0) {
              videos.insert(0, videos.removeAt(initialIndex));
            }
            if (videos.isEmpty) {
              return const _EmptyVideoState(message: 'No videos yet');
            }

            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              itemBuilder: (context, index) {
                return _VideoFeedItem(
                  video: videos[index],
                  places: places,
                  settings: settings,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VideoFeedItem extends StatefulWidget {
  final VideoPost video;
  final List<Place> places;
  final AppSettings settings;

  const _VideoFeedItem({
    required this.video,
    required this.places,
    required this.settings,
  });

  @override
  State<_VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<_VideoFeedItem> {
  late final VideoPlayerController _controller;
  bool hasVideoError = false;
  late bool isMuted;
  late final Future<Place?> linkedPlaceFuture;

  @override
  void initState() {
    super.initState();
    final existingPlace = _linkedPlace;
    linkedPlaceFuture =
        existingPlace != null || widget.video.attractionId.isEmpty
        ? Future.value(existingPlace)
        : PlaceRepository.loadPlaceByDocumentId(widget.video.attractionId);
    isMuted = widget.settings.startVideosMuted;
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
          ..setLooping(true)
          ..setVolume(isMuted ? 0 : 1)
          ..initialize()
              .then((_) {
                if (!mounted) return;
                setState(() {});
                if (widget.settings.autoplayVideos) {
                  _controller.play();
                }
              })
              .catchError((_) {
                if (!mounted) return;
                setState(() {
                  hasVideoError = true;
                });
              });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Place? get _linkedPlace {
    final attractionId = widget.video.attractionId;
    if (attractionId.isEmpty) return null;

    for (final place in widget.places) {
      if (place.documentId == attractionId) return place;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == video.uploadedByUid;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () {
                if (!_controller.value.isInitialized) return;
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: _VideoSurface(
                controller: _controller,
                hasError: hasVideoError,
              ),
            ),
            _VideoGradient(),
            Positioned(
              left: 20,
              right: 78,
              bottom: 28,
              child: _VideoSummary(video: video),
            ),
            Positioned(
              right: 16,
              bottom: 62,
              child: FutureBuilder<Place?>(
                future: linkedPlaceFuture,
                builder: (context, snapshot) =>
                    _ActionRail(video: video, linkedPlace: snapshot.data),
              ),
            ),
            if (isOwner)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                right: 12,
                child: _OwnerVideoMenu(video: video, places: widget.places),
              ),
            if (_controller.value.isInitialized && !_controller.value.isPlaying)
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

class _VideoSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final bool hasError;

  const _VideoSurface({required this.controller, required this.hasError});

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return const _VideoErrorState();
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

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 42),
            SizedBox(height: 10),
            Text(
              'Cannot load this video',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
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

class _VideoSummary extends StatelessWidget {
  final VideoPost video;

  const _VideoSummary({required this.video});

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
            _videoTitle(video),
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
          const SizedBox(height: 8),
          Row(
            children: [
              _UploaderAvatar(video: video),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  video.uploadedByName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _videoTitle(VideoPost video) {
    final name = video.attractionName.trim();
    if (name.isNotEmpty) return name;
    if (video.placeMode == 'google_maps') return 'Location from Google Maps';
    return 'Travel videos';
  }
}

class _ActionRail extends StatelessWidget {
  final VideoPost video;
  final Place? linkedPlace;

  const _ActionRail({required this.video, required this.linkedPlace});

  @override
  Widget build(BuildContext context) {
    final place = linkedPlace;
    final hasMaps = video.googleMapsUrl.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (place != null)
          _RoundActionButton(
            icon: Icons.place_outlined,
            label: 'Place',
            onTap: () {
              Navigator.push(context, smoothRoute(DetailPage(place: place)));
            },
          )
        else if (hasMaps)
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

enum _OwnerVideoAction { edit, delete }

class _OwnerVideoMenu extends StatelessWidget {
  final VideoPost video;
  final List<Place> places;

  const _OwnerVideoMenu({required this.video, required this.places});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OwnerVideoAction>(
      tooltip: 'Video options',
      color: Colors.white,
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
      onSelected: (action) async {
        switch (action) {
          case _OwnerVideoAction.edit:
            try {
              final catalog = await PlaceRepository.loadPlaces();
              if (!context.mounted) return;
              await showVideoManageSheet(
                context: context,
                video: video,
                places: catalog,
              );
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not load places. Please try again.'),
                ),
              );
            }
          case _OwnerVideoAction.delete:
            _deleteVideo(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _OwnerVideoAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _OwnerVideoAction.delete,
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
        message: 'This video will be removed from the feed',
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
              width: 42,
              height: 42,
              child: Icon(icon, color: Colors.white, size: 23),
            ),
          ),
        ),
        const SizedBox(height: 5),
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

class _UploaderAvatar extends StatelessWidget {
  final VideoPost video;

  const _UploaderAvatar({required this.video});

  @override
  Widget build(BuildContext context) {
    final photoUrl = video.uploadedByPhotoUrl.trim();
    final name = video.uploadedByName.trim();

    return CircleAvatar(
      radius: 11,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 10,
        backgroundColor: const Color(0xFFEAF7FF),
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty
            ? Text(
                name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFF7EC8E3),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
    );
  }
}

class _EmptyVideoState extends StatelessWidget {
  final String message;

  const _EmptyVideoState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
