import 'package:flutter/material.dart';

import '../widgets/selection_background.dart';

const _aboutInk = Color(0xFF19456B);
const _aboutMuted = Color(0xFF557FA2);

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'NotoSansThai',
        bodyColor: _aboutInk,
        displayColor: _aboutInk,
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      body: Stack(
        children: [
          const Positioned.fill(child: SelectionBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: _aboutInk,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'About',
                          style: TextStyle(
                            fontFamily: 'NotoSansThai',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _aboutInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.topCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: constraints.maxWidth.clamp(360.0, 560.0),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFE1EFF8),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _aboutInk.withValues(alpha: .06),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _AboutLogo(),
                                  SizedBox(height: 16),
                                  Divider(height: 24, color: Color(0xFFE1EFF8)),
                                  _AboutTextSection(
                                    icon: Icons.travel_explore_rounded,
                                    title: 'Project name',
                                    body:
                                        'Personalized tourist attraction recommendations for Taiwan',
                                  ),
                                  Divider(height: 24, color: Color(0xFFE1EFF8)),
                                  _AboutTextSection(
                                    icon: Icons.location_on_outlined,
                                    title: 'Attraction information',
                                    body:
                                        'Discover attractions across Taiwan. Attraction coverage will follow the selected Taiwan dataset.',
                                  ),
                                  Divider(height: 24, color: Color(0xFFE1EFF8)),
                                  _AboutTextSection(
                                    icon: Icons.auto_awesome_outlined,
                                    title: 'Personalized recommendations',
                                    body:
                                        'Recommendations use your selected interests and viewing history.\n\nThe Taiwan dataset, trained model and cloud services will be connected separately.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AboutLogo extends StatelessWidget {
  const _AboutLogo();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF518FD5), Color(0xFF70C4E7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Text(
          'TT',
          style: TextStyle(
            fontFamily: 'NotoSansThai',
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 16),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tour Travel',
              style: TextStyle(
                fontFamily: 'NotoSansThai',
                fontSize: 25,
                fontWeight: FontWeight.w600,
                color: _aboutInk,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontFamily: 'NotoSansThai',
                fontSize: 14,
                color: _aboutMuted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AboutTextSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AboutTextSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE7F4FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: const Color(0xFF3785BB)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoSansThai',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _aboutInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(
            fontFamily: 'NotoSansThai',
            color: _aboutMuted,
            height: 1.7,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}
