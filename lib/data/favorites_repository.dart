import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/favorite_place.dart';
import '../models/place_model.dart';

class FavoritesRepository {
  final FirebaseFirestore firestore;
  final String uid;

  const FavoritesRepository({required this.firestore, required this.uid});

  DocumentReference<Map<String, dynamic>> get _user =>
      firestore.collection('users').doc(uid);

  Stream<List<FavoritePlace>> watch() => _user.snapshots().map(
    (snapshot) => FavoritePlace.decode(snapshot.data()?['favorites']),
  );

  Future<void> setFavorite(Place place, bool saved) async {
    await firestore.runTransaction((transaction) async {
      final data = (await transaction.get(_user)).data() ?? {};
      transaction.set(_user, {
        'favorites': FavoritePlace.update(
          data['favorites'],
          place,
          saved,
          DateTime.now().toUtc(),
        ),
      }, SetOptions(mergeFields: ['favorites']));
    });
  }
}
