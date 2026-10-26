import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_settings.dart';
import 'province_notification_tracker.dart';
import '../models/recommendation_preferences.dart';

class UserRepository {
  static AppSettings? _cachedSettings;
  static String? _settingsUserId;

  static Stream<User?> authStateChanges() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } on FirebaseException catch (error) {
      if (error.code == 'no-app') return Stream.value(null);
      rethrow;
    }
  }

  static DocumentReference<Map<String, dynamic>>? _userDocument() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<RecommendationPreferences?> loadPreferences() async {
    final document = _userDocument();
    if (document == null) return null;

    try {
      final snapshot = await document.get();
      final data = snapshot.data();
      final preferencesData = data?['preferences'];

      if (preferencesData is! Map) return null;

      final preferences = RecommendationPreferences.fromJson({
        if (data?['age'] != null) 'age': data!['age'],
        if (data?['gender'] != null) 'gender': data!['gender'],
        ...Map<String, dynamic>.from(preferencesData),
      });

      return preferences.isComplete ? preferences : null;
    } on FirebaseException {
      return null;
    }
  }

  static Future<void> savePreferences(
    RecommendationPreferences preferences,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final document = _userDocument();
    if (user == null || document == null) return;

    final now = DateTime.now();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = (await transaction.get(document)).data() ?? {};
      transaction.set(
        document,
        {
          'displayName': user.displayName,
          'email': user.email,
          'preferences': preferences.toJson(),
          if (preferences.hasDemographics) 'age': preferences.age,
          if (preferences.hasDemographics) 'gender': preferences.gender,
          'preferencesUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'provinceUpdates': ProvinceNotificationTracker.reconcile(
            existing['provinceUpdates'],
            preferences.provinces,
            now,
          ),
        },
        SetOptions(
          mergeFields: [
            'displayName',
            'email',
            'preferences',
            if (preferences.hasDemographics) 'age',
            if (preferences.hasDemographics) 'gender',
            'preferencesUpdatedAt',
            'updatedAt',
            'provinceUpdates',
          ],
        ),
      );
    });
  }

  static Future<void> ensureUserProfile(User? user) async {
    if (user == null) return;

    final document = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snapshot = await document.get();
    final data = snapshot.data();

    final existingUsername = (data?['username'] as String?)?.trim();
    final existingDisplayName = (data?['displayName'] as String?)?.trim();
    final existingPhotoUrl = (data?['photoUrl'] as String?)?.trim();
    final displayName = user.displayName?.trim();
    final email = user.email?.trim();
    final fallbackUsername = email?.split('@').first.trim();

    await document.set({
      'uid': user.uid,
      'username': existingUsername?.isNotEmpty == true
          ? existingUsername
          : (displayName?.isNotEmpty == true ? displayName : fallbackUsername),
      'displayName': existingDisplayName?.isNotEmpty == true
          ? existingDisplayName
          : displayName,
      'email': email,
      'photoUrl': existingPhotoUrl?.isNotEmpty == true
          ? existingPhotoUrl
          : user.photoURL,
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<AppSettings> loadAppSettings({bool refresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!refresh && _cachedSettings != null && _settingsUserId == uid) {
      return _cachedSettings!;
    }

    final document = _userDocument();
    if (document == null) return const AppSettings();

    try {
      final snapshot = await document.get();
      final settingsData = snapshot.data()?['settings'];
      if (settingsData is Map) {
        _cachedSettings = AppSettings.fromJson(
          Map<String, dynamic>.from(settingsData),
        );
      } else {
        _cachedSettings = const AppSettings();
      }
      _settingsUserId = uid;
    } on FirebaseException {
      _cachedSettings = const AppSettings();
      _settingsUserId = uid;
    }

    return _cachedSettings!;
  }

  static Future<void> saveAppSettings(AppSettings settings) async {
    final document = _userDocument();
    if (document == null) return;

    _cachedSettings = settings;
    _settingsUserId = FirebaseAuth.instance.currentUser?.uid;
    await document.set({
      'settings': settings.toJson(),
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> resetAppSettings() async {
    await saveAppSettings(const AppSettings());
  }

  static Future<String> loadProfilePhotoUrl() async {
    final authPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL?.trim();
    if (authPhotoUrl != null && authPhotoUrl.isNotEmpty) return authPhotoUrl;

    final document = _userDocument();
    if (document == null) return '';

    try {
      final snapshot = await document.get();
      return (snapshot.data()?['photoUrl'] as String? ?? '').trim();
    } on FirebaseException {
      return '';
    }
  }

  static void clearCachedSettings() {
    _cachedSettings = null;
    _settingsUserId = null;
  }

  static Future<String> updateProfilePhoto(XFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    final document = _userDocument();
    if (user == null || document == null) {
      throw Exception('Please sign in before updating your profile photo.');
    }

    final bytes = await file.readAsBytes();
    final ref = FirebaseStorage.instance.ref(
      'profile_images/${user.uid}/avatar.jpg',
    );
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'),
    );
    final photoUrl = await task.ref.getDownloadURL();

    await user.updatePhotoURL(photoUrl);
    await user.reload();
    await document.set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return photoUrl;
  }
}
