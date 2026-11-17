import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/review_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/card_product.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_image.dart';
import '../../widgets/common/ui.dart';
import '../../widgets/state_views.dart';

/// My Reviews (the "Reviews" shortcut on the account page).
/// Animations: staggered review cards, swipe to delete, floating empty state.
class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = Get.find<ReviewController>();
    final products = Get.find<ProductController>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'My Reviews'),
      body: Obx(() {
        final list = reviews.myReviews.toList();
        if (list.isEmpty) {
          return const EmptyView(
            title: 'No reviews yet',
            message: 'Reviews you write on product pages will appear here.',
            icon: Icons.rate_review_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final review = list[index];
            final product = products.productById(review.productId);
            return FadeSlideIn(
              key: ValueKey(review.productId),
              delay: Motion.stagger(index),
              child: Dismissible(
                key: ValueKey('r-${review.productId}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => reviews.delete(review),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Appcolors.sale),
                ),
                child: InkWell(
                  onTap: product == null ? null : () => openProduct(product),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppImage(product?.imageAt0 ?? '', width: 64, height: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.productName.isEmpty ? (product?.name ?? 'Product') : review.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                RatingStars(rating: review.rating, size: 13),
                                const Spacer(),
                                if (review.createdAt != null)
                                  Text(
                                    DateFormats.relative(review.createdAt!),
                                    style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              review.body,
                              style: const TextStyle(fontSize: 12.5, color: Appcolors.secondaryText, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
