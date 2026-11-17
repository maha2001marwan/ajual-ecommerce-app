import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/payment_card.dart';

/// Saved cards at `users/{uid}/cards/{id}`. Only non-sensitive metadata is
/// stored; real charging would go through a payment provider (paid plan).
class PaymentRepository {
  PaymentRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.cards);

  Stream<List<PaymentCard>> watch(String uid) => _collection(uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => PaymentCard.fromMap(doc.id, doc.data()))
            .toList(),
      )
      .handleError((Object error) => throw AppException.from(error));

  Future<String> add(String uid, PaymentCard card) async {
    try {
      final ref = await _collection(uid).add(card.toMap());
      return ref.id;
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> delete(String uid, String id) async {
    try {
      await _collection(uid).doc(id).delete();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  /// Demo charge: waits like a gateway would and always approves.
  Future<String> simulateCharge({
    required double amount,
    required String method,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'demo_${DateTime.now().millisecondsSinceEpoch}';
  }
}
