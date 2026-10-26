import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/destination_photos.dart';
import '../data/taiwan_geography.dart';
import '../models/recommendation_preferences.dart';
import '../utils/app_routes.dart';
import '../widgets/destination_card.dart';
import '../widgets/selection_background.dart';
import 'demographics_page.dart';

const _destinationInk = Color(0xFF133A51);
const _destinationBlue = Color(0xFF09AEE3);

class LocationPage extends StatefulWidget {
  final RecommendationPreferences? initialPreferences;
  const LocationPage({super.key, this.initialPreferences});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final selectedProvinces = <String>{};

  @override
  void initState() {
    super.initState();
    selectedProvinces.addAll(
      widget.initialPreferences?.provinces.where(taiwanCities.contains) ?? [],
    );
  }

  void _continue() {
    Navigator.push(
      context,
      smoothRoute(
        DemographicsPage(
          selectedProvinces: selectedProvinces.toList(),
          initialPreferences: widget.initialPreferences,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5F5FF),
        foregroundColor: _destinationInk,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 84,
        title: const Text(
          'Choose your destination',
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SelectionBackground()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cities and counties',
                        style: TextStyle(
                          color: _destinationInk,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select cities, or continue to explore all of Taiwan.',
                        style: TextStyle(color: Color(0xFF557FA2)),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 664
                              ? 2
                              : constraints.maxWidth < 984
                              ? 3
                              : 4;
                          const gap = 14.0;
                          final width =
                              (constraints.maxWidth - (columns - 1) * gap) /
                              columns;
                          var labelHeight = 0.0;
                          for (final city in taiwanCities) {
                            final painter = TextPainter(
                              text: TextSpan(
                                text: city,
                                style: destinationCardLabelStyle,
                              ),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: math.max(1, width - 28));
                            labelHeight = math.max(labelHeight, painter.height);
                            painter.dispose();
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: taiwanCities.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  mainAxisExtent: math.max(
                                    112,
                                    width * .35 + labelHeight + 28,
                                  ),
                                ),
                            itemBuilder: (context, index) {
                              final city = taiwanCities[index];
                              return DestinationCard(
                                key: ValueKey('destination-$city'),
                                city: city,
                                imageAsset: destinationPhotos[city]!,
                                selected: selectedProvinces.contains(city),
                                onTap: () => setState(() {
                                  if (!selectedProvinces.add(city)) {
                                    selectedProvinces.remove(city);
                                  }
                                }),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: _destinationBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCEE8F2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 17,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
