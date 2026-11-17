import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/product_filter.dart';
import '../../core/animations/motion.dart';
import '../../models/category.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/card_product.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_image.dart';
import '../products/product_list_screen.dart';

/// Categories tab (design pages 3 & 14): department rail on the left,
/// sub-categories on the right.
/// Animations: active rail marker grows in, right panel slides/fades between
/// departments, staggered tiles, press-scale tiles, arrow nudge.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ProductController products = Get.find<ProductController>();

  /// `null` = Promotions.
  String? _selected;
  bool _forward = true;
  bool _initialised = false;

  List<String?> _railItems(List<ShopCategory> categories) => [
    null,
    ...categories.map((c) => c.name),
  ];

  void _select(String? value, List<String?> items) {
    if (value == _selected) return;
    HapticFeedback.selectionClick();
    setState(() {
      _forward = items.indexOf(value) > items.indexOf(_selected);
      _selected = value;
    });
  }

  void _openList(String title, ProductFilter filter) {
    Get.to(
      () => ProductListScreen(title: title, initialFilter: filter),
      transition: Transition.cupertino,
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, top + 12, 16, 16),
              decoration: const BoxDecoration(
                color: Appcolors.primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: HeaderSearchField(
                onTap: () => Get.toNamed(AppRoutes.search),
              ),
            ),
            Expanded(
              child: Obx(() {
                final categories = products.categories.toList();
                if (!_initialised && categories.isNotEmpty) {
                  _selected = categories.first.name;
                  _initialised = true;
                }
                final items = _railItems(categories);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      // Grows with the text size so long words such as
                      // "Technologies" never split across lines.
                      width:
                          104 *
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(1).clamp(1.0, 1.3),
                      child: ListView(
                        padding: const EdgeInsets.only(top: 12, bottom: 120),
                        children: staggered(
                          [
                            for (final item in items)
                              _RailItem(
                                label: item == null
                                    ? 'Promotions'
                                    : (products
                                              .categoryByName(item)
                                              ?.railLabel ??
                                          item),
                                selected: item == _selected,
                                onTap: () => _select(item, items),
                              ),
                          ],
                          stepMs: 30,
                          offset: const Offset(-0.2, 0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(_selected);
                          final dy = incoming == _forward ? 0.06 : -0.06;
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(0, dy),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_selected),
                          child: _selected == null
                              ? _promotionsPanel()
                              : _categoryPanel(
                                  products.categoryByName(_selected!),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required VoidCallback onArrow,
    required List<Widget> tiles,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 120),
      children: [
        InkWell(
          onTap: onArrow,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const _NudgingArrow(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Fixed-width tiles whose height follows their content, so two-line
        // labels never overflow (a fixed aspect-ratio cell did on narrow
        // phones and with larger text).
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final tileWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: 14,
              children: [
                for (final tile in staggered(tiles, stepMs: 45))
                  SizedBox(width: tileWidth, child: tile),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _categoryPanel(ShopCategory? category) {
    if (category == null) return const SizedBox.shrink();
    return _panel(
      title: category.name,
      onArrow: () =>
          _openList(category.name, ProductFilter(category: category.name)),
      tiles: [
        for (final sub in category.subcategories)
          _Tile(
            image: sub.image,
            label: sub.name,
            onTap: () => _openList(
              sub.name,
              ProductFilter(category: category.name, subcategories: {sub.name}),
            ),
          ),
      ],
    );
  }

  Widget _promotionsPanel() {
    final promoted = products.visible
        .where((p) => p.isPromotion)
        .take(10)
        .toList();
    return _panel(
      title: 'Promotions',
      onArrow: () => _openList(
        'Promotions',
        const ProductFilter(category: ProductFilter.promotions),
      ),
      tiles: [
        for (final product in promoted)
          _Tile(
            image: product.imageAt0,
            label: product.name,
            badge: product.discount > 0 ? '-${product.discount}%' : null,
            onTap: () => openProduct(product),
          ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              color: selected ? Appcolors.field : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 12,
                  height: 1.35,
                  color: selected ? Appcolors.text : Appcolors.secondaryText,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(label),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  // Overshooting while shrinking would make the height negative.
                  curve: selected ? Curves.easeOutBack : Curves.easeOutCubic,
                  width: 3,
                  height: selected ? 34 : 0,
                  decoration: BoxDecoration(
                    color: Appcolors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.image,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final String image;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(image),
                if (badge != null)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Appcolors.sale,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _NudgingArrow extends StatefulWidget {
  const _NudgingArrow();

  @override
  State<_NudgingArrow> createState() => _NudgingArrowState();
}

class _NudgingArrowState extends State<_NudgingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(4 * Curves.easeInOut.transform(_controller.value), 0),
        child: child,
      ),
      child: const Icon(Icons.arrow_forward_rounded, size: 20),
    );
  }
}
