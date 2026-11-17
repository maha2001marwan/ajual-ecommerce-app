import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.orderId,
    this.productId,
  });

  final String id;

  /// `order_update`, `cart`, `favorite`, `promo`, `activity`.
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool isRead;
  final String? orderId;
  final String? productId;

  factory AppNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['createdAt'];
    return AppNotification(
      id: document.id,
      type: data['type'] as String? ?? 'activity',
      title: data['title'] as String? ?? 'Ajual update',
      body: data['body'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      isRead: data['read'] as bool? ?? false,
      orderId: data['orderId'] as String?,
      productId: data['productId'] as String?,
    );
  }
}
