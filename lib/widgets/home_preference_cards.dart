import 'package:flutter/material.dart';

import '../models/recommendation_preferences.dart';

class HomePreferenceCards extends StatelessWidget {
  final RecommendationPreferences preferences;
  final VoidCallback onSelectLocation;
  final VoidCallback onSelectInterests;

  const HomePreferenceCards({
    super.key,
    required this.preferences,
    required this.onSelectLocation,
    required this.onSelectInterests,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: _PreferenceCard(
              title: 'Choose destinations',
              backgroundAsset: 'assets/backgrounds/province_card_scenery.png',
              description: preferences.provinces.isEmpty
                  ? 'Choose cities and counties'
                  : '${preferences.provinces.length} selected',
              icon: Icons.location_on_rounded,
              tint: const Color(0xFFE7F4FF),
              accent: const Color(0xFF3785BB),
              onTap: onSelectLocation,
              destinations: preferences.provinces,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PreferenceCard(
              title: 'Choose interests',
              description: 'Update your preferences',
              icon: Icons.favorite_border_rounded,
              tint: const Color(0xFFF0EDFC),
              accent: const Color(0xFF8070BF),
              onTap: onSelectInterests,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;
  final List<String>? destinations;
  final String? backgroundAsset;

  const _PreferenceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
    this.destinations,
    this.backgroundAsset,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (backgroundAsset != null)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      backgroundAsset!,
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomRight,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 21, color: accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansThai',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF19456B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansThai',
                                  fontSize: 11,
                                  height: 1.4,
                                  color: Color(0xFF58758F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (destinations != null)
                      Row(
                        children: destinations!
                            .take(2)
                            .map(
                              (destination) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: accent.withValues(alpha: .22),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                        horizontal: 3,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          destination,
                                          style: TextStyle(
                                            fontFamily: 'NotoSansThai',
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _MiniInterest(
                            icon: Icons.landscape_outlined,
                            label: 'Nature',
                            color: Color(0xFF398D80),
                          ),
                          _MiniInterest(
                            icon: Icons.temple_buddhist_outlined,
                            label: 'Culture',
                            color: Color(0xFF9273C5),
                          ),
                          _MiniInterest(
                            icon: Icons.local_activity_outlined,
                            label: 'Activities',
                            color: Color(0xFFC58C40),
                          ),
                          _MiniInterest(
                            icon: Icons.waves_rounded,
                            label: 'Coast',
                            color: Color(0xFF4E93CD),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInterest extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniInterest({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 14),
    ),
  );
}
