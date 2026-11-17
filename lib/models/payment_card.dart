import 'package:cloud_firestore/cloud_firestore.dart';

enum CardBrand {
  visa('VISA'),
  mastercard('Mastercard'),
  amex('Amex'),
  jcb('JCB'),
  unknown('Card');

  const CardBrand(this.label);

  final String label;

  static CardBrand detect(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('4')) return CardBrand.visa;
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) {
      return CardBrand.mastercard;
    }
    if (RegExp(r'^3[47]').hasMatch(digits)) return CardBrand.amex;
    if (RegExp(r'^35').hasMatch(digits)) return CardBrand.jcb;
    return CardBrand.unknown;
  }

  static CardBrand fromName(String? name) => CardBrand.values.firstWhere(
    (value) => value.name == name,
    orElse: () => CardBrand.unknown,
  );
}

/// A saved card. Only the brand, last four digits, holder and expiry are kept —
/// never the full number or the CVV.
class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.holder,
    required this.expiry,
    this.billingAddress = '',
    this.postalCode = '',
    this.isDefault = false,
  });

  final String id;
  final CardBrand brand;
  final String last4;
  final String holder;
  final String expiry;
  final String billingAddress;
  final String postalCode;
  final bool isDefault;

  String get masked => '*****$last4';

  Map<String, dynamic> toMap() => {
    'brand': brand.name,
    'last4': last4,
    'holder': holder,
    'expiry': expiry,
    'billingAddress': billingAddress,
    'postalCode': postalCode,
    'isDefault': isDefault,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory PaymentCard.fromMap(String id, Map<String, dynamic> map) =>
      PaymentCard(
        id: id,
        brand: CardBrand.fromName(map['brand'] as String?),
        last4: map['last4'] as String? ?? '0000',
        holder: map['holder'] as String? ?? '',
        expiry: map['expiry'] as String? ?? '',
        billingAddress: map['billingAddress'] as String? ?? '',
        postalCode: map['postalCode'] as String? ?? '',
        isDefault: map['isDefault'] as bool? ?? false,
      );
}

enum PaymentMethodType {
  cashOnDelivery('cash_on_delivery', 'Cash on Delivery'),
  card('card', 'Credit Card'),
  paypal('paypal', 'Paypal');

  const PaymentMethodType(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethodType fromValue(String? value) =>
      PaymentMethodType.values.firstWhere(
        (type) => type.value == value,
        orElse: () => PaymentMethodType.cashOnDelivery,
      );
}
