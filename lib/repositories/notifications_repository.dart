import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _db
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.notifications);

  CollectionReference<Map<String, dynamic>> _deviceTokens(String uid) =>
      _db
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.deviceTokens);

  Stream<List<AppNotification>> watchNotifications(String uid) =>
      _notifications(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(AppNotification.fromDocument).toList(),
          )
          .handleError((Object error) => throw AppException.from(error));

  Future<void> recordActivity({
    required String uid,
    required String type,
    required String title,
    required String body,
    String? productId,
    String? orderId,
  }) async {
    try {
      await _notifications(uid).add({
        'type': type,
        'title': title,
        'body': body,
        'productId': ?productId,
        'orderId': ?orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> markRead(String uid, String notificationId) async {
    try {
      await _notifications(uid).doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> markAllRead(String uid, List<String> ids) async {
    try {
      final batch = _db.batch();
      for (final id in ids) {
        batch.update(_notifications(uid).doc(id), {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> deleteAll(String uid, List<String> ids) async {
    try {
      final batch = _db.batch();
      for (final id in ids) {
        batch.delete(_notifications(uid).doc(id));
      }
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> deleteNotification(String uid, String notificationId) async {
    try {
      await _notifications(uid).doc(notificationId).delete();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> saveDeviceToken(String uid, String token) async {
    try {
      await _deviceTokens(uid).doc(token).set({
        'platform': 'flutter',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> removeDeviceToken(String uid, String token) async {
    try {
      await _deviceTokens(uid).doc(token).delete();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Stream<String> watchTokenRefresh(FirebaseMessaging messaging) =>
      messaging.onTokenRefresh;
}
