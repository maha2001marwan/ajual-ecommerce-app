import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/cart_item.dart';

/// Manages `users/{uid}/cart/{lineId}` where each line is a product + option.
class CartRepository {
  CartRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.cart);

  Stream<List<CartItem>> watchCart(String uid) => _collection(uid)
      .snapshots()
      .map((snapshot) {
        final items = snapshot.docs.map(CartItem.fromDocument).toList();
        items.sort(
          (a, b) => (b.addedAt ?? DateTime.now()).compareTo(
            a.addedAt ?? DateTime.now(),
          ),
        );
        return items;
      })
      .handleError((Object error) => throw AppException.from(error));

  Future<void> add(
    String uid, {
    required String productId,
    int quantity = 1,
    String? option,
    String? size,
  }) async {
    try {
      final lineId = CartItem.lineIdFor(productId, option: option, size: size);
      await _collection(uid).doc(lineId).set({
        'productId': productId,
        'option': option,
        'size': size,
        'quantity': FieldValue.increment(quantity),
        'selected': true,
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> setQuantity(String uid, String lineId, int quantity) async {
    try {
      final ref = _collection(uid).doc(lineId);
      if (quantity <= 0) {
        await ref.delete();
      } else {
        await ref.set({'quantity': quantity}, SetOptions(merge: true));
      }
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> setSelected(String uid, List<String> lineIds, bool selected) =>
      _batch(uid, lineIds, (batch, ref) {
        batch.set(ref, {'selected': selected}, SetOptions(merge: true));
      });

  Future<void> remove(String uid, List<String> lineIds) =>
      _batch(uid, lineIds, (batch, ref) => batch.delete(ref));

  Future<void> clear(String uid) async {
    try {
      final snapshot = await _collection(uid).get();
      await remove(uid, snapshot.docs.map((doc) => doc.id).toList());
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> _batch(
    String uid,
    List<String> lineIds,
    void Function(WriteBatch batch, DocumentReference<Map<String, dynamic>> ref)
    write,
  ) async {
    if (lineIds.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in lineIds) {
        write(batch, _collection(uid).doc(id));
      }
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
