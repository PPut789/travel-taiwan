import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../data/user_repository.dart';
import '../data/favorites_repository.dart';
import '../data/history_repository.dart';
import '../data/place_repository.dart';
import '../models/place_model.dart';
import '../widgets/selection_background.dart';
import '../widgets/travel_bottom_nav.dart';
import 'detail_page.dart';
import 'favorites_page.dart';
import '../utils/app_routes.dart';
import 'about_app_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'location_page.dart';
import 'my_videos_page.dart';
import 'settings_page.dart';
import 'start_page.dart';
import 'upload_video_page.dart';

const _profileBg = Color(0xFFEAF7FF);
const _profilePrimary = Color(0xFF76ADD1);
const _profilePrimaryDark = Color(0xFF19456B);
const _profileMuted = Color(0xFF557FA2);
const _profileLine = Color(0xFFE4EDF3);
const _profileDanger = Color(0xFFD66D6D);
const _profileIconBg = Color(0xFFEFF6FA);

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBack;

  const ProfilePage({super.key, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  bool isUploadingPhoto = false;
  bool isSigningOut = false;
  String? localPhotoUrl;
  late Future<String> profilePhotoFuture;

  @override
  void initState() {
    super.initState();
    profilePhotoFuture = UserRepository.loadProfilePhotoUrl();
  }

  Future<void> _changeProfilePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 86,
    );
    if (image == null) return;

    setState(() {
      isUploadingPhoto = true;
    });

    try {
      final photoUrl = await UserRepository.updateProfilePhoto(image);
      if (!mounted) return;
      setState(() {
        localPhotoUrl = photoUrl;
        profilePhotoFuture = Future.value(photoUrl);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot update profile photo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (isSigningOut) return;
    setState(() {
      isSigningOut = true;
    });

    UserRepository.clearCachedSettings();
    try {
      await FirebaseAuth.instance.signOut();

      try {
        await GoogleSignIn.instance.signOut().timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {
        // Firebase sign-out is the source of truth for app navigation.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isSigningOut = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
      return;
    }
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushAndRemoveUntil(smoothRoute(const StartPage()), (route) => false);
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _openHomeTab(int tabIndex) async {
    final preferences = await UserRepository.loadPreferences();
    if (!mounted) return;

    if (preferences == null) {
      Navigator.pushReplacement(context, smoothRoute(const LocationPage()));
      return;
    }

    Navigator.pushReplacement(
      context,
      smoothRoute(
        HomePage(preferences: preferences, initialTabIndex: tabIndex),
      ),
    );
  }

  Future<void> _openPreferences() async {
    final preferences = await UserRepository.loadPreferences();
    if (!mounted) return;
    await Navigator.push(
      context,
      smoothRoute(LocationPage(initialPreferences: preferences)),
    );
  }

  Future<void> _openPlace(Place place) async {
    Navigator.push(context, smoothRoute(DetailPage(place: place)));
    try {
      final settings = await UserRepository.loadAppSettings(
        refresh: true,
      ).timeout(const Duration(seconds: 3));
      if (settings.saveViewingHistory) {
        await HistoryRepository.addViewedPlace(
          place,
        ).timeout(const Duration(seconds: 3));
      }
    } catch (error) {
      debugPrint('Viewing history was not saved: $error');
    }
  }

  Future<void> _openFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to view favorites')),
      );
      return;
    }
    final repository = FavoritesRepository(
      firestore: FirebaseFirestore.instance,
      uid: uid,
    );
    await Navigator.push(
      context,
      smoothRoute(
        FavoritesPage(
          favorites: repository.watch(),
          onFavoriteChanged: repository.setFavorite,
          onOpenPlace: (saved) async {
            try {
              Place? place;
              if (saved.documentId.isNotEmpty) {
                place = await PlaceRepository.loadPlaceByDocumentId(
                  saved.documentId,
                );
              } else {
                for (final candidate in await PlaceRepository.loadPlaces()) {
                  if (saved.id.isNotEmpty
                      ? candidate.id == saved.id
                      : candidate.name == saved.name &&
                            candidate.province == saved.province) {
                    place = candidate;
                    break;
                  }
                }
              }
              if (!mounted) return;
              if (place == null) throw StateError('unavailable');
              await _openPlace(place);
            } catch (_) {
              _showUnavailable();
            }
          },
        ),
      ),
    );
  }

  void _showUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this item. Check your connection.'),
      ),
    );
  }

  void _handleMenu(ProfileAction action) {
    switch (action) {
      case ProfileAction.favorites:
        _openFavorites();
      case ProfileAction.preferences:
        _openPreferences();
      case ProfileAction.history:
        Navigator.push(context, smoothRoute(const HistoryPage()));
      case ProfileAction.videos:
        Navigator.push(context, smoothRoute(const MyVideosPage()));
      case ProfileAction.about:
        Navigator.push(context, smoothRoute(const AboutAppPage()));
      case ProfileAction.settings:
        Navigator.push(context, smoothRoute(const SettingsPage()));
      case ProfileAction.logout:
        _signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ProfileDashboard(
      onBack: _goBack,
      displayName: user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : 'Traveler',
      email: user?.email ?? 'No email',
      profilePhotoFuture: profilePhotoFuture,
      fallbackPhotoUrl: localPhotoUrl ?? user?.photoURL,
      isUploadingPhoto: isUploadingPhoto,
      isSigningOut: isSigningOut,
      onChangePhoto: isUploadingPhoto ? null : _changeProfilePhoto,
      onMenuSelected: _handleMenu,
      onNavigation: (index) {
        if (index == 0 || index == 3) {
          _openHomeTab(index);
        } else if (index == 1) {
          _openFavorites();
        } else if (index == 2) {
          Navigator.push(context, smoothRoute(const UploadVideoPage()));
        }
      },
    );
  }
}

enum ProfileAction {
  favorites,
  preferences,
  history,
  videos,
  about,
  settings,
  logout,
}

class ProfileDashboard extends StatelessWidget {
  final String displayName;
  final String email;
  final Future<String> profilePhotoFuture;
  final String? fallbackPhotoUrl;
  final bool isUploadingPhoto;
  final bool isSigningOut;
  final VoidCallback? onChangePhoto;
  final ValueChanged<ProfileAction> onMenuSelected;
  final ValueChanged<int> onNavigation;
  final VoidCallback onBack;

  const ProfileDashboard({
    super.key,
    required this.displayName,
    required this.email,
    required this.profilePhotoFuture,
    this.fallbackPhotoUrl,
    this.isUploadingPhoto = false,
    this.isSigningOut = false,
    required this.onChangePhoto,
    required this.onMenuSelected,
    required this.onNavigation,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(
        context,
      ).textTheme.apply(fontFamily: 'NotoSansThai', fontSizeDelta: 2),
    ),
    child: Scaffold(
      backgroundColor: _profileBg,
      bottomNavigationBar: TravelBottomNav(
        selectedIndex: 4,
        onSelected: onNavigation,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SelectionBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: _profilePrimaryDark,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'My profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NotoSansThai',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _profilePrimaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const compact = true;
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final minHeight =
                          920 + (textScale - 1).clamp(0.0, 2.0) * 300;
                      final height = constraints.maxHeight < minHeight
                          ? minHeight
                          : constraints.maxHeight;
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: constraints.maxWidth.clamp(500.0, 600.0),
                            height: height,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String>(
                                    future: profilePhotoFuture,
                                    builder: (context, snapshot) =>
                                        _ProfileHeader(
                                          photoUrl:
                                              snapshot.data
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? snapshot.data
                                              : fallbackPhotoUrl,
                                          displayName: displayName,
                                          email: email,
                                          isUploadingPhoto: isUploadingPhoto,
                                          isCompact: compact,
                                          onChangePhoto: onChangePhoto,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'My account',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansThai',
                                      color: _profilePrimaryDark,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _ProfileMenuGroup(
                                    isCompact: compact,
                                    children: [
                                      _ProfileMenuTile(
                                        icon: Icons.favorite_rounded,
                                        title: 'Favorites',
                                        iconColor: const Color(0xFFE86989),
                                        isCompact: compact,
                                        onTap: () => onMenuSelected(
                                          ProfileAction.favorites,
                                        ),
                                      ),
                                      _ProfileMenuTile(
                                        icon: Icons.explore_outlined,
                                        title: 'Destinations and interests',
                                        iconColor: const Color(0xFF3785BB),
                                        isCompact: compact,
                                        onTap: () => onMenuSelected(
                                          ProfileAction.preferences,
                                        ),
                                      ),
                                      _ProfileMenuTile(
                                        icon: Icons.history_rounded,
                                        title: 'Viewing history',
                                        iconColor: const Color(0xFF5B93AF),
                                        isCompact: compact,
                                        onTap: () => onMenuSelected(
                                          ProfileAction.history,
                                        ),
                                      ),
                                      _ProfileMenuTile(
                                        icon: Icons.videocam_outlined,
                                        title: 'My videos',
                                        iconColor: const Color(0xFF69A8A4),
                                        isCompact: compact,
                                        onTap: () => onMenuSelected(
                                          ProfileAction.videos,
                                        ),
                                      ),
                                      _ProfileMenuTile(
                                        icon: Icons.info_outline_rounded,
                                        title: 'About',
                                        iconColor: const Color(0xFF8D80B8),
                                        isCompact: compact,
                                        onTap: () =>
                                            onMenuSelected(ProfileAction.about),
                                      ),
                                      _ProfileMenuTile(
                                        icon: Icons.settings_outlined,
                                        title: 'Settings',
                                        iconColor: const Color(0xFFB49A56),
                                        isCompact: compact,
                                        onTap: () => onMenuSelected(
                                          ProfileAction.settings,
                                        ),
                                      ),
                                      _ProfileMenuTile(
                                        icon: Icons.logout_rounded,
                                        title: isSigningOut
                                            ? 'Signing out...'
                                            : 'Sign out',
                                        iconColor: _profileDanger,
                                        isCompact: compact,
                                        isDestructive: true,
                                        onTap: () {
                                          if (!isSigningOut) {
                                            onMenuSelected(
                                              ProfileAction.logout,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

class _ProfileHeader extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final String email;
  final bool isUploadingPhoto;
  final bool isCompact;
  final VoidCallback? onChangePhoto;

  const _ProfileHeader({
    required this.photoUrl,
    required this.displayName,
    required this.email,
    required this.isUploadingPhoto,
    required this.isCompact,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        isCompact ? 34 : 44,
        18,
        isCompact ? 36 : 42,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: _profilePrimaryDark.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _EditableProfileAvatar(
            photoUrl: photoUrl,
            isUploading: isUploadingPhoto,
            isCompact: isCompact,
            onTap: onChangePhoto,
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              color: _profilePrimaryDark,
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 15.5,
              color: _profileMuted,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onChangePhoto,
            icon: Icon(
              isUploadingPhoto ? Icons.hourglass_top_rounded : Icons.edit,
              size: 20,
            ),
            label: Text(isUploadingPhoto ? 'Uploading...' : 'Edit profile'),
            style: FilledButton.styleFrom(
              foregroundColor: _profilePrimaryDark,
              backgroundColor: const Color(0xFFE2F1FB),
              minimumSize: const Size(230, 54),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              textStyle: const TextStyle(
                fontFamily: 'NotoSansThai',
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final bool isUploading;
  final bool isCompact;
  final VoidCallback? onTap;

  const _EditableProfileAvatar({
    required this.photoUrl,
    required this.isUploading,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoUrl?.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: CircleAvatar(
            radius: isCompact ? 32 : 48,
            backgroundColor: _profileIconBg,
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? Icon(
                    Icons.person_outline,
                    color: _profilePrimaryDark,
                    size: isCompact ? 31 : 46,
                  )
                : null,
          ),
        ),
        Positioned(
          right: -2,
          bottom: 4,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 30,
                height: 30,
                child: isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.photo_camera_outlined,
                        color: _profilePrimary,
                        size: 17,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  final bool isCompact;
  final List<_ProfileMenuTile> children;

  const _ProfileMenuGroup({required this.isCompact, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: _profilePrimaryDark.withValues(alpha: 0.08),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                endIndent: 24,
                color: _profileLine,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final bool isCompact;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
    this.isCompact = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: isCompact ? 74 : 87,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: isCompact ? 40 : 48,
                  height: isCompact ? 40 : 48,
                  decoration: const BoxDecoration(
                    color: _profileIconBg,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: isCompact ? 22 : 25,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NotoSansThai',
                      color: isDestructive
                          ? _profileDanger
                          : _profilePrimaryDark,
                      fontSize: isCompact ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive
                      ? _profileDanger
                      : _profileMuted.withValues(alpha: 0.62),
                  size: isCompact ? 23 : 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
