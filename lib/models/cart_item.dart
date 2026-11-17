import 'package:cloud_firestore/cloud_firestore.dart';

/// A line in `users/{uid}/cart/{lineId}`. One product can appear on several
/// lines when different options (colour / size) are chosen.
class CartItem {
  const CartItem({
    required this.lineId,
    required this.productId,
    required this.quantity,
    this.option,
    this.size,
    this.selected = true,
    this.addedAt,
  });

  final String lineId;
  final String productId;
  final int quantity;
  final String? option;
  final String? size;

  /// Whether the line is ticked for checkout ("Choose All").
  final bool selected;
  final DateTime? addedAt;

  /// Stable id for a product + option + size combination.
  static String lineIdFor(String productId, {String? option, String? size}) {
    String clean(String? value) =>
        (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final parts = [productId, clean(option), clean(size)];
    return parts.where((part) => part.isNotEmpty).join('__');
  }

  String get variantLabel =>
      [option, size].whereType<String>().where((v) => v.isNotEmpty).join(' / ');

  CartItem copyWith({int? quantity, bool? selected}) => CartItem(
    lineId: lineId,
    productId: productId,
    quantity: quantity ?? this.quantity,
    option: option,
    size: size,
    selected: selected ?? this.selected,
    addedAt: addedAt,
  );

  factory CartItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final added = data['addedAt'];
    return CartItem(
      lineId: doc.id,
      // Older carts used the product id as the document id.
      productId: data['productId'] as String? ?? doc.id,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      option: data['option'] as String?,
      size: data['size'] as String?,
      selected: data['selected'] as bool? ?? true,
      addedAt: added is Timestamp ? added.toDate() : null,
    );
  }
}
