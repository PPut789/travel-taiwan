import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/place_repository.dart';
import '../data/video_repository.dart';
import '../models/place_model.dart';
import '../widgets/app_chrome.dart';

const _uploadBg = Color(0xFFEAF5FB);
const _uploadInk = Color(0xFF263F52);
const _uploadPrimary = Color(0xFF76ADD1);
const _uploadPrimaryDark = Color(0xFF3A6384);
const _uploadMuted = Color(0xFF7A93A7);
const _uploadLine = Color(0xFFD8E9F3);
const _uploadSoft = Color(0xFFF5FBFF);

InputDecoration _uploadInputDecoration({
  required String hintText,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(icon, color: _uploadPrimaryDark),
    hintStyle: const TextStyle(
      color: _uploadMuted,
      fontWeight: FontWeight.w700,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _uploadLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _uploadPrimary, width: 1.6),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );
}

Color _uploadAccentFor(Place place) {
  final value = [
    place.category,
    place.type,
    place.name,
  ].join(' ').toLowerCase();
  if (value.contains('Nature')) return const Color(0xFF3AA6C8);
  if (value.contains('Mountains') ||
      value.contains('Hiking') ||
      value.contains('Parks')) {
    return const Color(0xFF3E9F83);
  }
  if (value.contains('Coast') ||
      value.contains('Beaches') ||
      value.contains('Island')) {
    return const Color(0xFF1FAEAF);
  }
  if (value.contains('Waterfalls') ||
      value.contains('Rivers') ||
      value.contains('Canals')) {
    return const Color(0xFF22A9D6);
  }
  if (value.contains('Viewpoints') || value.contains('Scenic viewing')) {
    return const Color(0xFFD6A431);
  }
  if (value.contains('Culture') ||
      value.contains('History') ||
      value.contains('Historic') ||
      value.contains('Temple') ||
      value.contains('Museums') ||
      value.contains('Worship and prayer')) {
    return const Color(0xFF8E78D6);
  }
  if (value.contains('Cafes') ||
      value.contains('Food') ||
      value.contains('Markets') ||
      value.contains('Shop')) {
    return const Color(0xFF54BFA9);
  }
  if (value.contains('Relaxation')) return const Color(0xFF72A94B);
  if (value.contains('Photography') || value.contains('Activities')) {
    return const Color(0xFFD76FA2);
  }
  return const Color(0xFF4A8FBD);
}

class UploadVideoPage extends StatefulWidget {
  const UploadVideoPage({super.key});

  @override
  State<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends State<UploadVideoPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _mapsController = TextEditingController();

  XFile? selectedVideo;
  Place? selectedPlace;
  bool useGoogleMaps = false;
  bool isUploading = false;
  bool isChangingPlace = false;
  String placeQuery = '';
  late final Future<List<Place>> placesFuture;

  @override
  void initState() {
    super.initState();
    placesFuture = PlaceRepository.loadPlaces();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _searchController.dispose();
    _mapsController.dispose();
    super.dispose();
  }

  bool get canUpload {
    final hasLocation = useGoogleMaps
        ? _mapsController.text.trim().isNotEmpty
        : selectedPlace != null;
    return selectedVideo != null && hasLocation && !isUploading;
  }

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() {
      selectedVideo = video;
    });
  }

  Future<void> _upload() async {
    final file = selectedVideo;
    if (file == null || !canUpload) return;

    setState(() {
      isUploading = true;
    });

    try {
      await VideoRepository.uploadVideo(
        file: file,
        caption: _captionController.text,
        selectedPlace: useGoogleMaps ? null : selectedPlace,
        googleMapsUrl: useGoogleMaps ? _mapsController.text : '',
        googlePlaceName: '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot upload video: $error')));
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  List<Place> _filterPlaces(List<Place> places) {
    final query = _normalize(placeQuery);
    if (query.isEmpty) {
      if (selectedPlace != null) return [selectedPlace!];
      return const <Place>[];
    }

    return places
        .where((place) {
          return [
            place.name,
            place.nameEn,
            place.province,
            place.region,
            place.category,
            place.type,
          ].map(_normalize).any((value) => value.contains(query));
        })
        .take(20)
        .toList();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uploadBg,
      body: SafeArea(
        child: ColoredBox(
          color: _uploadBg,
          child: Column(
            children: [
              const _UploadHeader(),
              Expanded(
                child: FutureBuilder<List<Place>>(
                  future: placesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _uploadPrimary),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load attractions: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _uploadInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }

                    final places = snapshot.data ?? const <Place>[];
                    final filteredPlaces = _filterPlaces(places);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _VideoPickerBox(
                          fileName: selectedVideo?.name,
                          onTap: isUploading ? null : _pickVideo,
                        ),
                        const SizedBox(height: 16),
                        _UploadPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                title: 'Choose a location',
                                subtitle:
                                    'Choose an attraction or use a Google Maps link',
                              ),
                              const SizedBox(height: 14),
                              SegmentedButton<bool>(
                                style: SegmentedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  selectedBackgroundColor: _uploadPrimaryDark,
                                  selectedForegroundColor: Colors.white,
                                  foregroundColor: _uploadPrimaryDark,
                                  side: const BorderSide(color: _uploadLine),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    icon: Icon(Icons.place_outlined),
                                    label: Text('In app'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: Icon(Icons.map_outlined),
                                    label: Text('Google Maps'),
                                  ),
                                ],
                                selected: {useGoogleMaps},
                                onSelectionChanged: isUploading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          useGoogleMaps = value.first;
                                        });
                                      },
                              ),
                              const SizedBox(height: 14),
                              if (useGoogleMaps) ...[
                                TextField(
                                  controller: _mapsController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: _uploadInputDecoration(
                                    hintText: 'Paste a Google Maps link',
                                    icon: Icons.link_outlined,
                                  ),
                                ),
                              ] else ...[
                                if (selectedPlace != null && !isChangingPlace)
                                  _SelectedPlaceCard(
                                    place: selectedPlace!,
                                    onChange: isUploading
                                        ? null
                                        : () {
                                            setState(() {
                                              isChangingPlace = true;
                                              _searchController.clear();
                                              placeQuery = '';
                                            });
                                          },
                                  )
                                else ...[
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        placeQuery = value;
                                      });
                                    },
                                    decoration: _uploadInputDecoration(
                                      hintText: 'Search attractions...',
                                      icon: Icons.search_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (placeQuery.trim().isEmpty)
                                    const _SmallHintCard(
                                      icon: Icons.travel_explore_rounded,
                                      text:
                                          'Search by attraction, city or county',
                                    )
                                  else if (filteredPlaces.isEmpty)
                                    const _NoPlaceResults()
                                  else
                                    ...filteredPlaces.map((place) {
                                      final isSelected =
                                          selectedPlace?.documentId ==
                                          place.documentId;
                                      return _PlaceOption(
                                        place: place,
                                        isSelected: isSelected,
                                        onTap: isUploading
                                            ? null
                                            : () {
                                                setState(() {
                                                  selectedPlace = place;
                                                  isChangingPlace = false;
                                                  _searchController.clear();
                                                  placeQuery = '';
                                                });
                                              },
                                      );
                                    }),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _UploadPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                title: 'Caption',
                                subtitle:
                                    'Add a short description for this video',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _captionController,
                                minLines: 3,
                                maxLines: 5,
                                decoration: _uploadInputDecoration(
                                  hintText: 'Describe your video...',
                                  icon: Icons.notes_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _UploadActionButton(
                          label: isUploading ? 'Uploading...' : 'Upload video',
                          isLoading: isUploading,
                          onPressed: canUpload ? _upload : null,
                        ),
                      ],
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

class _UploadHeader extends StatelessWidget {
  const _UploadHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 10),
      child: Row(
        children: [
          RoundBackButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: Colors.white,
            foregroundColor: _uploadPrimaryDark,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload video',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _uploadPrimaryDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Share your travel discoveries',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _uploadMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _UploadPanel extends StatelessWidget {
  final Widget child;

  const _UploadPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: _uploadPrimaryDark.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _UploadActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _UploadActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_upload_outlined, size: 22),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _uploadPrimaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _uploadMuted.withValues(alpha: 0.28),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          elevation: 4,
          shadowColor: _uploadPrimaryDark.withValues(alpha: 0.24),
        ),
      ),
    );
  }
}

class _VideoPickerBox extends StatelessWidget {
  final String? fileName;
  final VoidCallback? onTap;

  const _VideoPickerBox({required this.fileName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      shadowColor: _uploadPrimaryDark.withValues(alpha: 0.12),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _uploadLine, width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: _uploadPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_call_rounded,
                  color: _uploadPrimaryDark,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                fileName == null ? 'Choose video' : fileName!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _uploadInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose a video from your device',
                style: TextStyle(
                  color: _uploadMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _uploadPrimaryDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: _uploadMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NoPlaceResults extends StatelessWidget {
  const _NoPlaceResults();

  @override
  Widget build(BuildContext context) {
    return const _SmallHintCard(
      icon: Icons.search_off_outlined,
      text: 'No matching attractions',
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onChange;

  const _SelectedPlaceCard({required this.place, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final accent = _uploadAccentFor(place);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.check_circle_rounded, color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _uploadInk,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${place.province}, ${place.region}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _uploadMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _SmallHintCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallHintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _uploadSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _uploadLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: _uploadPrimaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _uploadMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceOption extends StatelessWidget {
  final Place place;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PlaceOption({
    required this.place,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _uploadAccentFor(place);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.12) : _uploadSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? accent : _uploadLine,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.place_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _uploadInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${place.province}, ${place.region}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _uploadMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
