import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/orders_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../core/animations/effects.dart';
import '../../core/animations/motion.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/ui.dart';
import '../orders/order_detail_screen.dart';

/// Shown after Place Order (not in the design — it closes the flow).
/// Animations: drawn check mark, confetti burst, staggered text and buttons.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrdersController>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.find<ShellController>().open(ShellTab.home);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const Positioned.fill(child: ConfettiBurst()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    const AnimatedCheck(size: 120),
                    const SizedBox(height: 24),
                    ...staggered(
                      [
                        const Text(
                          'Order placed!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(() {
                          final order = orders.byId(widget.orderId);
                          return Text(
                            order == null
                                ? 'Thank you for shopping with us.'
                                : 'Order #${order.displayNumber} is confirmed.\nWe’ll notify you as it moves.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Appcolors.secondaryText,
                              height: 1.5,
                            ),
                          );
                        }),
                      ],
                      startIndex: 6,
                      stepMs: 90,
                    ),
                    const Spacer(),
                    ...staggered(
                      [
                        AppButton(
                          label: 'View Order',
                          onPressed: () {
                            final order = orders.byId(widget.orderId);
                            Get.find<ShellController>().open(ShellTab.account);
                            if (order != null) {
                              Get.to(
                                () => OrderDetailScreen(orderId: order.id),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Continue Shopping',
                          outlined: true,
                          onPressed: () =>
                              Get.find<ShellController>().open(ShellTab.home),
                        ),
                      ],
                      startIndex: 9,
                      stepMs: 90,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
