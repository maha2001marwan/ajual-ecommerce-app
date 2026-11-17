import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/orders_controller.dart';
import '../core/animations/motion.dart';
import '../models/customer_order.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/common/app_header.dart';
import '../widgets/state_views.dart';
import 'orders/order_widgets.dart';

/// My Order (design page 26) with All / Ongoing / Completed / Return tabs.
/// Animations: sliding tab indicator, swipeable tab pages, staggered cards,
/// pulsing live status dots, expandable item lists, pull-to-refresh.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const _tabs = ['All', 'Ongoing', 'Completed', 'Return'];

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrdersController>();
    final args = Get.arguments;
    final initial = args is Map && args['tab'] is int ? args['tab'] as int : 0;
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initial.clamp(0, _tabs.length - 1).toInt(),
      child: Scaffold(
        backgroundColor: Appcolors.section,
        appBar: AppHeader(
          title: 'My Order',
          actions: [
            IconButton(
              tooltip: 'Search orders',
              onPressed: () => Get.toNamed(AppRoutes.orderSearch),
              icon: const Icon(Icons.search_rounded),
            ),
            const SupportAction(),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: Appcolors.text,
                unselectedLabelColor: Appcolors.secondaryText,
                indicatorColor: Appcolors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2,
                dividerColor: Appcolors.divider,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: [for (final tab in _tabs) Tab(text: tab)],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (orders.isLoading.value && orders.orders.isEmpty) {
                  return const LoadingView();
                }
                if (orders.errorMessage.value.isNotEmpty && orders.orders.isEmpty) {
                  return ErrorView(message: orders.errorMessage.value, onRetry: orders.retry);
                }
                final lists = <List<CustomerOrder>>[
                  orders.orders.toList(),
                  orders.ongoing,
                  orders.completed,
                  orders.returns,
                ];
                return TabBarView(
                  children: [
                    for (var i = 0; i < lists.length; i++) _OrderList(orders: lists[i], tab: _tabs[i]),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.tab});

  final List<CustomerOrder> orders;
  final String tab;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OrdersController>();
    if (orders.isEmpty) {
      return EmptyView(
        title: tab == 'All' ? 'No orders yet' : 'No ${tab.toLowerCase()} orders',
        message: 'Orders you place will show up here.',
        icon: Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      color: Appcolors.primary,
      onRefresh: () async {
        controller.retry();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          for (var i = 0; i < orders.length; i++)
            FadeSlideIn(
              key: ValueKey('$tab-${orders[i].id}'),
              delay: Motion.stagger(i, stepMs: 70),
              child: OrderCard(key: ValueKey(orders[i].id), order: orders[i]),
            ),
        ],
      ),
    );
  }
}
