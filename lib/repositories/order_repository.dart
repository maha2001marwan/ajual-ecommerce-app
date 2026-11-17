import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../core/config/app_config.dart';
import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/customer_order.dart';

/// Everything needed to create an order; built by the checkout controller.
class OrderDraft {
  const OrderDraft({
    required this.items,
    required this.customerName,
    required this.phoneNumber,
    required this.deliveryAddress,
    required this.addressSnapshot,
    required this.subtotal,
    required this.originalSubtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.shippingMethod,
    required this.estimatedFrom,
    required this.estimatedTo,
    required this.paymentMethod,
    required this.paymentLabel,
    required this.paymentStatus,
    this.couponCode,
    this.paymentReference,
  });

  final List<OrderItem> items;
  final String customerName;
  final String phoneNumber;
  final String deliveryAddress;
  final Map<String, dynamic> addressSnapshot;
  final double subtotal;
  final double originalSubtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String shippingMethod;
  final DateTime estimatedFrom;
  final DateTime estimatedTo;
  final String paymentMethod;
  final String paymentLabel;
  final String paymentStatus;
  final String? couponCode;
  final String? paymentReference;
}

class OrderRepository {
  OrderRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _db = db ?? FirebaseFirestore.instance,
      _functions = functions;

  final FirebaseFirestore _db;

  /// Only touched when [AppConfig.useCloudFunctions] is on (Blaze plan).
  final FirebaseFunctions? _functions;

  final math.Random _random = math.Random.secure();

  CollectionReference<Map<String, dynamic>> _orders(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.orders);

  CollectionReference<Map<String, dynamic>> _notifications(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.notifications);

  Stream<List<CustomerOrder>> watchOrders(String uid) => _orders(uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(CustomerOrder.fromDocument).toList())
      .handleError((Object error) => throw AppException.from(error));

  String _digits(int count) =>
      List.generate(count, (_) => _random.nextInt(10)).join();

  /// Places the order and returns its document id.
  Future<String> placeOrder(String uid, OrderDraft draft) async {
    if (AppConfig.useCloudFunctions) return _placeWithFunction(draft);
    try {
      final now = DateTime.now();
      final ref = _orders(uid).doc();
      final orderNumber = 'GSHN${_digits(6)}';
      final batch = _db.batch();
      batch.set(ref, {
        'orderNumber': orderNumber,
        'items': draft.items.map((item) => item.toMap()).toList(),
        'subtotal': draft.subtotal,
        'originalSubtotal': draft.originalSubtotal,
        'deliveryFee': draft.deliveryFee,
        'discount': draft.discount,
        'total': draft.total,
        'couponCode': draft.couponCode,
        'status': OrderStatus.pending.value,
        'shippingMethod': draft.shippingMethod,
        'estimatedFrom': Timestamp.fromDate(draft.estimatedFrom),
        'estimatedTo': Timestamp.fromDate(draft.estimatedTo),
        'paymentMethod': draft.paymentMethod,
        'paymentLabel': draft.paymentLabel,
        'paymentStatus': draft.paymentStatus,
        'paymentReference': draft.paymentReference,
        if (draft.paymentStatus == 'paid')
          'paidAt': FieldValue.serverTimestamp(),
        'customerName': draft.customerName,
        'phoneNumber': draft.phoneNumber,
        'deliveryAddress': draft.deliveryAddress,
        'address': draft.addressSnapshot,
        'trackingId': 'TRK${_digits(8)}',
        'events': [
          OrderEvent(
            status: OrderStatus.pending,
            title: 'Order Placed',
            at: now,
          ).toMap(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_notifications(uid).doc(), {
        'type': 'order_update',
        'title': 'Order placed',
        'body': 'We received order #$orderNumber. We will notify you as it moves.',
        'orderId': ref.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return ref.id;
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<String> _placeWithFunction(OrderDraft draft) async {
    try {
      final functions = _functions ?? FirebaseFunctions.instance;
      final response = await functions.httpsCallable('placeOrder').call({
        'items': draft.items
            .map((item) => {'productId': item.productId, 'quantity': item.quantity})
            .toList(),
        'customerName': draft.customerName,
        'phoneNumber': draft.phoneNumber,
        'deliveryAddress': draft.deliveryAddress,
        'shippingMethod': draft.shippingMethod,
        'couponCode': draft.couponCode,
        'paymentMethod': draft.paymentMethod,
      });
      final data = response.data;
      if (data is! Map || data['orderId'] is! String) {
        throw const AppException('The order service returned an invalid response.');
      }
      return data['orderId'] as String;
    } catch (error) {
      throw AppException.from(error);
    }
  }

  /// Appends a timeline event and moves the order to [status].
  Future<void> updateStatus(
    String uid,
    CustomerOrder order,
    OrderStatus status, {
    required String title,
    String note = '',
    DateTime? at,
    bool notify = true,
  }) async {
    try {
      final ref = _orders(uid).doc(order.id);
      final batch = _db.batch();
      batch.update(ref, {
        'status': status.value,
        'events': FieldValue.arrayUnion([
          OrderEvent(
            status: status,
            title: title,
            note: note,
            at: at ?? DateTime.now(),
          ).toMap(),
        ]),
        if (status == OrderStatus.shipped)
          'shippedAt': Timestamp.fromDate(at ?? DateTime.now()),
        if (status == OrderStatus.delivered &&
            order.paymentMethod.value == 'cash_on_delivery')
          'paymentStatus': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (notify) {
        batch.set(_notifications(uid).doc(), {
          'type': 'order_update',
          'title': title,
          'body': 'Order #${order.displayNumber}: ${status.label}.',
          'orderId': order.id,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
