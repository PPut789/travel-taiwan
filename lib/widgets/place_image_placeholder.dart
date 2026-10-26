import 'package:flutter/material.dart';

class PlaceImagePlaceholder extends StatelessWidget {
  final String placeName;
  final double width;
  final double height;

  const PlaceImagePlaceholder({
    super.key,
    required this.placeName,
    required this.width,
    required this.height,
  });

  static const _backgrounds = [
    Color(0xFFEDE3F0),
    Color(0xFFE3EEF0),
    Color(0xFFE8EDE2),
    Color(0xFFF1E8E2),
    Color(0xFFE7E5F1),
  ];

  @override
  Widget build(BuildContext context) {
    final colorIndex =
        placeName.codeUnits.fold<int>(0, (sum, value) {
          return sum + value;
        }) %
        _backgrounds.length;

    final isCompact = height < 100 || width < 100;

    return Container(
      width: width,
      height: height,
      color: _backgrounds[colorIndex],
      padding: EdgeInsets.all(isCompact ? 6 : 14),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 60) {
            return Icon(
              Icons.landscape_outlined,
              color: const Color(0xFF7EC8E3),
              size: constraints.maxHeight.clamp(0.0, 22.0),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.landscape_outlined,
                color: const Color(0xFF7EC8E3),
                size: isCompact ? 22 : 34,
              ),
              SizedBox(height: isCompact ? 3 : 8),
              Text(
                placeName,
                maxLines: isCompact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF2F5872),
                  fontSize: isCompact ? 8 : 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
