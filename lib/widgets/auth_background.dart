import 'package:flutter/material.dart';

import 'app_chrome.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppPastelBackground(child: child);
  }
}
