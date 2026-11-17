import 'package:hive_ce/hive.dart';

import '../models/products.dart';

class StorageServiceHive {
  StorageServiceHive._();

  static final StorageServiceHive instance = StorageServiceHive._();

  Box<Product> get box => Hive.box<Product>('products');

  Future<void> saveProduct(Product product) async {
    await box.put(product.id, product);
  }

  Product? getProduct(String id) {
    return box.get(id);
  }

  List<Product> getAllProducts() {
    return box.values.toList();
  }

  Future<void> deleteProduct(String id) async {
    await box.delete(id);
  }
}
