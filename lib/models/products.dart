import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A purchasable variant such as a colour. It may override the base price.
class ProductOption {
  const ProductOption({
    required this.name,
    required this.hex,
    this.price,
    this.oldPrice,
    this.imageIndex = 0,
  });

  final String name;

  /// `#RRGGBB`, used for colour swatches in the filter.
  final String hex;
  final double? price;
  final double? oldPrice;
  final int imageIndex;

  Map<String, dynamic> toMap() => {
    'name': name,
    'hex': hex,
    if (price != null) 'price': price,
    if (oldPrice != null) 'oldPrice': oldPrice,
    'imageIndex': imageIndex,
  };

  factory ProductOption.fromMap(Map<String, dynamic> map) => ProductOption(
    name: map['name'] as String? ?? '',
    hex: map['hex'] as String? ?? '#000000',
    price: (map['price'] as num?)?.toDouble(),
    oldPrice: (map['oldPrice'] as num?)?.toDouble(),
    imageIndex: (map['imageIndex'] as num?)?.toInt() ?? 0,
  );
}

class Product {
  final String id;
  final String name;
  final String brand;

  /// Store shown as "Sold by" and in the store card on the details page.
  final String seller;
  final double price;
  final double oldPrice;
  final double rating;
  final int reviews;
  final bool inStock;
  final int stock;
  final int sold;
  final String category;
  final String subcategory;
  final List<String> images;
  final List<String> features;
  final String description;
  final List<ProductOption> options;
  final List<String> sizes;

  /// `promotion`, `new`, `flash`, `trending`.
  final List<String> tags;

  /// `freeship`, `cod`, `verified`, `international`.
  final List<String> delivery;
  final String sku;

  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.oldPrice,
    required this.rating,
    required this.reviews,
    required this.images,
    required this.features,
    this.seller = 'Ajual Store',
    this.category = 'General',
    this.subcategory = '',
    this.description = '',
    this.options = const [],
    this.sizes = const [],
    this.tags = const [],
    this.delivery = const ['cod'],
    this.sku = '',
    this.inStock = true,
    this.stock = 50,
    this.sold = 0,
    this.createdAt,
  });

  int get discount =>
      oldPrice <= price || oldPrice <= 0 ? 0 : ((1 - price / oldPrice) * 100).round();

  bool get hasDiscount => discount > 0;
  bool get isFlashSale => tags.contains('flash');
  bool get isPromotion => tags.contains('promotion') || hasDiscount;
  bool get isNew => tags.contains('new');

  /// 0..1 share of the flash-sale stock already sold.
  double get soldRatio {
    final total = sold + stock;
    return total <= 0 ? 0 : sold / total;
  }

  String get imageAt0 => images.isEmpty ? '' : images.first;

  double priceFor(ProductOption? option) => option?.price ?? price;

  double oldPriceFor(ProductOption? option) =>
      option?.oldPrice ?? (option?.price != null ? 0 : oldPrice);

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        brand.toLowerCase().contains(q) ||
        seller.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        subcategory.toLowerCase().contains(q);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameLower': name.toLowerCase(),
      'brand': brand,
      'seller': seller,
      'price': price,
      'oldPrice': oldPrice,
      'rating': rating,
      'reviews': reviews,
      'inStock': inStock,
      'stock': stock,
      'sold': sold,
      'category': category,
      'subcategory': subcategory,
      'images': images,
      'features': features,
      'description': description,
      'options': options.map((option) => option.toMap()).toList(),
      'sizes': sizes,
      'tags': tags,
      'delivery': delivery,
      'sku': sku,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'];
    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      seller: map['seller'] as String? ?? 'Ajual Store',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      oldPrice: (map['oldPrice'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (map['reviews'] as num?)?.toInt() ?? 0,
      inStock: map['inStock'] as bool? ?? false,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      sold: (map['sold'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? 'General',
      subcategory: map['subcategory'] as String? ?? '',
      images: List<String>.from(map['images'] ?? const []),
      features: List<String>.from(map['features'] ?? const []),
      description: map['description'] as String? ?? '',
      options: (map['options'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => ProductOption.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      sizes: List<String>.from(map['sizes'] ?? const []),
      tags: List<String>.from(map['tags'] ?? const []),
      delivery: List<String>.from(map['delivery'] ?? const []),
      sku: map['sku'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  /// JSON for local caches (timestamps are dropped).
  String toJson() {
    final map = toMap()..remove('createdAt');
    return json.encode(map);
  }

  factory Product.fromJson(String source) =>
      Product.fromMap(Map<String, dynamic>.from(json.decode(source) as Map));
}
