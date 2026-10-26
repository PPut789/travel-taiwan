import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/user_repository.dart';
import '../data/recommendation_session.dart';
import '../data/place_repository.dart';
import '../firebase_options.dart';
import '../models/recommendation_preferences.dart';
import '../models/interest_choices.dart';
import '../utils/app_routes.dart';
import 'home_page.dart';

const _interestBg = Color(0xFFF3F9FD);
const _interestPanelTint = Color(0xFFEAF5FB);
const _interestInk = Color(0xFF19456B);
const _interestMuted = Color(0xFF557FA2);
const _interestPrimary = Color(0xFF76ADD1);
const _interestPrimaryDark = Color(0xFF3A6384);
const _interestLine = Color(0xFFD7E8F2);
const _optionLabelStyle = TextStyle(
  fontFamily: 'NotoSansThai',
  fontSize: 10,
  height: 1.2,
  fontWeight: FontWeight.w600,
);

class InterestPage extends StatefulWidget {
  final List<String> selectedProvinces;
  final RecommendationPreferences? initialPreferences;
  final Future<InterestChoices> Function()? choicesLoader;

  const InterestPage({
    super.key,
    required this.selectedProvinces,
    this.initialPreferences,
    this.choicesLoader,
  });

  @override
  State<InterestPage> createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  List<String> categories = [];

  List<String> selectedCategories = [];

  List<String> types = [];

  List<String> selectedTypes = [];

  List<String> activities = [];

  List<String> selectedActivities = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadChoices();
    final preferences = widget.initialPreferences;
    if (preferences == null) return;

    selectedCategories.addAll(preferences.categories);
    selectedTypes.addAll(preferences.types);
    selectedActivities.addAll(preferences.activities);
  }

  Future<void> _loadChoices() async {
    if (widget.choicesLoader == null && !DefaultFirebaseOptions.isConfigured) {
      return;
    }
    try {
      final choices =
          await (widget.choicesLoader ?? PlaceRepository.loadInterestChoices)();
      if (!mounted) return;
      setState(() {
        categories = choices.categories;
        types = choices.types;
        activities = choices.activities;
        selectedCategories.removeWhere((value) => !categories.contains(value));
        selectedTypes.removeWhere((value) => !types.contains(value));
        selectedActivities.removeWhere((value) => !activities.contains(value));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not load available interests.'),
          action: SnackBarAction(label: 'Retry', onPressed: _loadChoices),
        ),
      );
    }
  }

  bool get canGenerate =>
      selectedCategories.isNotEmpty &&
      selectedTypes.isNotEmpty &&
      selectedActivities.isNotEmpty;

  Future<void> _generateRecommendation() async {
    final preferences = RecommendationPreferences(
      provinces: widget.selectedProvinces,
      categories: selectedCategories,
      types: selectedTypes,
      activities: selectedActivities,
      age: widget.initialPreferences?.age,
      gender: widget.initialPreferences?.gender,
    );

    setState(() {
      isSaving = true;
    });

    try {
      await UserRepository.savePreferences(preferences);
      RecommendationSession.shared.beginNewSearch(
        userId: DefaultFirebaseOptions.isConfigured
            ? FirebaseAuth.instance.currentUser?.uid ?? ''
            : '',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot save preferences. Please check Firestore rules.',
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      smoothRoute(HomePage(preferences: preferences)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _interestBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _InterestScenicBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _InterestHeader(onBack: () => Navigator.pop(context)),
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
                      stops: [0, (1 - 28 / bounds.height).clamp(0.0, 1.0), 1],
                    ).createShader(bounds),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        2,
                        20,
                        36 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Choose your interests for personalized recommendations",
                            style: TextStyle(
                              fontFamily: 'NotoSansThai',
                              color: _interestMuted,
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InterestContentPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _InterestSectionHeader(
                                  title: "Main interests",
                                  icon: Icons.favorite_rounded,
                                ),
                                const SizedBox(height: 10),
                                _InterestOptionGrid(
                                  values: categories,
                                  selectedValues: selectedCategories,
                                  iconForValue: _categoryIcon,
                                  onChanged: (category, selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedCategories.add(category);
                                      } else {
                                        selectedCategories.remove(category);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 18),
                                const _InterestSectionHeader(
                                  title: "Attraction types",
                                  icon: Icons.place_rounded,
                                  trailing: "Select multiple",
                                ),
                                const SizedBox(height: 10),
                                _InterestOptionGrid(
                                  values: types,
                                  selectedValues: selectedTypes,
                                  iconForValue: _typeIcon,
                                  onChanged: (type, selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedTypes.add(type);
                                      } else {
                                        selectedTypes.remove(type);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 18),
                                const _InterestSectionHeader(
                                  title: "Preferred activities",
                                  icon: Icons.star_rounded,
                                  trailing: "Select multiple",
                                ),
                                const SizedBox(height: 10),
                                _InterestOptionGrid(
                                  values: activities,
                                  selectedValues: selectedActivities,
                                  iconForValue: _activityIcon,
                                  onChanged: (activity, selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedActivities.add(activity);
                                      } else {
                                        selectedActivities.remove(activity);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                _InterestSelectionSummary(
                                  count:
                                      selectedCategories.length +
                                      selectedTypes.length +
                                      selectedActivities.length,
                                  onClear: () {
                                    setState(() {
                                      selectedCategories.clear();
                                      selectedTypes.clear();
                                      selectedActivities.clear();
                                    });
                                  },
                                ),
                                if (!canGenerate) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Select at least one category, type and activity",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'NotoSansThai',
                                      color: _interestMuted,
                                      fontSize: 11.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _InterestNextButton(
                            label: "Continue",
                            isLoading: isSaving,
                            onPressed: canGenerate
                                ? isSaving
                                      ? null
                                      : _generateRecommendation
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String value) =>
      _categoryIcons[value] ?? Icons.interests_outlined;
  IconData _typeIcon(String value) =>
      _typeIcons[value] ?? Icons.explore_outlined;
  IconData _activityIcon(String value) =>
      _activityIcons[value] ?? Icons.interests_outlined;
}

// Exact keys from the Taiwan catalog, rather than inherited labels.
const _categoryIcons = <String, IconData>{
  'Agriculture and industry': Icons.agriculture_outlined,
  'Arts and exhibitions': Icons.palette_outlined,
  'Culture and heritage': Icons.account_balance_outlined,
  'Faith and spirituality': Icons.temple_buddhist_outlined,
  'Leisure and recreation': Icons.weekend_outlined,
  'Nature and ecology': Icons.landscape_outlined,
  'Shopping': Icons.shopping_bag_outlined,
  'Sports and fitness': Icons.fitness_center_outlined,
  'Transport landmarks': Icons.train_outlined,
  'Wellness': Icons.spa_outlined,
};

const _typeIcons = <String, IconData>{
  'Arts': Icons.palette_outlined,
  'Arts and cultural venues': Icons.theater_comedy_outlined,
  'Cultural heritage': Icons.account_balance_outlined,
  'Culture': Icons.diversity_3_outlined,
  'Ecological education venues': Icons.school_outlined,
  'Ecology': Icons.eco_outlined,
  'Entertainment venues': Icons.local_activity_outlined,
  'Forest recreation areas': Icons.forest_outlined,
  'Hakka culture': Icons.holiday_village_outlined,
  'Hot springs': Icons.hot_tub_outlined,
  'Indigenous culture': Icons.groups_outlined,
  'Leisure agriculture': Icons.agriculture_outlined,
  'Licensed amusement parks': Icons.attractions_outlined,
  'Lowland forest parks': Icons.nature_outlined,
  'Metropolitan parks': Icons.location_city_outlined,
  'National nature parks': Icons.terrain_outlined,
  'National parks': Icons.park_outlined,
  'National scenic areas': Icons.panorama_outlined,
  'Natural scenery': Icons.landscape_outlined,
  'Parks and green spaces': Icons.grass_outlined,
  'Recreation': Icons.weekend_outlined,
  'Religious sites': Icons.temple_buddhist_outlined,
  'Shopping districts and shops': Icons.storefront_outlined,
  'Sports and fitness': Icons.fitness_center_outlined,
  'Tourism factories': Icons.factory_outlined,
  'Transport terminals and stations': Icons.train_outlined,
  'Water environments': Icons.water_outlined,
};

const _activityIcons = <String, IconData>{
  'Cycling': Icons.directions_bike_outlined,
  'Diving': Icons.scuba_diving_outlined,
  'Exhibition visits': Icons.museum_outlined,
  'Fruit picking': Icons.apple_outlined,
  'Hands-on workshops': Icons.handyman_outlined,
  'Hot spring experiences': Icons.hot_tub_outlined,
  'Paddling': Icons.kayaking_outlined,
  'Photography': Icons.photo_camera_outlined,
  'Scenic viewing': Icons.visibility_outlined,
  'Surfing': Icons.surfing_outlined,
  'Walking and hiking': Icons.hiking_outlined,
  'Worship and prayer': Icons.temple_buddhist_outlined,
};

class _InterestScenicBackground extends StatelessWidget {
  const _InterestScenicBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F8FD), Color(0xFFF7FBFF)],
        ),
      ),
      child: CustomPaint(painter: _InterestSeaWavePainter()),
    );
  }
}

class _InterestSeaWavePainter extends CustomPainter {
  const _InterestSeaWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 2; i++) {
      final y = size.height - 58 + i * 25;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * .35,
          y - 45,
          size.width * .55,
          y + 90,
          size.width,
          y - 18,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = i == 0 ? const Color(0xFFD8EDFC) : const Color(0xFFC8E4F8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InterestSeaWavePainter oldDelegate) => false;
}

class _InterestHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _InterestHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: _interestPrimaryDark,
            iconSize: 18,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.86),
              fixedSize: const Size(38, 38),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Choose interests",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NotoSansThai',
                color: _interestInk,
                fontSize: 25,
                height: 1.3,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestContentPanel extends StatelessWidget {
  final Widget child;

  const _InterestContentPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _interestPrimary.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: -3,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.72),
            blurRadius: 3,
            spreadRadius: -1,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InterestSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? trailing;

  const _InterestSectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: _interestPrimaryDark,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: _interestInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _interestPrimary, width: 1.15),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: _interestInk,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InterestSelectionSummary extends StatelessWidget {
  final int count;
  final VoidCallback onClear;

  const _InterestSelectionSummary({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _interestPanelTint.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: _interestPrimary,
                    size: 17,
                  ),
                ),
                TextSpan(
                  text: count > 0 ? '  $count selected' : '  Nothing selected',
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              color: _interestInk,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton.icon(
            onPressed: count > 0 ? onClear : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 15),
            label: const Text('Clear all'),
            style: TextButton.styleFrom(
              foregroundColor: _interestPrimaryDark,
              textStyle: const TextStyle(
                fontFamily: 'NotoSansThai',
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestOptionGrid extends StatelessWidget {
  final List<String> values;
  final List<String> selectedValues;
  final IconData Function(String value) iconForValue;
  final void Function(String value, bool selected) onChanged;

  const _InterestOptionGrid({
    required this.values,
    required this.selectedValues,
    required this.iconForValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = ((constraints.maxWidth + gap) / 108).floor().clamp(
          2,
          5,
        );
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        var labelHeight = 0.0;
        // Measure full labels with the actual accessibility text scale. Reserve
        // room for the icon, spacing, padding and the thicker selected border.
        for (final label in values) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: _optionLabelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: math.max(1, tileWidth - 14));
          labelHeight = math.max(labelHeight, painter.height);
          painter.dispose();
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: math.max(
              100,
              41 + 6 + 14 + 4 + labelHeight.ceilToDouble() + 4,
            ),
          ),
          itemBuilder: (context, index) {
            final value = values[index];
            final isSelected = selectedValues.contains(value);
            return _InterestOptionTile(
              label: value,
              icon: iconForValue(value),
              isSelected: isSelected,
              onTap: () => onChanged(value, !isSelected),
            );
          },
        );
      },
    );
  }
}

class _InterestOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _InterestOptionTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColorFor(label);
    final tileFill = _tileFillFor(label, isSelected);
    final iconBgColor = Color.lerp(
      Colors.white,
      accentColor,
      isSelected ? 0.24 : 0.14,
    )!;
    final iconColor = accentColor;

    return AnimatedScale(
      scale: isSelected ? 1.025 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            decoration: BoxDecoration(
              color: tileFill,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : _interestLine.withValues(alpha: 0.65),
                width: isSelected ? 1.9 : 1.35,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(
                    alpha: isSelected ? 0.12 : 0.04,
                  ),
                  blurRadius: isSelected ? 11 : 7,
                  spreadRadius: -1.5,
                  offset: Offset(0, isSelected ? 5 : 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 41,
                        height: 41,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 23,
                          weight: 700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: _optionLabelStyle.copyWith(
                          color: _interestInk,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: isSelected
                        ? Container(
                            key: ValueKey('selected'),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          )
                        : Container(
                            key: ValueKey('unselected'),
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _interestLine,
                                width: 1.15,
                              ),
                            ),
                          ),
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

Color _tileFillFor(String label, bool isSelected) {
  final accent = _accentColorFor(label);
  final amount = isSelected ? 0.12 : 0.015;
  return Color.lerp(Colors.white, accent, amount)!;
}

Color _accentColorFor(String label) {
  if (label.contains("Nature")) {
    return const Color(0xFF32A9DB);
  }
  if (label.contains("Mountains") ||
      label.contains("Hiking") ||
      label.contains("Parks")) {
    return const Color(0xFF50A985);
  }
  if (label.contains("Islands")) {
    return const Color(0xFF36ABB8);
  }
  if (label.contains("Waterfalls") ||
      label.contains("Rivers") ||
      label.contains("Lakes") ||
      label.contains("Coast") ||
      label.contains("Beaches") ||
      label.contains("Island") ||
      label.contains("Swimming")) {
    return const Color(0xFF36ABB8);
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
    return const Color(0xFF947AD5);
  }
  if (label.contains("Markets") || label.contains("Shop")) {
    return const Color(0xFFDA739E);
  }
  if (label.contains("Cafes") || label.contains("Food")) {
    return const Color(0xFFD3A04A);
  }
  if (label.contains("Relaxation") ||
      label.contains("Spas") ||
      label.contains("Wellness")) {
    return const Color(0xFF54BFA9);
  }
  if (label.contains("Photography")) {
    return const Color(0xFFDA739E);
  }
  if (label.contains("Activities") || label.contains("Theme parks")) {
    return const Color(0xFF947AD5);
  }
  if (label.contains("Zoos") ||
      label.contains("Farms") ||
      label.contains("Gardens")) {
    return const Color(0xFF72A94B);
  }
  if (label.contains("Communities")) {
    return const Color(0xFF608DCA);
  }
  if (label.contains("Hot springs")) {
    return const Color(0xFFD47A52);
  }
  return const Color(0xFF4A8FBD);
}

class _InterestNextButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _InterestNextButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FractionallySizedBox(
        alignment: Alignment.center,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onPressed == null
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF518FD5), Color(0xFF70C4E7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: onPressed == null
                ? Colors.white.withValues(alpha: 0.80)
                : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (onPressed != null)
                BoxShadow(
                  color: const Color(0xFF609ED5).withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
            ],
          ),
          child: SizedBox(
            height: math.max(
              52,
              MediaQuery.textScalerOf(context).scale(16) * 2.6 + 24,
            ),
            child: FilledButton(
              onPressed: isLoading ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: _interestMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'NotoSansThai',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(label, textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 22),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
