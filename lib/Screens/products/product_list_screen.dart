import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/product_filter.dart';
import '../../controllers/settings_controller.dart';
import '../../core/animations/motion.dart';
import '../../models/products.dart';
import '../../theme/app_colors.dart';
import '../../widgets/card_product.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/state_views.dart';
import 'filter_sheet.dart';

/// Product listing (design page 15) with filter, sort and grid/list toggle.
/// Animations: grid ↔ list cross-fade, staggered items, filter badge pop,
/// result count rolling, press-scale cards.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    required this.title,
    this.initialFilter = const ProductFilter(),
  });

  final String title;
  final ProductFilter initialFilter;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductController products = Get.find<ProductController>();
  final SettingsController settings = Get.find<SettingsController>();
  late ProductFilter _filter = widget.initialFilter;

  /// Products in scope before refinements (for filter options & counts).
  List<Product> get _scope => ProductFilter(
    category: _filter.category,
    query: _filter.query,
  ).apply(products.visible);

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<ProductFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterSheet(initial: _filter, scope: _scope),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _openSort() async {
    final result = await showModalBottomSheet<ProductSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Sort by',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...staggered([
              for (final sort in ProductSort.values)
                ListTile(
                  title: Text(sort.label),
                  trailing: AnimatedScale(
                    scale: sort == _filter.sort ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.check_rounded),
                  ),
                  onTap: () => Navigator.pop(context, sort),
                ),
            ], stepMs: 35),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null)
      setState(() => _filter = _filter.copyWith(sort: result));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: widget.title,
        actions: const [CartAction(), NotificationAction()],
      ),
      body: Obx(() {
        final grid = settings.gridView.value;
        if (products.isLoading.value && products.products.isEmpty) {
          return const ProductGridSkeleton(count: 6);
        }
        final results = _filter.apply(products.visible);
        return Column(
          children: [
            _Toolbar(
              filterCount: _filter.activeCount,
              sort: _filter.sort,
              grid: grid,
              resultCount: results.length,
              onFilter: _openFilter,
              onSort: _openSort,
              onToggle: settings.toggleGrid,
            ),
            Expanded(
              child: results.isEmpty
                  ? EmptyView(
                      title: 'No products found',
                      message: 'Try another keyword or clear some filters.',
                      icon: Icons.search_off_rounded,
                      action: _filter.activeCount > 0
                          ? TextButton(
                              onPressed: () =>
                                  setState(() => _filter = _filter.cleared()),
                              child: const Text('Clear filters'),
                            )
                          : null,
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: grid
                          ? GridView.builder(
                              key: const ValueKey('grid'),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                              itemCount: results.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 22,
                                    childAspectRatio:
                                        0.50 /
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(1),
                                  ),
                              itemBuilder: (context, index) => FadeSlideIn(
                                key: ValueKey('g-${results[index].id}'),
                                delay: Motion.stagger(index % 8, stepMs: 50),
                                child: ProductCard(
                                  product: results[index],
                                  section: 'list',
                                ),
                              ),
                            )
                          : ListView.separated(
                              key: const ValueKey('list'),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                              itemCount: results.length,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (context, index) => FadeSlideIn(
                                key: ValueKey('l-${results[index].id}'),
                                delay: Motion.stagger(index % 8, stepMs: 40),
                                offset: const Offset(0.08, 0),
                                child: ProductListTile(product: results[index]),
                              ),
                            ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filterCount,
    required this.sort,
    required this.grid,
    required this.resultCount,
    required this.onFilter,
    required this.onSort,
    required this.onToggle,
  });

  final int filterCount;
  final ProductSort sort;
  final bool grid;
  final int resultCount;
  final VoidCallback onFilter;
  final VoidCallback onSort;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          _OutlinedChip(
            onTap: onFilter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_outlined, size: 16),
                const SizedBox(width: 6),
                const Text('Filter', style: TextStyle(fontSize: 12)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: filterCount == 0
                      ? const SizedBox(key: ValueKey(0))
                      : Container(
                          key: ValueKey(filterCount),
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Appcolors.field,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$filterCount',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _OutlinedChip(
              onTap: onSort,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Sort by: ${sort.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: grid ? 'Show as list' : 'Show as grid',
            onPressed: onToggle,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                key: ValueKey(grid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedChip extends StatelessWidget {
  const _OutlinedChip({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Appcolors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(widthFactor: 1, child: child),
      ),
    );
  }
}
