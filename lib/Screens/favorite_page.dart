import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/cart_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/product_filter.dart';
import '../controllers/shell_controller.dart';
import '../core/animations/effects.dart';
import '../core/animations/motion.dart';
import '../models/products.dart';
import '../theme/app_colors.dart';
import '../widgets/card_product.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/ui.dart';
import '../widgets/state_views.dart';
import 'products/filter_sheet.dart';

/// Wishlist tab (design page 18).
/// Animations: header title morphs into a search field, staggered grid,
/// removed cards shrink and fade out, fly-to-cart from each card.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesController favorites = Get.find<FavoritesController>();
  final ProductController products = Get.find<ProductController>();
  final CartController cart = Get.find<CartController>();
  final GlobalKey _cartKey = GlobalKey();
  final TextEditingController _search = TextEditingController();
  final Map<String, GlobalKey> _buttonKeys = {};
  final Set<String> _removing = {};

  bool _searching = false;
  ProductFilter _filter = const ProductFilter();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remove(Product product) async {
    setState(() => _removing.add(product.id));
    await Future<void>.delayed(const Duration(milliseconds: 260));
    await favorites.remove(product);
    if (mounted) setState(() => _removing.remove(product.id));
  }

  Future<void> _addToCart(Product product) async {
    FlyToCart.run(
      context: context,
      from: _buttonKeys[product.id],
      to: _cartKey,
      imageUrl: product.imageAt0,
    );
    await cart.addProduct(product.id);
  }

  Future<void> _openFilter(List<Product> scope) async {
    final result = await showModalBottomSheet<ProductFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterSheet(initial: _filter, scope: scope),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _openSort() async {
    final result = await showModalBottomSheet<ProductSort>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final sort in ProductSort.values)
              ListTile(
                title: Text(sort.label),
                trailing: sort == _filter.sort ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, sort),
              ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _filter = _filter.copyWith(sort: result));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        showBack: false,
        titleWidget: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: _searching
              ? HeaderSearchField(
                  key: const ValueKey('search'),
                  controller: _search,
                  hint: 'Search your wishlist',
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {},
                )
              : const Align(
                  key: ValueKey('title'),
                  alignment: Alignment.centerLeft,
                  child: Text('Wishlist'),
                ),
        ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
                key: ValueKey(_searching),
              ),
            ),
          ),
          CartAction(key: _cartKey),
        ],
      ),
      body: Obx(() {
        final saved = favorites.favoriteIds
            .map(products.productById)
            .whereType<Product>()
            .toList();
        if (saved.isEmpty) {
          return EmptyView(
            title: 'Your wishlist is empty',
            message: 'Tap the heart on any product to save it here.',
            icon: Icons.favorite_border_rounded,
            action: AppButton(
              label: 'Start shopping',
              expand: false,
              height: 44,
              onPressed: () => Get.find<ShellController>().select(ShellTab.home),
            ),
          );
        }
        final visible = _filter
            .copyWith(query: _search.text)
            .apply(saved);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  _ToolChip(
                    icon: Icons.filter_alt_outlined,
                    label: _filter.activeCount == 0 ? 'Filter' : 'Filter (${_filter.activeCount})',
                    onTap: () => _openFilter(saved),
                  ),
                  const SizedBox(width: 8),
                  _ToolChip(
                    label: 'Sort by: ${_filter.sort.label}',
                    trailing: Icons.keyboard_arrow_down_rounded,
                    onTap: _openSort,
                  ),
                  const Spacer(),
                  Text(
                    '${visible.length} items',
                    style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 22,
                  childAspectRatio: 0.55 / MediaQuery.textScalerOf(context).scale(1),
                ),
                itemBuilder: (context, index) {
                  final product = visible[index];
                  final removing = _removing.contains(product.id);
                  final key = _buttonKeys.putIfAbsent(product.id, () => GlobalKey());
                  return FadeSlideIn(
                    key: ValueKey(product.id),
                    delay: Motion.stagger(index % 8, stepMs: 50),
                    child: AnimatedScale(
                      scale: removing ? 0.6 : 1,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInBack,
                      child: AnimatedOpacity(
                        opacity: removing ? 0 : 1,
                        duration: const Duration(milliseconds: 240),
                        child: WishlistCard(
                          product: product,
                          cartButtonKey: key,
                          onRemove: () => _remove(product),
                          onAddToCart: () => _addToCart(product),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label, required this.onTap, this.icon, this.trailing});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Appcolors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 4)],
            Text(label, style: const TextStyle(fontSize: 11.5)),
            if (trailing != null) Icon(trailing, size: 16),
          ],
        ),
      ),
    );
  }
}
