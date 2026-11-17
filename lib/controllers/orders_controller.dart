import 'dart:async';

import 'package:get/get.dart';

import '../Service/shared_pref.dart';
import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/customer_order.dart';
import '../repositories/order_repository.dart';
import 'auth_controller.dart';

class OrdersController extends GetxController {
  OrdersController(this._repository, this._authController, {StorageServiceShared? storage})
    : _storage = storage ?? StorageServiceShared.instance;

  final OrderRepository _repository;
  final AuthController _authController;
  final StorageServiceShared _storage;

  final RxList<CustomerOrder> orders = <CustomerOrder>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isPlacingOrder = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<String> recentSearches = <String>[].obs;
  final RxSet<String> busyOrderIds = <String>{}.obs;

  StreamSubscription<List<CustomerOrder>>? _subscription;
  Worker? _userWorker;
  Timer? _simulation;
  final Set<String> _advancing = {};

  String? get _uid => _authController.user.value?.uid;

  List<CustomerOrder> get ongoing =>
      orders.where((o) => o.status.isOngoing).toList();
  List<CustomerOrder> get completed =>
      orders.where((o) => o.status.isCompleted).toList();
  List<CustomerOrder> get returns =>
      orders.where((o) => o.status.isReturn).toList();

  CustomerOrder? byId(String id) => orders.firstWhereOrNull((o) => o.id == id);

  List<CustomerOrder> search(String query) =>
      orders.where((order) => order.matches(query)).toList();

  @override
  void onInit() {
    super.onInit();
    _listen();
    _userWorker = ever(_authController.user, (_) => _listen());
    unawaited(_loadSearches());
    if (AppConfig.simulateOrderProgress) {
      _simulation = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _advanceDemoOrders(),
      );
    }
  }

  void _listen() {
    _subscription?.cancel();
    orders.clear();
    errorMessage.value = '';
    final uid = _uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    _subscription = _repository.watchOrders(uid).listen(
      (value) {
        orders.assignAll(value);
        isLoading.value = false;
        _advanceDemoOrders();
      },
      onError: (Object error) {
        isLoading.value = false;
        errorMessage.value = AppException.from(error).message;
      },
    );
  }

  void retry() => _listen();

  Future<String?> placeOrder(OrderDraft draft) async {
    final uid = _uid;
    if (uid == null || draft.items.isEmpty || isPlacingOrder.value) return null;
    isPlacingOrder.value = true;
    try {
      return await _repository.placeOrder(uid, draft);
    } catch (error) {
      AppFeedback.error(error, title: 'Could not place order');
      return null;
    } finally {
      isPlacingOrder.value = false;
    }
  }

  Future<bool> cancel(CustomerOrder order) => _change(
    order,
    OrderStatus.cancelled,
    'Order Cancelled',
    note: 'Cancelled by customer',
    success: 'Your order was cancelled.',
  );

  Future<bool> requestReturn(CustomerOrder order, String reason) => _change(
    order,
    OrderStatus.returnRequested,
    'Return Requested',
    note: reason,
    success: 'Return request sent. We will contact you shortly.',
  );

  Future<bool> _change(
    CustomerOrder order,
    OrderStatus status,
    String title, {
    String note = '',
    String? success,
  }) async {
    final uid = _uid;
    if (uid == null || busyOrderIds.contains(order.id)) return false;
    busyOrderIds.add(order.id);
    try {
      await _repository.updateStatus(uid, order, status, title: title, note: note);
      if (success != null) AppFeedback.success(success);
      return true;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not update order');
      return false;
    } finally {
      busyOrderIds.remove(order.id);
    }
  }

  /// Spark plan demo: with no backend to move orders forward, each ongoing
  /// order advances one step every [AppConfig.simulatedStepMinutes].
  Future<void> _advanceDemoOrders() async {
    if (!AppConfig.simulateOrderProgress) return;
    final uid = _uid;
    if (uid == null) return;
    final step = Duration(minutes: AppConfig.simulatedStepMinutes);
    for (final order in orders.toList()) {
      if (!order.status.isOngoing || _advancing.contains(order.id)) continue;
      final last = order.events.isNotEmpty
          ? order.events.last.at
          : (order.createdAt ?? DateTime.now());
      if (DateTime.now().difference(last) < step) continue;
      final next = switch (order.status) {
        OrderStatus.pending => (OrderStatus.confirmed, 'Order Confirmed', ''),
        OrderStatus.confirmed => (
          OrderStatus.shipped,
          'Order Shipped',
          'Packed at Warehouse: Ajual hub 23B',
        ),
        OrderStatus.shipped => (
          OrderStatus.delivered,
          'Delivered',
          'Handed to ${order.customerName.isEmpty ? 'customer' : order.customerName}',
        ),
        _ => null,
      };
      if (next == null) continue;
      _advancing.add(order.id);
      try {
        await _repository.updateStatus(
          uid,
          order,
          next.$1,
          title: next.$2,
          note: next.$3,
          at: last.add(step),
        );
      } catch (_) {
        // Try again on the next tick.
      } finally {
        _advancing.remove(order.id);
      }
    }
  }

  // --- Order search history --------------------------------------------------

  Future<void> _loadSearches() async {
    try {
      recentSearches.assignAll(await _storage.orderSearches());
    } catch (_) {}
  }

  void addSearch(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    recentSearches
      ..remove(text)
      ..insert(0, text);
    if (recentSearches.length > 6) {
      recentSearches.removeRange(6, recentSearches.length);
    }
    unawaited(_storage.saveOrderSearches(recentSearches.toList()));
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _userWorker?.dispose();
    _simulation?.cancel();
    super.onClose();
  }
}
