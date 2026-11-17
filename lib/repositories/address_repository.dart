import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/address.dart';

/// `users/{uid}/addresses/{id}`. Exactly one address is kept as default.
class AddressRepository {
  AddressRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.addresses);

  Stream<List<Address>> watch(String uid) => _collection(uid)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Address.fromMap(doc.id, doc.data()))
            .toList();
        list.sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return (b.updatedAt ?? DateTime(2100)).compareTo(
            a.updatedAt ?? DateTime(2100),
          );
        });
        return list;
      })
      .handleError((Object error) => throw AppException.from(error));

  /// Creates or updates [address]; returns its id.
  Future<String> save(String uid, Address address) async {
    try {
      final collection = _collection(uid);
      final ref = address.id.isEmpty
          ? collection.doc()
          : collection.doc(address.id);
      final batch = _db.batch();
      if (address.isDefault) {
        final others = await collection.where('isDefault', isEqualTo: true).get();
        for (final doc in others.docs) {
          if (doc.id != ref.id) {
            batch.update(doc.reference, {'isDefault': false});
          }
        }
      }
      batch.set(ref, address.toMap());
      await batch.commit();
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
}
