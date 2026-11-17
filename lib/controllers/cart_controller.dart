import 'dart:async';

import 'package:get/get.dart';

import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import '../models/products.dart';
import '../models/cart_item.dart';
import '../models/coupon.dart';
import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';
import 'auth_controller.dart';
import 'notifications_controller.dart';
import 'product_controller.dart';

/// A cart line joined with its product.
class CartLine {
  const CartLine({required this.item, required this.product});

  final CartItem item;
  final Product product;

  ProductOption? get option {
    for (final option in product.options) {
      if (option.name == item.option) return option;
    }
    return null;
  }

  double get unitPrice => product.priceFor(option);
  double get unitOldPrice {
    final old = product.oldPriceFor(option);
    return old > unitPrice ? old : unitPrice;
  }

  double get total => unitPrice * item.quantity;
  double get originalTotal => unitOldPrice * item.quantity;

  String get image {
    final index = option?.imageIndex ?? 0;
    if (product.images.isEmpty) return '';
    return product.images[index < product.images.length ? index : 0];
  }
}

/// The current user's cart, kept in sync with Firestore with optimistic
/// updates. Also owns the applied coupon and the shipping estimate, which
/// are shared with checkout.
class CartController extends GetxController {
  CartController(
    this._repository,
    this._productRepository,
    this._authController,
    this._products,
  );

  final CartRepository _repository;
  final ProductRepository _productRepository;
  final AuthController _authController;
  final ProductController _products;

  final RxList<CartItem> items = <CartItem>[].obs;
  final Rxn<Coupon> coupon = Rxn<Coupon>();
  final RxString couponError = ''.obs;
  final RxBool isApplyingCoupon = false.obs;

  /// Edit List mode (bulk delete).
  final RxBool editing = false.obs;

  /// Shipping estimate from the "Calculate Shipping" card.
  final RxString shippingCountry = 'United Kingdom (UK)'.obs;
  final RxString shippingPostcode = ''.obs;
  final RxBool estimateUpdated = false.obs;

  StreamSubscription<List<CartItem>>? _subscription;
  Worker? _userWorker;
  final Set<String> _pending = {};

  String? get _uid => _authController.user.value?.uid;

  @override
  void onInit() {
    super.onInit();
    _listen();
    _userWorker = ever(_authController.user, (_) => _listen());
  }

  void _listen() {
    _subscription?.cancel();
    items.clear();
    coupon.value = null;
    final uid = _uid;
    if (uid == null) return;
    _subscription = _repository.watchCart(uid).listen(
      (value) {
        // Keep optimistic quantities for lines with a write in flight.
        final merged = [
          for (final item in value)
            _pending.contains(item.lineId)
                ? items.firstWhereOrNull((i) => i.lineId == item.lineId) ?? item
                : item,
        ];
        items.assignAll(merged);
      },
      onError: (Object error) => AppFeedback.error(error, title: 'Cart error'),
    );
  }

  // --- Derived state ---------------------------------------------------------

  /// Lines whose product is still in the catalogue.
  List<CartLine> get lines => [
    for (final item in items)
      if (_products.productById(item.productId) case final product?)
        CartLine(item: item, product: product),
  ];

  List<CartLine> get selectedLines =>
      lines.where((line) => line.item.selected).toList();

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get selectedCount =>
      selectedLines.fold(0, (sum, line) => sum + line.item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get allSelected => lines.isNotEmpty && lines.every((l) => l.item.selected);

  int quantityOf(String productId) => items
      .where((item) => item.productId == productId)
      .fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      selectedLines.fold(0, (sum, line) => sum + line.total);
  double get originalSubtotal =>
      selectedLines.fold(0, (sum, line) => sum + line.originalTotal);

  bool get qualifiesForFreeShipping =>
      subtotal >= AppConfig.freeShippingThreshold;

  /// 0..1 progress towards free shipping for the banner.
  double get freeShippingProgress =>
      (subtotal / AppConfig.freeShippingThreshold).clamp(0.0, 1.0);

  double deliveryFeeFor(String method) {
    if (selectedLines.isEmpty) return 0;
    if (method == 'express') return AppConfig.expressShippingFee;
    return qualifiesForFreeShipping ? 0 : AppConfig.standardShippingFee;
  }

  double get deliveryFee => deliveryFeeFor('standard');

  double couponDiscountFor(double fee) =>
      coupon.value?.discountFor(subtotal, fee) ?? 0;

  double get couponDiscount => couponDiscountFor(deliveryFee);

  double get total {
    final value = subtotal + deliveryFee - couponDiscount;
    return value < 0 ? 0 : value;
  }

  /// Kept for screens that still compute totals from a product lookup.
  double totalPrice(Product? Function(String id) lookup) => subtotal;

  // --- Mutations -------------------------------------------------------------

  Future<void> addProduct(
    String productId, {
    int quantity = 1,
    String? option,
    String? size,
    bool notify = true,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final lineId = CartItem.lineIdFor(productId, option: option, size: size);
    if (_pending.contains(lineId)) return;
    _pending.add(lineId);

    final index = items.indexWhere((item) => item.lineId == lineId);
    final previous = index >= 0 ? items[index] : null;
    if (previous != null) {
      items[index] = previous.copyWith(
        quantity: previous.quantity + quantity,
        selected: true,
      );
    } else {
      items.insert(
        0,
        CartItem(
          lineId: lineId,
          productId: productId,
          quantity: quantity,
          option: option,
          size: size,
        ),
      );
    }

    try {
      await _repository.add(
        uid,
        productId: productId,
        quantity: quantity,
        option: option,
        size: size,
      );
      if (notify) {
        final name = _products.productById(productId)?.name ?? 'A product';
        unawaited(
          Get.find<NotificationsController>().recordActivity(
            type: 'cart',
            title: 'Added to cart',
            body: '$name was added to your shopping cart.',
            productId: productId,
          ),
        );
      }
    } catch (error) {
      if (previous != null) {
        final i = items.indexWhere((item) => item.lineId == lineId);
        if (i >= 0) items[i] = previous;
      } else {
        items.removeWhere((item) => item.lineId == lineId);
      }
      AppFeedback.error(error, title: 'Could not update cart');
    } finally {
      _pending.remove(lineId);
    }
  }

  /// Puts only this product in the selection, for "Buy Now".
  Future<void> buyNow(
    String productId, {
    int quantity = 1,
    String? option,
    String? size,
  }) async {
    final lineId = CartItem.lineIdFor(productId, option: option, size: size);
    final others = items
        .where((item) => item.lineId != lineId && item.selected)
        .map((item) => item.lineId)
        .toList();
    await _setSelected(others, false);
    final existing = items.firstWhereOrNull((item) => item.lineId == lineId);
    if (existing == null) {
      await addProduct(productId, quantity: quantity, option: option, size: size, notify: false);
    } else {
      await setQuantity(lineId, quantity);
      await _setSelected([lineId], true);
    }
  }

  Future<void> setQuantity(String lineId, int quantity) async {
    final uid = _uid;
    if (uid == null || _pending.contains(lineId)) return;
    final index = items.indexWhere((item) => item.lineId == lineId);
    if (index < 0) return;
    _pending.add(lineId);
    final previous = items[index];
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = previous.copyWith(quantity: quantity);
    }
    try {
      await _repository.setQuantity(uid, lineId, quantity);
    } catch (error) {
      if (quantity <= 0) {
        items.insert(index > items.length ? items.length : index, previous);
      } else {
        final i = items.indexWhere((item) => item.lineId == lineId);
        if (i >= 0) items[i] = previous;
      }
      AppFeedback.error(error, title: 'Could not update cart');
    } finally {
      _pending.remove(lineId);
    }
  }

  Future<void> increment(String lineId) {
    final item = items.firstWhereOrNull((i) => i.lineId == lineId);
    if (item == null) return Future.value();
    final product = _products.productById(item.productId);
    final max = product == null || product.stock <= 0 ? 99 : product.stock;
    if (item.quantity >= max) {
      AppFeedback.info('Only $max left in stock.', title: 'Stock limit');
      return Future.value();
    }
    return setQuantity(lineId, item.quantity + 1);
  }

  Future<void> decrement(String lineId) {
    final item = items.firstWhereOrNull((i) => i.lineId == lineId);
    if (item == null || item.quantity <= 1) return Future.value();
    return setQuantity(lineId, item.quantity - 1);
  }

  Future<void> toggleSelected(String lineId) {
    final item = items.firstWhereOrNull((i) => i.lineId == lineId);
    if (item == null) return Future.value();
    return _setSelected([lineId], !item.selected);
  }

  Future<void> selectAll(bool selected) =>
      _setSelected(items.map((item) => item.lineId).toList(), selected);

  Future<void> _setSelected(List<String> lineIds, bool selected) async {
    final uid = _uid;
    if (uid == null || lineIds.isEmpty) return;
    final snapshot = items.toList();
    for (var i = 0; i < items.length; i++) {
      if (lineIds.contains(items[i].lineId)) {
        items[i] = items[i].copyWith(selected: selected);
      }
    }
    try {
      await _repository.setSelected(uid, lineIds, selected);
    } catch (error) {
      items.assignAll(snapshot);
      AppFeedback.error(error, title: 'Could not update cart');
    }
  }

  Future<void> removeLines(List<String> lineIds) async {
    final uid = _uid;
    if (uid == null || lineIds.isEmpty) return;
    final snapshot = items.toList();
    items.removeWhere((item) => lineIds.contains(item.lineId));
    try {
      await _repository.remove(uid, lineIds);
    } catch (error) {
      items.assignAll(snapshot);
      AppFeedback.error(error, title: 'Could not update cart');
    }
  }

  /// Moves a line to another option/size, merging with an existing line.
  Future<void> changeVariant(CartLine line, {String? option, String? size}) async {
    final newOption = option ?? line.item.option;
    final newSize = size ?? line.item.size;
    final newId = CartItem.lineIdFor(line.product.id, option: newOption, size: newSize);
    if (newId == line.item.lineId) return;
    final quantity = line.item.quantity;
    await removeLines([line.item.lineId]);
    await addProduct(
      line.product.id,
      quantity: quantity,
      option: newOption,
      size: newSize,
      notify: false,
    );
  }

  Future<void> removeSelected() =>
      removeLines(selectedLines.map((line) => line.item.lineId).toList());

  Future<void> clear() async {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = items.toList();
    items.clear();
    final ok = await guard(
      () => _repository.clear(uid),
      errorTitle: 'Could not clear cart',
    );
    if (!ok) items.assignAll(snapshot);
  }

  // --- Coupon & shipping estimate ----------------------------------------------

  /// Validates [code] against Firestore. Returns `true` when applied.
  Future<bool> applyCoupon(String code) async {
    final value = code.trim().toUpperCase();
    couponError.value = '';
    if (value.isEmpty) {
      couponError.value = 'Enter a promo code';
      return false;
    }
    isApplyingCoupon.value = true;
    try {
      final found = await _productRepository.findCoupon(value);
      if (found == null) {
        couponError.value = 'This code is not valid';
        return false;
      }
      final problem = found.problemFor(subtotal);
      if (problem != null) {
        couponError.value = problem;
        return false;
      }
      coupon.value = found;
      return true;
    } catch (error) {
      couponError.value = 'Could not check the code. Try again.';
      return false;
    } finally {
      isApplyingCoupon.value = false;
    }
  }

  void selectCoupon(Coupon? value) {
    couponError.value = '';
    coupon.value = value;
  }

  void removeCoupon() => selectCoupon(null);

  void updateEstimate(String country, String postcode) {
    shippingCountry.value = country;
    shippingPostcode.value = postcode.trim();
    estimateUpdated.value = true;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
