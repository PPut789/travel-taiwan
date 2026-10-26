import 'package:flutter/material.dart';

class TravelBrand extends StatelessWidget {
  const TravelBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.landscape_outlined, size: 64, color: Color(0xFF3785BB)),
          SizedBox(height: 8),
          Text(
            'Tour Travel',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF19456B),
            ),
          ),
        ],
      ),
    );
  }
}
