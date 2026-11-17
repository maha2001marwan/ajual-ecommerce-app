import 'package:cloud_firestore/cloud_firestore.dart';

enum CouponType { percent, fixed, freeShipping, cashback }

/// A promo code from the shared `coupons` collection.
class Coupon {
  const Coupon({
    required this.code,
    required this.title,
    required this.type,
    required this.value,
    required this.minSpend,
    required this.validUntil,
    this.cap,
    this.limited = false,
  });

  final String code;
  final String title;
  final CouponType type;

  /// Percent (0-100) for percent/cashback, an amount for fixed.
  final double value;
  final double? cap;
  final double minSpend;
  final DateTime validUntil;
  final bool limited;

  bool get isExpired => validUntil.isBefore(DateTime.now());

  /// Why the coupon can't be used for [subtotal], or null when it can.
  String? problemFor(double subtotal) {
    if (isExpired) return 'This coupon has expired';
    if (subtotal < minSpend) {
      return 'Spend at least \$${minSpend.toStringAsFixed(2)} to use $code';
    }
    return null;
  }

  /// Amount taken off the order total.
  double discountFor(double subtotal, double deliveryFee) {
    if (problemFor(subtotal) != null) return 0;
    switch (type) {
      case CouponType.percent:
        final raw = subtotal * value / 100;
        return cap == null ? raw : (raw > cap! ? cap! : raw);
      case CouponType.fixed:
        return value > subtotal ? subtotal : value;
      case CouponType.freeShipping:
        return deliveryFee;
      case CouponType.cashback:
        return 0;
    }
  }

  /// Cashback credited after delivery (shown, not deducted).
  double cashbackFor(double subtotal) {
    if (type != CouponType.cashback || problemFor(subtotal) != null) return 0;
    final raw = subtotal * value / 100;
    return cap == null ? raw : (raw > cap! ? cap! : raw);
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'title': title,
    'type': type.name,
    'value': value,
    if (cap != null) 'cap': cap,
    'minSpend': minSpend,
    'validUntil': Timestamp.fromDate(validUntil),
    'limited': limited,
  };

  factory Coupon.fromMap(Map<String, dynamic> map) {
    final until = map['validUntil'];
    return Coupon(
      code: (map['code'] as String? ?? '').toUpperCase(),
      title: map['title'] as String? ?? '',
      type: CouponType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => CouponType.fixed,
      ),
      value: (map['value'] as num?)?.toDouble() ?? 0,
      cap: (map['cap'] as num?)?.toDouble(),
      minSpend: (map['minSpend'] as num?)?.toDouble() ?? 0,
      validUntil: until is Timestamp
          ? until.toDate()
          : DateTime.now().add(const Duration(days: 30)),
      limited: map['limited'] as bool? ?? false,
    );
  }
}
