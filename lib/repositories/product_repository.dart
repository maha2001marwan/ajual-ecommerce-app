import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_config.dart';
import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../data/prodcuts.dart' as seed;
import '../models/products.dart';
import '../models/category.dart';
import '../models/coupon.dart';

/// Reads the shared catalogue: `products`, `categories` and `coupons`.
class ProductRepository {
  ProductRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(FirestorePaths.products);
  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection(FirestorePaths.categories);
  CollectionReference<Map<String, dynamic>> get _coupons =>
      _db.collection(FirestorePaths.coupons);
  DocumentReference<Map<String, dynamic>> get _seedDoc =>
      _db.collection(FirestorePaths.appConfig).doc(FirestorePaths.seedMeta);

  Stream<List<Product>> watchProducts() => _products
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Product.fromMap({...doc.data(), 'id': doc.id}))
            .toList(),
      )
      .handleError((Object error) => throw AppException.from(error));

  Stream<List<ShopCategory>> watchCategories() => _categories
      .orderBy('order')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ShopCategory.fromMap({...doc.data(), 'id': doc.id}))
            .toList(),
      )
      .handleError((Object error) => throw AppException.from(error));

  /// Catalogue version stored in `appConfig/seed` (0 when never seeded).
  Stream<int> watchCatalogVersion() => _seedDoc
      .snapshots()
      .map((doc) => (doc.data()?['version'] as num?)?.toInt() ?? 0)
      .handleError((Object error) => throw AppException.from(error));

  Future<List<Coupon>> fetchCoupons() async {
    try {
      final snapshot = await _coupons.get();
      return snapshot.docs.map((doc) => Coupon.fromMap(doc.data())).toList();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<Coupon?> findCoupon(String code) async {
    try {
      final snapshot = await _coupons.doc(code.trim().toUpperCase()).get();
      final data = snapshot.data();
      return data == null ? null : Coupon.fromMap(data);
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<Product?> fetchProduct(String id) async {
    try {
      final snapshot = await _products.doc(id).get();
      final data = snapshot.data();
      if (data == null) return null;
      return Product.fromMap({...data, 'id': snapshot.id});
    } catch (error) {
      throw AppException.from(error);
    }
  }

  /// Writes the seed catalogue once per [AppConfig.catalogVersion]. Firestore
  /// rules only allow this while `appConfig/seed` is missing or older, so the
  /// catalogue is effectively read-only for clients afterwards.
  Future<void> seedIfNeeded() async {
    try {
      final meta = await _seedDoc.get();
      final version = (meta.data()?['version'] as num?)?.toInt() ?? 0;
      if (version >= AppConfig.catalogVersion) return;

      final batch = _db.batch();
      final keepIds = seed.products.map((product) => product.id).toSet();
      final existing = await _products.get();
      for (final doc in existing.docs) {
        if (!keepIds.contains(doc.id)) batch.delete(doc.reference);
      }
      for (final product in seed.products) {
        batch.set(_products.doc(product.id), product.toMap());
      }
      final keepCategoryIds = seed.categories.map((c) => c.id).toSet();
      for (final doc in (await _categories.get()).docs) {
        if (!keepCategoryIds.contains(doc.id)) batch.delete(doc.reference);
      }
      for (final category in seed.categories) {
        batch.set(_categories.doc(category.id), category.toMap());
      }
      for (final coupon in seed.coupons()) {
        batch.set(_coupons.doc(coupon.code), coupon.toMap());
      }
      batch.set(_seedDoc, {
        'version': AppConfig.catalogVersion,
        'seededAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
