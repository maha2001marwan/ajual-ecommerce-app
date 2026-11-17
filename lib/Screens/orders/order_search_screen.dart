import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/orders_controller.dart';
import '../../core/animations/motion.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/state_views.dart';
import 'order_widgets.dart';

/// Search Order (design pages 27 & 28): by order ID or product name.
/// Animations: floating empty illustration, idle ↔ results cross-fade,
/// staggered results, recent search chips pop in.
class OrderSearchScreen extends StatefulWidget {
  const OrderSearchScreen({super.key});

  @override
  State<OrderSearchScreen> createState() => _OrderSearchScreenState();
}

class _OrderSearchScreenState extends State<OrderSearchScreen> {
  final OrdersController orders = Get.find<OrdersController>();
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    FocusScope.of(context).unfocus();
    orders.addSearch(value);
    setState(() => _query = value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: AppHeader(
        titleWidget: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: HeaderSearchField(
            controller: _controller,
            hint: 'Search order',
            autofocus: true,
            onChanged: (value) => setState(() => _query = value.trim()),
            onSubmitted: _submit,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _query.isEmpty ? _idle() : _results(),
      ),
    );
  }

  Widget _idle() {
    return Obx(() {
      final recent = orders.recentSearches.toList();
      return Column(
        key: const ValueKey('idle'),
        children: [
          if (recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: staggered([
                  for (final item in recent)
                    ActionChip(
                      label: Text(item, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Appcolors.border),
                      onPressed: () {
                        _controller.text = item;
                        _submit(item);
                      },
                    ),
                ], stepMs: 40),
              ),
            ),
          const Expanded(
            child: EmptyView(
              message: 'You can search by Order ID\nor Product Name',
              icon: Icons.inventory_2_outlined,
            ),
          ),
        ],
      );
    });
  }

  Widget _results() {
    return Obx(() {
      final found = orders.search(_query);
      return ListView(
        key: const ValueKey('results'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            child: Text(
              'Showing orders for key word “$_query”',
              style: const TextStyle(fontSize: 13, color: Appcolors.secondaryText),
            ),
          ),
          if (found.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyView(message: 'No orders match this search.', icon: Icons.search_off_rounded),
            )
          else
            for (var i = 0; i < found.length; i++)
              FadeSlideIn(
                key: ValueKey('${_query}_${found[i].id}'),
                delay: Motion.stagger(i, stepMs: 60),
                child: OrderCard(order: found[i]),
              ),
        ],
      );
    });
  }
}
