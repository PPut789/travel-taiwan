import 'package:flutter/material.dart';

const destinationCardLabelStyle = TextStyle(
  fontFamily: 'NotoSansThai',
  fontSize: 14,
  height: 1.2,
  fontWeight: FontWeight.w700,
  color: Colors.white,
  shadows: [
    Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
  ],
);

class DestinationCard extends StatelessWidget {
  final String city;
  final String imageAsset;
  final bool selected;
  final VoidCallback onTap;

  const DestinationCard({
    super.key,
    required this.city,
    required this.imageAsset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF05B6EB);
    return Semantics(
      label: city,
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? blue.withValues(alpha: .30)
                  : const Color(0x1A124766),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          color: const Color(0xFFAAD6E6),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  cacheWidth: 640,
                  errorBuilder: (context, error, stack) => const ColoredBox(
                    color: Color(0xFF427F98),
                    child: Center(
                      child: Icon(
                        Icons.landscape_outlined,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x000F3040),
                        Color(0x200F3040),
                        Color(0xE60F3040),
                      ],
                      stops: [0, .4, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: ExcludeSemantics(
                    child: Text(city, style: destinationCardLabelStyle),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: blue,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? blue
                            : Colors.white.withValues(alpha: .6),
                        width: selected ? 3 : 1,
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
