import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client configuration; access is controlled by Firebase Security Rules.
class DefaultFirebaseOptions {
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'travel---taiwan',
  );
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '1020915794188',
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'travel---taiwan.firebasestorage.app',
  );
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'travel---taiwan.firebaseapp.com',
  );

  static bool get isConfigured =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw UnsupportedError(
        'Firebase is configured for Web and Android only.',
      );
    }
    final defaults = kIsWeb ? web : android;
    return FirebaseOptions(
      projectId: projectId,
      apiKey: apiKey.isEmpty ? defaults.apiKey : apiKey,
      appId: appId.isEmpty ? defaults.appId : appId,
      messagingSenderId: messagingSenderId,
      storageBucket: storageBucket,
      authDomain: authDomain,
    );
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBeT8meW-lIOeEJD2CdjKUjjtxwsr1y_M8',
    appId: '1:1020915794188:web:82309fbd68f082f99c8929',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyC3cSBJV14j_BOihsbr1SVOOTXpSlh_jz0',
    appId: '1:1020915794188:android:bf7623e4eda437329c8929',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );
}
