import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/orders_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer_order.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/state_views.dart';
import 'order_detail_screen.dart';

/// Track Order (design page 31).
/// Animations: progress line fills to the current step, the current step's
/// check pops in, the active label bolds, timeline events stagger in, the
/// newest event pulses.
class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key, required this.orderId});

  final String orderId;

  static const _steps = ['Order Placed', 'In Progress', 'Shipped', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrdersController>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Track Order', actions: [SupportAction()]),
      body: Obx(() {
        final order = orders.byId(orderId);
        if (order == null) return const LoadingView();
        final (headline, _) = OrderDetailScreen.banner(order.status);
        final events = order.events.reversed.toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 22),
            if (order.status.trackerStep >= 0)
              _Tracker(step: order.status.trackerStep, labels: _steps)
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Appcolors.field,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status == OrderStatus.cancelled
                      ? 'This order was cancelled and will not be shipped.'
                      : 'Your return request is being reviewed.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const Divider(height: 40),
            const Text('Delivery Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _Detail(
              label: 'Estimated Delivery Time',
              value: order.estimatedFrom == null || order.estimatedTo == null
                  ? '—'
                  : DateFormats.range(order.estimatedFrom!, order.estimatedTo!),
            ),
            _Detail(label: 'Tracking ID', value: order.trackingId.isEmpty ? '—' : order.trackingId),
            const Divider(height: 36),
            for (var i = 0; i < events.length; i++)
              FadeSlideIn(
                key: ValueKey('${events[i].title}-${events[i].at.millisecondsSinceEpoch}'),
                delay: Motion.stagger(i, stepMs: 90),
                offset: const Offset(0.1, 0),
                child: _EventTile(event: events[i], isLatest: i == 0, isLast: i == events.length - 1),
              ),
            if (AppConfig.simulateOrderProgress && order.status.isOngoing)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Text(
                  'Demo: with no shipping backend on the free plan, orders advance automatically every few minutes.',
                  style: TextStyle(fontSize: 11, color: Appcolors.hint),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _Tracker extends StatelessWidget {
  const _Tracker({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width / (labels.length * 2);
        final lineWidth = width - gap * 2;
        return Column(
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: gap,
                    width: lineWidth,
                    child: Container(height: 2, color: Appcolors.border),
                  ),
                  Positioned(
                    left: gap,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: step / (labels.length - 1)),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, _) =>
                          Container(width: lineWidth * value, height: 2, color: Appcolors.primary),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: Center(
                            child: i == step
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.elasticOut,
                                    builder: (context, value, child) =>
                                        Transform.scale(scale: value, child: child),
                                    child: const CircleAvatar(
                                      radius: 13,
                                      backgroundColor: Appcolors.primary,
                                      child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 4,
                                    backgroundColor: i < step ? Appcolors.primary : const Color(0xFFD0D0D0),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 11,
                        color: i == step ? Appcolors.text : Appcolors.secondaryText,
                        fontWeight: i == step ? FontWeight.w600 : FontWeight.w400,
                      ),
                      child: Text(labels[i], textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.isLatest, required this.isLast});

  final OrderEvent event;
  final bool isLatest;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 4),
                isLatest
                    ? const PulseDot(color: Appcolors.primary, size: 7)
                    : const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircleAvatar(radius: 3.5, backgroundColor: Color(0xFFBDBDBD)),
                      ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: Appcolors.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (event.note.isNotEmpty)
                    Text(event.note, style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DateFormats.date(event.at), style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
              Text(DateFormats.time(event.at), style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}
