import 'package:flutter/material.dart';

import '../models/products.dart';

enum ProductSort {
  defaultOrder('Default'),
  popular('Popularity'),
  rating('Top rated'),
  newest('Newest'),
  priceLow('Price: Low to High'),
  priceHigh('Price: High to Low');

  const ProductSort(this.label);

  final String label;
}

/// Immutable filter state for a product listing (the Filter sheet edits a
/// copy and returns it).
@immutable
class ProductFilter {
  const ProductFilter({
    this.category,
    this.subcategories = const {},
    this.highlights = const {},
    this.brands = const {},
    this.sellers = const {},
    this.delivery = const {},
    this.ratings = const {},
    this.colors = const {},
    this.sizes = const {},
    this.priceRange,
    this.query = '',
    this.sort = ProductSort.defaultOrder,
  });

  /// Top-level category; `null` = all, `Promotions` = discounted items.
  final String? category;
  final Set<String> subcategories;

  /// `promotion` / `new`.
  final Set<String> highlights;
  final Set<String> brands;
  final Set<String> sellers;
  final Set<String> delivery;

  /// Exact star values (1–5) a product's rounded rating must match.
  final Set<int> ratings;

  /// Option names (colours).
  final Set<String> colors;
  final Set<String> sizes;
  final RangeValues? priceRange;
  final String query;
  final ProductSort sort;

  static const String promotions = 'Promotions';

  /// Number shown in the Filter button badge.
  int get activeCount =>
      subcategories.length +
      highlights.length +
      brands.length +
      sellers.length +
      delivery.length +
      ratings.length +
      colors.length +
      sizes.length +
      (priceRange == null ? 0 : 1);

  ProductFilter copyWith({
    String? category,
    bool clearCategory = false,
    Set<String>? subcategories,
    Set<String>? highlights,
    Set<String>? brands,
    Set<String>? sellers,
    Set<String>? delivery,
    Set<int>? ratings,
    Set<String>? colors,
    Set<String>? sizes,
    RangeValues? priceRange,
    bool clearPrice = false,
    String? query,
    ProductSort? sort,
  }) {
    return ProductFilter(
      category: clearCategory ? null : (category ?? this.category),
      subcategories: subcategories ?? this.subcategories,
      highlights: highlights ?? this.highlights,
      brands: brands ?? this.brands,
      sellers: sellers ?? this.sellers,
      delivery: delivery ?? this.delivery,
      ratings: ratings ?? this.ratings,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      priceRange: clearPrice ? null : (priceRange ?? this.priceRange),
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }

  /// Keeps the category, query and sort; drops every refinement.
  ProductFilter cleared() =>
      ProductFilter(category: category, query: query, sort: sort);

  bool _inCategory(Product product) {
    if (category == null) return true;
    if (category == promotions) return product.isPromotion;
    return product.category == category;
  }

  bool matches(Product product) {
    if (!_inCategory(product)) return false;
    if (!product.matches(query)) return false;
    if (subcategories.isNotEmpty &&
        !subcategories.contains(product.subcategory)) {
      return false;
    }
    if (highlights.contains('promotion') && !product.isPromotion) return false;
    if (highlights.contains('new') && !product.isNew) return false;
    if (brands.isNotEmpty && !brands.contains(product.brand)) return false;
    if (sellers.isNotEmpty && !sellers.contains(product.seller)) return false;
    if (delivery.isNotEmpty && !delivery.every(product.delivery.contains)) {
      return false;
    }
    if (ratings.isNotEmpty && !ratings.contains(product.rating.round())) {
      return false;
    }
    if (colors.isNotEmpty &&
        !product.options.any((option) => colors.contains(option.name))) {
      return false;
    }
    if (sizes.isNotEmpty && !product.sizes.any(sizes.contains)) return false;
    final range = priceRange;
    if (range != null &&
        (product.price < range.start || product.price > range.end)) {
      return false;
    }
    return true;
  }

  List<Product> apply(Iterable<Product> products) {
    final list = products.where(matches).toList();
    switch (sort) {
      case ProductSort.defaultOrder:
        break;
      case ProductSort.popular:
        list.sort((a, b) => (b.sold + b.reviews).compareTo(a.sold + a.reviews));
      case ProductSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case ProductSort.newest:
        list.sort(
          (a, b) => (b.isNew ? 1 : 0).compareTo(a.isNew ? 1 : 0),
        );
      case ProductSort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }
}
