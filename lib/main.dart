import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/user_repository.dart';
import 'firebase_options.dart';
import 'models/recommendation_preferences.dart';
import 'pages/home_page.dart';
import 'pages/demographics_page.dart';
import 'pages/location_page.dart';
import 'pages/start_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x66000000),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tour Travel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        platform: TargetPlatform.android,
        fontFamily: 'Kanit',
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7EC8E3),
          primary: const Color(0xFF7EC8E3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FCFF),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF8FCFF),
          foregroundColor: Colors.black,
          titleTextStyle: TextStyle(
            fontFamily: 'Kanit',
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFFF3C4),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              color: isSelected ? const Color(0xFF7EC8E3) : Colors.black54,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: isSelected ? const Color(0xFF7EC8E3) : Colors.black54,
            );
          }),
        ),
        useMaterial3: true,
      ),
      scrollBehavior: const _AppScrollBehavior(),
      home: DefaultFirebaseOptions.isConfigured
          ? const _AuthGate()
          : const StartPage(),
    );
  }
}

// Keep scrolling physics consistent without changing the actual host platform.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.android;
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserRepository.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const StartPage();
        }

        return FutureBuilder<RecommendationPreferences?>(
          future: UserRepository.loadPreferences(),
          builder: (context, preferencesSnapshot) {
            if (preferencesSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final preferences = preferencesSnapshot.data;
            if (preferences == null) {
              return const LocationPage();
            }

            if (!preferences.hasDemographics) {
              return DemographicsPage(
                selectedProvinces: preferences.provinces,
                initialPreferences: preferences,
              );
            }

            return HomePage(preferences: preferences);
          },
        );
      },
    );
  }
}
