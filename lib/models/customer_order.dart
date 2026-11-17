import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_card.dart';

/// Order lifecycle. `returned` covers both requested and completed returns.
enum OrderStatus {
  pending('pending', 'Order Placed'),
  confirmed('confirmed', 'In Progress'),
  shipped('shipped', 'Shipped'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled'),
  returnRequested('return_requested', 'Return Requested');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  bool get isOngoing =>
      this == pending || this == confirmed || this == shipped;
  bool get isCompleted => this == delivered;
  bool get isReturn => this == returnRequested;
  bool get canCancel => this == pending || this == confirmed;

  /// Position on the 4-step tracker (cancelled/returns sit outside it).
  int get trackerStep => switch (this) {
    pending => 0,
    confirmed => 1,
    shipped => 2,
    delivered => 3,
    _ => -1,
  };

  static OrderStatus fromValue(String? value) => OrderStatus.values.firstWhere(
    (status) => status.value == value,
    orElse: () => OrderStatus.pending,
  );
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.oldPrice = 0,
    this.image = '',
    this.variant = '',
  });

  final String productId;
  final String name;
  final double unitPrice;
  final double oldPrice;
  final int quantity;
  final String image;
  final String variant;

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'oldPrice': oldPrice,
    'quantity': quantity,
    'image': image,
    'variant': variant,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    productId: map['productId'] as String? ?? '',
    name: map['name'] as String? ?? 'Product',
    unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    oldPrice: (map['oldPrice'] as num?)?.toDouble() ?? 0,
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    image: map['image'] as String? ?? '',
    variant: map['variant'] as String? ?? '',
  );
}

/// One entry of the order timeline shown on the Track Order screen.
class OrderEvent {
  const OrderEvent({
    required this.status,
    required this.title,
    required this.at,
    this.note = '',
  });

  final OrderStatus status;
  final String title;
  final String note;
  final DateTime at;

  Map<String, dynamic> toMap() => {
    'status': status.value,
    'title': title,
    'note': note,
    'at': Timestamp.fromDate(at),
  };

  factory OrderEvent.fromMap(Map<String, dynamic> map) {
    final at = map['at'];
    return OrderEvent(
      status: OrderStatus.fromValue(map['status'] as String?),
      title: map['title'] as String? ?? '',
      note: map['note'] as String? ?? '',
      at: at is Timestamp ? at.toDate() : DateTime.now(),
    );
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.createdAt,
    this.subtotal = 0,
    this.originalSubtotal = 0,
    this.deliveryFee = 0,
    this.discount = 0,
    this.couponCode,
    this.shippingMethod = 'standard',
    this.estimatedFrom,
    this.estimatedTo,
    this.paymentLabel = '',
    this.paymentStatus = 'unpaid',
    this.paidAt,
    this.trackingId = '',
    this.customerName = '',
    this.phoneNumber = '',
    this.events = const [],
    this.shippedAt,
  });

  final String id;
  final String orderNumber;
  final List<OrderItem> items;
  final double subtotal;
  final double originalSubtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String? couponCode;
  final OrderStatus status;
  final String shippingMethod;
  final DateTime? estimatedFrom;
  final DateTime? estimatedTo;
  final PaymentMethodType paymentMethod;
  final String paymentLabel;
  final String paymentStatus;
  final DateTime? paidAt;
  final String deliveryAddress;
  final String customerName;
  final String phoneNumber;
  final String trackingId;
  final List<OrderEvent> events;
  final DateTime? createdAt;
  final DateTime? shippedAt;

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  String get displayNumber => orderNumber.isNotEmpty
      ? orderNumber
      : (id.length > 8 ? id.substring(0, 8).toUpperCase() : id);

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return displayNumber.toLowerCase().contains(q) ||
        items.any((item) => item.name.toLowerCase().contains(q));
  }

  factory CustomerOrder.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    DateTime? time(String key) {
      final value = data[key];
      return value is Timestamp ? value.toDate() : null;
    }

    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final rawEvents = data['events'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final subtotal = (data['subtotal'] as num?)?.toDouble() ??
        items.fold<double>(0, (total, item) => total + item.lineTotal);
    return CustomerOrder(
      id: document.id,
      orderNumber: data['orderNumber'] as String? ?? '',
      items: items,
      subtotal: subtotal,
      originalSubtotal:
          (data['originalSubtotal'] as num?)?.toDouble() ?? subtotal,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? subtotal,
      couponCode: data['couponCode'] as String?,
      status: OrderStatus.fromValue(data['status'] as String?),
      shippingMethod: data['shippingMethod'] as String? ?? 'standard',
      estimatedFrom: time('estimatedFrom'),
      estimatedTo: time('estimatedTo'),
      paymentMethod: PaymentMethodType.fromValue(
        data['paymentMethod'] as String?,
      ),
      paymentLabel: data['paymentLabel'] as String? ?? '',
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      paidAt: time('paidAt'),
      deliveryAddress: data['deliveryAddress'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      trackingId: data['trackingId'] as String? ?? '',
      events: rawEvents
          .whereType<Map>()
          .map((e) => OrderEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: time('createdAt'),
      shippedAt: time('shippedAt'),
    );
  }
}
