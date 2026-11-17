import 'package:cloud_firestore/cloud_firestore.dart';

/// A product review at `products/{productId}/reviews/{uid}` (one per user).
class Review {
  const Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.name,
    required this.rating,
    required this.title,
    required this.body,
    this.productName = '',
    this.photoCount = 0,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String userId;
  final String name;
  final double rating;
  final String title;
  final String body;
  final String productName;

  /// Photos picked in the form. They are not uploaded on the Spark plan.
  final int photoCount;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'userId': userId,
    'name': name,
    'rating': rating,
    'title': title,
    'body': body,
    'photoCount': photoCount,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory Review.fromMap(String id, Map<String, dynamic> map) {
    final created = map['createdAt'];
    return Review(
      id: id,
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      userId: map['userId'] as String? ?? id,
      name: map['name'] as String? ?? 'Customer',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      photoCount: (map['photoCount'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
