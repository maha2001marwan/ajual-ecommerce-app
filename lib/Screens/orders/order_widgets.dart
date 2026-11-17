import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/orders_controller.dart';
import '../../controllers/product_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/money.dart';
import '../../models/customer_order.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_image.dart';
import '../../widgets/common/ui.dart';
import 'order_detail_screen.dart';

(String, Color) orderStatusStyle(OrderStatus status) => switch (status) {
  OrderStatus.pending => ('Ongoing', Appcolors.info),
  OrderStatus.confirmed => ('Ongoing', Appcolors.info),
  OrderStatus.shipped => ('Shipped', const Color(0xFF7C4DFF)),
  OrderStatus.delivered => ('Completed', Appcolors.success),
  OrderStatus.cancelled => ('Cancelled', Appcolors.sale),
  OrderStatus.returnRequested => ('Return', Appcolors.warning),
};

/// Pill with a (pulsing, when live) dot.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = orderStatusStyle(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(4, 3, 12, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Appcolors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status.isOngoing
              ? PulseDot(color: color, size: 6)
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(radius: 3.5, backgroundColor: color),
                ),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class OrderItemRow extends StatelessWidget {
  const OrderItemRow({super.key, required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AppImage(item.image, width: 64, height: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (item.variant.isNotEmpty)
                  Text(item.variant, style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: PriceRow(price: item.unitPrice, oldPrice: item.oldPrice, size: 12.5),
                    ),
                    Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card used by My Order and order search (design pages 26 & 28).
class OrderCard extends StatefulWidget {
  const OrderCard({super.key, required this.order});

  final CustomerOrder order;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final first = order.items.isEmpty ? null : order.items.first;
    final rest = order.items.length > 1 ? order.items.sublist(1) : const <OrderItem>[];
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Get.to(() => OrderDetailScreen(orderId: order.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(
                          '#${order.displayNumber}',
                          style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusPill(status: order.status),
                ],
              ),
              const Divider(height: 24),
              if (first != null) OrderItemRow(item: first),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Column(children: [for (final item in rest) OrderItemRow(item: item)])
                    : const SizedBox(width: double.infinity),
              ),
              if (rest.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(foregroundColor: Appcolors.text),
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 240),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ),
                    label: Text(_expanded ? 'View Less' : 'View More', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total (${order.itemCount} Items):  ',
                    style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText),
                  ),
                  Text(
                    Money.format(order.total),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OrderActions(order: order, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Context-dependent order buttons (cancel / contact / return / repurchase).
class OrderActions extends StatelessWidget {
  const OrderActions({super.key, required this.order, this.compact = false});

  final CustomerOrder order;
  final bool compact;

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('Order #${order.displayNumber} will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order', style: TextStyle(color: Appcolors.sale)),
          ),
        ],
      ),
    );
    if (confirmed == true) await Get.find<OrdersController>().cancel(order);
  }

  Future<void> _return(BuildContext context) async {
    const reasons = [
      'Item arrived damaged',
      'Wrong item received',
      'Not as described',
      'Changed my mind',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Why are you returning it?', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...staggered([
              for (final r in reasons)
                ListTile(
                  title: Text(r),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, r),
                ),
            ], stepMs: 40),
          ],
        ),
      ),
    );
    if (reason != null) await Get.find<OrdersController>().requestReturn(order, reason);
  }

  Future<void> _repurchase() async {
    final cart = Get.find<CartController>();
    final products = Get.find<ProductController>();
    var added = 0;
    for (final item in order.items) {
      final product = products.productById(item.productId);
      if (product == null || !product.inStock) continue;
      final parts = item.variant.split(' / ');
      final option = product.options.any((o) => o.name == parts.first) ? parts.first : null;
      final size = product.sizes.contains(parts.last) ? parts.last : null;
      await cart.addProduct(item.productId, quantity: item.quantity, option: option, size: size, notify: false);
      added++;
    }
    if (added == 0) {
      AppFeedback.info('These items are no longer available.', title: 'Repurchase');
      return;
    }
    Get.toNamed(AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrdersController>();
    final height = compact ? 36.0 : 50.0;
    return Obx(() {
      final busy = orders.busyOrderIds.contains(order.id);
      final buttons = <Widget>[];
      if (order.status.canCancel) {
        buttons.add(AppButton(
          label: 'Cancel Order',
          outlined: true,
          height: height,
          expand: !compact,
          loading: busy,
          onPressed: () => _cancel(context),
        ));
      }
      if (order.status.isCompleted) {
        buttons.add(AppButton(
          label: 'Return / Refund',
          outlined: true,
          height: height,
          expand: !compact,
          loading: busy,
          onPressed: () => _return(context),
        ));
      }
      if (order.status.isCompleted || order.status == OrderStatus.cancelled) {
        buttons.add(AppButton(
          label: 'Repurchase',
          height: height,
          expand: !compact,
          onPressed: _repurchase,
        ));
      } else {
        buttons.add(AppButton(
          label: 'Contact',
          height: height,
          expand: !compact,
          onPressed: () => Get.toNamed(AppRoutes.customerService),
        ));
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            compact ? buttons[i] : Expanded(child: buttons[i]),
          ],
        ],
      );
    });
  }
}
