import 'package:flutter/material.dart';

import '../data/video_repository.dart';
import '../models/place_model.dart';
import '../models/video_post_model.dart';
import 'app_chrome.dart';

Future<void> showVideoManageSheet({
  required BuildContext context,
  required VideoPost video,
  required List<Place> places,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _VideoManageSheet(video: video, places: places),
  );
}

class _VideoManageSheet extends StatefulWidget {
  final VideoPost video;
  final List<Place> places;

  const _VideoManageSheet({required this.video, required this.places});

  @override
  State<_VideoManageSheet> createState() => _VideoManageSheetState();
}

class _VideoManageSheetState extends State<_VideoManageSheet> {
  late final TextEditingController captionController;
  late final TextEditingController searchController;
  late final TextEditingController mapsController;

  bool useGoogleMaps = false;
  bool isSaving = false;
  String placeQuery = '';
  Place? selectedPlace;
  bool isChangingPlace = false;

  @override
  void initState() {
    super.initState();
    final video = widget.video;
    captionController = TextEditingController(text: video.caption);
    searchController = TextEditingController();
    mapsController = TextEditingController(text: video.googleMapsUrl);
    useGoogleMaps = video.placeMode == 'google_maps';
    selectedPlace = _findLinkedPlace();
  }

  @override
  void dispose() {
    captionController.dispose();
    searchController.dispose();
    mapsController.dispose();
    super.dispose();
  }

  bool get canSave {
    final hasLocation = useGoogleMaps
        ? mapsController.text.trim().isNotEmpty
        : selectedPlace != null;
    return hasLocation && !isSaving;
  }

  Place? _findLinkedPlace() {
    if (widget.video.attractionId.isEmpty) return null;
    for (final place in widget.places) {
      if (place.documentId == widget.video.attractionId) return place;
    }
    return null;
  }

  List<Place> _filteredPlaces() {
    final query = _normalize(placeQuery);
    if (query.isEmpty) {
      return const <Place>[];
    }

    return widget.places
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
        .take(18)
        .toList();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _save() async {
    if (!canSave) return;
    setState(() {
      isSaving = true;
    });

    try {
      await VideoRepository.updateVideoDetails(
        video: widget.video,
        caption: captionController.text,
        selectedPlace: useGoogleMaps ? null : selectedPlace,
        googleMapsUrl: useGoogleMaps ? mapsController.text : '',
        googlePlaceName: '',
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video details saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot save video: $error')));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filteredPlaces = _filteredPlaces();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF9FF),
        borderRadius: BorderRadius.zero,
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Edit video',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            _SegmentedLocationMode(
              useGoogleMaps: useGoogleMaps,
              onChanged: isSaving
                  ? null
                  : (value) => setState(() {
                      useGoogleMaps = value;
                      isChangingPlace = false;
                    }),
            ),
            const SizedBox(height: 14),
            if (useGoogleMaps) ...[
              _SoftTextField(
                controller: mapsController,
                onChanged: (_) => setState(() {}),
                labelText: 'Google Maps link',
                icon: Icons.link_outlined,
              ),
            ] else ...[
              if (selectedPlace != null && !isChangingPlace)
                _SelectedPlaceCard(
                  place: selectedPlace!,
                  onChange: isSaving
                      ? null
                      : () => setState(() {
                          isChangingPlace = true;
                          searchController.clear();
                          placeQuery = '';
                        }),
                )
              else ...[
                _SoftTextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      placeQuery = value;
                    });
                  },
                  labelText: 'Search attractions',
                  icon: Icons.search,
                ),
                const SizedBox(height: 10),
                if (placeQuery.trim().isEmpty)
                  const SizedBox.shrink()
                else if (filteredPlaces.isEmpty)
                  const _NoPlaceResults()
                else
                  ...filteredPlaces.map((place) {
                    final isSelected =
                        selectedPlace?.documentId == place.documentId;
                    return _PlaceOption(
                      place: place,
                      isSelected: isSelected,
                      onTap: isSaving
                          ? null
                          : () {
                              setState(() {
                                selectedPlace = place;
                                isChangingPlace = false;
                                searchController.clear();
                                placeQuery = '';
                              });
                            },
                    );
                  }),
              ],
            ],
            const SizedBox(height: 18),
            const Text(
              'Caption',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _CaptionTextArea(controller: captionController),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appSky,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: appBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: appSky,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(isSaving ? 'Saving...' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionTextArea extends StatelessWidget {
  final TextEditingController controller;

  const _CaptionTextArea({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 4,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: 'Write a caption...',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: appSky, width: 1.4),
        ),
      ),
    );
  }
}

class _SegmentedLocationMode extends StatelessWidget {
  final bool useGoogleMaps;
  final ValueChanged<bool>? onChanged;

  const _SegmentedLocationMode({
    required this.useGoogleMaps,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: appBorder),
      ),
      child: Row(
        children: [
          _SegmentedLocationButton(
            label: 'In app',
            icon: Icons.check_rounded,
            isSelected: !useGoogleMaps,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
          _SegmentedLocationButton(
            label: 'Google Maps',
            icon: Icons.map_outlined,
            isSelected: useGoogleMaps,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentedLocationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SegmentedLocationButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAF7FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: isSelected ? appSky : Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? appSky : Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _SoftTextField({
    required this.controller,
    required this.labelText,
    required this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: appSky, width: 1.4),
        ),
      ),
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onChange;

  const _SelectedPlaceCard({required this.place, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: appSky, size: 28),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${place.province}, ${place.region}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: appTextMuted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _NoPlaceResults extends StatelessWidget {
  const _NoPlaceResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'No matching attractions',
        style: TextStyle(color: appTextMuted, fontWeight: FontWeight.w700),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? const Color(0xFFEAF7FF) : const Color(0xFFF8FCFF),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${place.province}, ${place.region}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5E7A8A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF7EC8E3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
