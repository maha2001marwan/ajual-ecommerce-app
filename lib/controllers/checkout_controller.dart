import 'package:get/get.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/address.dart';
import '../models/customer_order.dart';
import '../models/payment_card.dart';
import '../repositories/order_repository.dart';
import 'address_controller.dart';
import 'cart_controller.dart';
import 'orders_controller.dart';
import 'payment_controller.dart';

class ShippingMethod {
  const ShippingMethod({
    required this.id,
    required this.label,
    required this.minDays,
    required this.maxDays,
  });

  final String id;
  final String label;
  final int minDays;
  final int maxDays;

  DateTime get from => DateTime.now().add(Duration(days: minDays));
  DateTime get to => DateTime.now().add(Duration(days: maxDays));

  static const standard = ShippingMethod(
    id: 'standard',
    label: 'Standard Shipping',
    minDays: 3,
    maxDays: 5,
  );
  static const express = ShippingMethod(
    id: 'express',
    label: 'Express Shipping',
    minDays: 1,
    maxDays: 3,
  );
  static const all = [standard, express];

  static ShippingMethod byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => standard);
}

/// State of one checkout session: address, shipping, payment, totals.
class CheckoutController extends GetxController {
  CheckoutController(this._cart, this._orders, this._addresses, this._payments);

  final CartController _cart;
  final OrdersController _orders;
  final AddressController _addresses;
  final PaymentController _payments;

  final RxnString addressId = RxnString();
  final RxString shippingId = ShippingMethod.standard.id.obs;
  final Rx<PaymentMethodType> paymentType = PaymentMethodType.cashOnDelivery.obs;
  final RxnString cardId = RxnString();
  final RxBool isPlacing = false.obs;
  final RxString placingStep = ''.obs;

  Address? get address =>
      _addresses.byId(addressId.value) ?? _addresses.defaultAddress;

  PaymentCard? get card {
    final id = cardId.value;
    if (id != null) {
      final found = _payments.cards.firstWhereOrNull((c) => c.id == id);
      if (found != null) return found;
    }
    return _payments.cards.isEmpty ? null : _payments.cards.first;
  }

  ShippingMethod get shipping => ShippingMethod.byId(shippingId.value);

  double get subtotal => _cart.subtotal;
  double get originalSubtotal => _cart.originalSubtotal;
  double get deliveryFee => _cart.deliveryFeeFor(shipping.id);
  double get discount => _cart.couponDiscountFor(deliveryFee);
  double get cashback => _cart.coupon.value?.cashbackFor(subtotal) ?? 0;

  double get total {
    final value = subtotal + deliveryFee - discount;
    return value < 0 ? 0 : value;
  }

  void selectAddress(Address value) => addressId.value = value.id;
  void selectShipping(ShippingMethod value) => shippingId.value = value.id;

  void selectPayment(PaymentMethodType type, {PaymentCard? card}) {
    paymentType.value = type;
    if (card != null) cardId.value = card.id;
  }

  String get paymentLabel => switch (paymentType.value) {
    PaymentMethodType.cashOnDelivery => 'Cash on Delivery',
    PaymentMethodType.card =>
      card == null ? 'Credit Card' : '${card!.brand.label} ${card!.masked}',
    PaymentMethodType.paypal => 'Paypal',
  };

  /// Validates, (demo-)charges and writes the order. Returns its id.
  Future<String?> placeOrder() async {
    if (isPlacing.value) return null;
    final lines = _cart.selectedLines;
    final address = this.address;
    if (lines.isEmpty) {
      AppFeedback.info('Select at least one item in your cart.', title: 'Cart is empty');
      return null;
    }
    if (address == null) {
      AppFeedback.info('Add a shipping address to continue.', title: 'Address needed');
      return null;
    }
    final outOfStock = lines.where((line) => !line.product.inStock).toList();
    if (outOfStock.isNotEmpty) {
      AppFeedback.error(
        AppException('${outOfStock.first.product.name} is out of stock.'),
        title: 'Unavailable item',
      );
      return null;
    }
    if (paymentType.value == PaymentMethodType.card && card == null) {
      AppFeedback.info('Add a card or pick another payment method.', title: 'No card');
      return null;
    }

    isPlacing.value = true;
    try {
      var paymentStatus = 'unpaid';
      String? reference;
      if (paymentType.value != PaymentMethodType.cashOnDelivery) {
        placingStep.value = 'Processing payment…';
        // Demo charge — no gateway on the free plan.
        reference = await _payments.repository.simulateCharge(
          amount: total,
          method: paymentType.value.value,
        );
        paymentStatus = 'paid';
      }
      placingStep.value = 'Placing order…';
      final method = shipping;
      final draft = OrderDraft(
        items: [
          for (final line in lines)
            OrderItem(
              productId: line.product.id,
              name: line.product.name,
              unitPrice: line.unitPrice,
              oldPrice: line.unitOldPrice > line.unitPrice ? line.unitOldPrice : 0,
              quantity: line.item.quantity,
              image: line.image,
              variant: line.item.variantLabel,
            ),
        ],
        customerName: address.fullName,
        phoneNumber: address.fullPhone,
        deliveryAddress: address.singleLine,
        addressSnapshot: address.toOrderMap(),
        subtotal: subtotal,
        originalSubtotal: originalSubtotal,
        deliveryFee: deliveryFee,
        discount: discount,
        total: total,
        couponCode: _cart.coupon.value?.code,
        shippingMethod: method.id,
        estimatedFrom: method.from,
        estimatedTo: method.to,
        paymentMethod: paymentType.value.value,
        paymentLabel: paymentLabel,
        paymentStatus: paymentStatus,
        paymentReference: reference,
      );
      final orderId = await _orders.placeOrder(draft);
      if (orderId == null) return null;
      await _cart.removeLines(lines.map((line) => line.item.lineId).toList());
      _cart.removeCoupon();
      return orderId;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not place order');
      return null;
    } finally {
      isPlacing.value = false;
      placingStep.value = '';
    }
  }
}
