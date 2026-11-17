import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/notifications_controller.dart';
import '../controllers/product_controller.dart';
import '../core/animations/motion.dart';
import '../core/utils/formatters.dart';
import '../models/app_notification.dart';
import '../theme/app_colors.dart';
import '../widgets/card_product.dart';
import '../widgets/common/app_header.dart';
import '../widgets/state_views.dart';
import 'orders/order_detail_screen.dart';

/// Notifications inbox (opened from the bell; not a separate design page).
/// Animations: staggered tiles, unread dot pulses, read state fades the
/// background, swipe to delete, floating empty state.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = Get.find<NotificationsController>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'Notifications',
        actions: [
          Obx(
            () => notifications.unreadCount == 0
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: notifications.markAllRead,
                    child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
                  ),
          ),
          Obx(
            () => notifications.notifications.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear all',
                    onPressed: notifications.clearAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
          ),
        ],
      ),
      body: Obx(() {
        final items = notifications.notifications.toList();
        if (items.isEmpty) {
          return const EmptyView(
            title: 'You are all caught up',
            message: 'Order updates and activity will appear here.',
            icon: Icons.notifications_none_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return FadeSlideIn(
              key: ValueKey(item.id),
              delay: Motion.stagger(index, stepMs: 45),
              child: _NotificationTile(
                notification: item,
                onTap: () {
                  notifications.markRead(item);
                  _open(item);
                },
                onDismissed: () => notifications.deleteNotification(item),
              ),
            );
          },
        );
      }),
    );
  }

  void _open(AppNotification item) {
    if (item.orderId != null) {
      Get.to(() => OrderDetailScreen(orderId: item.orderId!));
      return;
    }
    final productId = item.productId;
    if (productId != null) {
      final product = Get.find<ProductController>().productById(productId);
      if (product != null) openProduct(product);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final icon = switch (notification.type) {
      'order_update' => Icons.local_shipping_outlined,
      'cart' => Icons.shopping_bag_outlined,
      'favorite' => Icons.favorite_border_rounded,
      'promo' => Icons.local_offer_outlined,
      _ => Icons.notifications_none_rounded,
    };
    return Dismissible(
      key: ValueKey('n-${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Appcolors.sale, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Appcolors.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Appcolors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Appcolors.primary, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(notification.body, style: const TextStyle(fontSize: 12.5, color: Appcolors.secondaryText)),
                      if (notification.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          DateFormats.relative(notification.createdAt!),
                          style: const TextStyle(fontSize: 11, color: Appcolors.hint),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!notification.isRead) const PulseDot(color: Appcolors.pink, size: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
