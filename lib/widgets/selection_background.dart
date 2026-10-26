import 'package:flutter/material.dart';

class SelectionBackground extends StatelessWidget {
  const SelectionBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDF1FF), Color(0xFFF4FBFF)],
        ),
      ),
      child: CustomPaint(painter: _SeaWavePainter()),
    );
  }
}

class _SeaWavePainter extends CustomPainter {
  const _SeaWavePainter();

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
  bool shouldRepaint(covariant _SeaWavePainter oldDelegate) => false;
}
