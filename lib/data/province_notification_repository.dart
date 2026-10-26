import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/province_notification.dart';
import 'province_notification_tracker.dart';

/// In-app monitoring. Checkpoints also detect changes made while the app was closed
/// when the client next connects. User-owned state uses the existing users rule.
class ProvinceNotificationRepository {
  final FirebaseFirestore firestore;
  final String uid;

  ProvinceNotificationRepository({required this.firestore, required this.uid});

  DocumentReference<Map<String, dynamic>> get _user =>
      firestore.collection('users').doc(uid);

  Stream<List<ProvinceNotification>> watch() {
    late StreamController<List<ProvinceNotification>> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userListener;
    final listeners =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final active = <String, String>{};
    Future<void> sourceQueue = Future<void>.value();
    var closed = false;
    Future<void> userQueue = Future<void>.value();

    void report(Object error, StackTrace stack) {
      if (!closed) controller.addError(error, stack);
    }

    Future<void> handleUser(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) async {
      if (closed) return;
      if (!snapshot.exists) {
        controller.add(const []);
        return;
      }
      final data = snapshot.data()!;
      final preferences = ProvinceNotificationTracker.map(data['preferences']);
      final provinces = List<String>.from(
        preferences['provinces'] as List? ?? [],
      );
      final original = ProvinceNotificationTracker.map(data['provinceUpdates']);
      final state = ProvinceNotificationTracker.reconcile(
        original,
        provinces,
        DateTime.now(),
      );
      if (!ProvinceNotificationTracker.sameState(original, state)) {
        // Reconcile inside the transaction too, so a concurrent preference save wins.
        await firestore.runTransaction((transaction) async {
          final latest = (await transaction.get(_user)).data() ?? {};
          final selected = ProvinceNotificationTracker.map(
            latest['preferences'],
          );
          transaction.update(_user, {
            'provinceUpdates': ProvinceNotificationTracker.reconcile(
              latest['provinceUpdates'],
              List<String>.from(selected['provinces'] as List? ?? []),
              DateTime.now(),
            ),
          });
        });
        return;
      }
      if (closed) return;
      controller.add(
        ProvinceNotificationTracker.visibleItems(state, provinces),
      );
      final subscriptions = ProvinceNotificationTracker.map(
        state['subscriptions'],
      );
      final desired = <String, String>{};
      for (final entry in subscriptions.entries) {
        for (final source in ['attractions', 'videos']) {
          final key = '$source:${entry.key}';
          final generation = entry.value as String;
          desired[key] = generation;
          if (active[key] == generation) continue;
          await listeners.remove(key)?.cancel();
          if (closed) return;
          active[key] = generation;
          listeners[key] = firestore
              .collection(source)
              .where('province', isEqualTo: entry.key)
              .snapshots(includeMetadataChanges: true)
              .listen((snapshot) {
                if (snapshot.metadata.isFromCache ||
                    snapshot.metadata.hasPendingWrites) {
                  return;
                }
                // Serialize source transactions to avoid contention on the user
                // document and preserve snapshot order during initial monitoring.
                final previous = sourceQueue;
                final next = previous
                    .then((_) async {
                      if (closed || active[key] != generation) return;
                      final records = snapshot.docs
                          .where(
                            (doc) =>
                                source != 'videos' ||
                                (doc.data()['status'] ?? 'published') ==
                                    'published',
                          )
                          .map((doc) {
                            final data = doc.data();
                            final timestamp =
                                data['updatedAt'] ?? data['createdAt'];
                            final keys = source == 'videos'
                                ? [
                                    'videoUrl',
                                    'caption',
                                    'attractionId',
                                    'attractionSourceId',
                                    'attractionName',
                                    'province',
                                    'region',
                                    'googleMapsUrl',
                                    'status',
                                  ]
                                : [
                                    'nameTh',
                                    'nameEn',
                                    'province',
                                    'region',
                                    'description',
                                    'category',
                                    'type',
                                    'activity',
                                    'location',
                                    'latitude',
                                    'longitude',
                                    'youtubeUrl',
                                    'youtubeUrls',
                                    'tiktokUrls',
                                    'videoUrls',
                                    'images',
                                    'assetImages',
                                    'tags',
                                  ];
                            return ProvinceUpdateRecord(
                              id: doc.id,
                              province: entry.key,
                              name:
                                  (data[source == 'videos'
                                          ? 'attractionName'
                                          : 'nameTh']
                                      as String?) ??
                                  entry.key,
                              createdAt: data['createdAt'] is Timestamp
                                  ? (data['createdAt'] as Timestamp).toDate()
                                  : null,
                              updatedAt: timestamp is Timestamp
                                  ? timestamp.toDate()
                                  : null,
                              content: {for (final key in keys) key: data[key]},
                            );
                          })
                          .toList();
                      await firestore.runTransaction((transaction) async {
                        final user =
                            (await transaction.get(_user)).data() ?? {};
                        final current = ProvinceNotificationTracker.map(
                          user['provinceUpdates'],
                        );
                        if (ProvinceNotificationTracker.map(
                              current['subscriptions'],
                            )[entry.key] !=
                            generation) {
                          return;
                        }
                        final next = ProvinceNotificationTracker.applySnapshot(
                          state: current,
                          source: source,
                          province: entry.key,
                          generation: generation,
                          records: records,
                          now: DateTime.now(),
                        );
                        if (!ProvinceNotificationTracker.sameState(
                          current,
                          next,
                        )) {
                          transaction.update(_user, {'provinceUpdates': next});
                        }
                      });
                    })
                    .catchError((Object error, StackTrace stack) {
                      report(error, stack);
                    });
                sourceQueue = next;
              }, onError: (Object error, StackTrace stack) => report(error, stack));
        }
      }
      for (final key in active.keys.toList()) {
        if (desired[key] == active[key]) continue;
        active.remove(key);
        await listeners.remove(key)?.cancel();
      }
    }

    controller = StreamController<List<ProvinceNotification>>.broadcast(
      onListen: () {
        closed = false;
        userListener = _user.snapshots().listen((snapshot) {
          userQueue = userQueue.then((_) => handleUser(snapshot)).catchError((
            Object error,
            StackTrace stack,
          ) {
            report(error, stack);
          });
        }, onError: (Object error, StackTrace stack) => report(error, stack));
      },
      onCancel: () async {
        closed = true;
        await userListener?.cancel();
        active.clear();
        for (final subscription in listeners.values) {
          await subscription.cancel();
        }
        listeners.clear();
      },
    );
    return controller.stream;
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await firestore.runTransaction((transaction) async {
      final data = (await transaction.get(_user)).data();
      if (data == null) return;
      transaction.update(_user, {
        'provinceUpdates': ProvinceNotificationTracker.markRead(
          data['provinceUpdates'],
          ids.toSet(),
        ),
      });
    });
  }
}
