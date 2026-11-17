import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';

/// Manages the `users/{uid}/favorites/{productId}` sub-collection.
class FavoritesRepository {
  FavoritesRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.favorites);

  Stream<List<String>> watchFavoriteIds(String uid) => _collection(uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList())
      .handleError((Object error) => throw AppException.from(error));

  Future<void> setFavorite(
    String uid,
    String productId,
    bool favorite,
  ) async {
    try {
      final ref = _collection(uid).doc(productId);
      if (favorite) {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> toggle(String uid, String productId, bool favorite) =>
      setFavorite(uid, productId, favorite);
}
