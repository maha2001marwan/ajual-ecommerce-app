import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/orders_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer_order.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';
import '../../widgets/state_views.dart';
import 'order_widgets.dart';
import 'track_order_screen.dart';

/// Order Detail (design pages 29 & 30). Updates live as the status changes.
/// Animations: status banner colour/text morph, staggered sections, copy
/// button confirms with a check, totals count, latest event slides in.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  static (String, Color) banner(OrderStatus status) => switch (status) {
    OrderStatus.pending || OrderStatus.confirmed => ('Your order is in progress', Appcolors.info),
    OrderStatus.shipped => ('Your order is on the way', const Color(0xFF7C4DFF)),
    OrderStatus.delivered => ('Your order is completed', Appcolors.success),
    OrderStatus.cancelled => ('This order was cancelled', Appcolors.sale),
    OrderStatus.returnRequested => ('Return requested', Appcolors.warning),
  };

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrdersController>();
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: const AppHeader(title: 'Order Detail', actions: [SupportAction()]),
      body: Obx(() {
        final order = orders.byId(orderId);
        if (order == null) {
          return orders.isLoading.value
              ? const LoadingView()
              : const EmptyView(message: 'This order could not be found.', icon: Icons.receipt_long_outlined);
        }
        final (text, color) = banner(order.status);
        final latest = order.events.isEmpty ? null : order.events.last;
        final sections = <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      text,
                      key: ValueKey(text),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _IconRow(
                  icon: Icons.local_shipping_outlined,
                  title: order.shippingMethod == 'express' ? 'Express Shipping' : 'Standard Shipping',
                  subtitle: order.estimatedFrom == null || order.estimatedTo == null
                      ? null
                      : 'Estimated delivery time: ${DateFormats.range(order.estimatedFrom!, order.estimatedTo!)}',
                ),
                const Divider(height: 24),
                _IconRow(
                  icon: Icons.location_on_outlined,
                  title: '${order.customerName}   |   ${order.phoneNumber}',
                  subtitle: order.deliveryAddress,
                ),
                const Divider(height: 24),
                InkWell(
                  onTap: () => Get.to(() => TrackOrderScreen(orderId: order.id)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: Text('Track Order',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                            Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        if (latest != null) ...[
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            child: Row(
                              key: ValueKey(latest.title),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 5, right: 10),
                                  child: CircleAvatar(radius: 3.5, backgroundColor: Appcolors.primary),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(latest.title,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      if (latest.note.isNotEmpty)
                                        Text(latest.note,
                                            style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(DateFormats.date(latest.at),
                                        style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
                                    Text(DateFormats.time(latest.at),
                                        style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            child: Column(children: [for (final item in order.items) OrderItemRow(item: item)]),
          ),
          SectionCard(
            title: 'Order Summary',
            child: Column(
              children: [
                SummaryRow(
                  label: 'Subtotal (${order.itemCount} Items)',
                  value: order.subtotal,
                  oldValue: order.originalSubtotal,
                ),
                SummaryRow(label: 'Delivery Fee', value: order.deliveryFee),
                if (order.discount > 0)
                  SummaryRow(label: 'Coupon', value: order.discount, valueColor: Appcolors.sale),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: DashedDivider()),
                SummaryRow(label: 'Total (VAT Included)', value: order.total, bold: true),
              ],
            ),
          ),
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Order ID', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    Text(order.displayNumber, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 10),
                    _CopyButton(value: order.displayNumber),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Payment Method', value: order.paymentLabel.isEmpty
                    ? order.paymentMethod.label
                    : order.paymentLabel),
                _InfoRow(
                  label: 'Payment Status',
                  value: order.paymentStatus == 'paid' ? 'Paid' : 'Pay on delivery',
                ),
                const Divider(height: 24),
                if (order.createdAt != null) _TimeRow(label: 'Order Time', time: order.createdAt!),
                if (order.paidAt != null) _TimeRow(label: 'Payment Time', time: order.paidAt!),
                if (order.shippedAt != null) _TimeRow(label: 'Ship Time', time: order.shippedAt!),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: OrderActions(order: order),
          ),
        ];
        return ListView(
          padding: const EdgeInsets.only(top: 8),
          children: staggered(sections, stepMs: 60),
        );
      }),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText, height: 1.4)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText)),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.time});

  final String label;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(label: label, value: '${DateFormats.date(time)}  |  ${DateFormats.time(time)}');
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    AppFeedback.success('Order ID copied');
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: _copy,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Appcolors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: _copied
              ? const Icon(Icons.check_rounded, key: ValueKey('ok'), size: 16, color: Appcolors.success)
              : const Text('Copy', key: ValueKey('copy'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
