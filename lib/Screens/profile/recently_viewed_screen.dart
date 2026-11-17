import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../core/animations/motion.dart';
import '../../widgets/card_product.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/state_views.dart';

/// Recently Viewed (account menu): products opened on this device.
/// Animations: staggered grid, press-scale cards with Hero into details,
/// clear-all fades the grid out, floating empty state.
class RecentlyViewedScreen extends StatelessWidget {
  const RecentlyViewedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = Get.find<ProductController>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'Recently Viewed',
        actions: [
          Obx(
            () => products.recentlyViewedIds.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: products.clearRecentlyViewed,
                    child: const Text('Clear', style: TextStyle(color: Colors.white)),
                  ),
          ),
        ],
      ),
      body: Obx(() {
        final items = products.recentlyViewed;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: items.isEmpty
              ? const EmptyView(
                  key: ValueKey('empty'),
                  title: 'Nothing here yet',
                  message: 'Products you open will appear here.',
                  icon: Icons.history_rounded,
                )
              : GridView.builder(
                  key: const ValueKey('grid'),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 22,
                    childAspectRatio: 0.54 / MediaQuery.textScalerOf(context).scale(1),
                  ),
                  itemBuilder: (context, index) => FadeSlideIn(
                    key: ValueKey(items[index].id),
                    delay: Motion.stagger(index, stepMs: 50),
                    child: ProductCard(product: items[index], section: 'recently-viewed'),
                  ),
                ),
        );
      }),
    );
  }
}
