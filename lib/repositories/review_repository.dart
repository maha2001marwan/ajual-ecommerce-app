import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/review.dart';

/// Reviews live at `products/{productId}/reviews/{uid}` with a mirror at
/// `users/{uid}/reviews/{productId}` for the "My Reviews" list.
class ReviewRepository {
  ReviewRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _productReviews(String productId) =>
      _db
          .collection(FirestorePaths.products)
          .doc(productId)
          .collection(FirestorePaths.reviews);

  CollectionReference<Map<String, dynamic>> _userReviews(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.myReviews);

  Stream<List<Review>> watchForProduct(String productId) =>
      _productReviews(productId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Review.fromMap(doc.id, doc.data()))
                .toList(),
          )
          .handleError((Object error) => throw AppException.from(error));

  Stream<List<Review>> watchForUser(String uid) => _userReviews(uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.id, doc.data()))
            .toList(),
      )
      .handleError((Object error) => throw AppException.from(error));

  Future<void> submit(Review review) async {
    try {
      final batch = _db.batch();
      batch.set(_productReviews(review.productId).doc(review.userId), review.toMap());
      batch.set(_userReviews(review.userId).doc(review.productId), review.toMap());
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> delete(String uid, String productId) async {
    try {
      final batch = _db.batch();
      batch.delete(_productReviews(productId).doc(uid));
      batch.delete(_userReviews(uid).doc(productId));
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
