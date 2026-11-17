import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/cart_controller.dart';
import '../controllers/shell_controller.dart';
import '../core/animations/motion.dart';
import '../core/config/app_config.dart';
import '../core/utils/money.dart';
import '../models/address.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/card_product.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';
import '../widgets/common/ui.dart';
import '../widgets/state_views.dart';

/// Shopping Cart (design page 19).
/// Animations: free-shipping progress bar fills and the banner celebrates,
/// swipe-to-delete with a red trash reveal, quantity digits roll, totals
/// count up/down, staggered rows, edit-mode bottom bar swap.
class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  final CartController cart = Get.find<CartController>();
  final TextEditingController _promo = TextEditingController();
  final TextEditingController _postcode = TextEditingController();
  String _country = Regions.countries.first;
  int _promoShake = 0;

  @override
  void initState() {
    super.initState();
    _country = cart.shippingCountry.value;
    _postcode.text = cart.shippingPostcode.value;
    _promo.text = cart.coupon.value?.code ?? '';
  }

  @override
  void dispose() {
    _promo.dispose();
    _postcode.dispose();
    cart.editing.value = false;
    super.dispose();
  }

  Future<void> _applyPromo() async {
    FocusScope.of(context).unfocus();
    final ok = await cart.applyCoupon(_promo.text);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() => _promoShake++);
    }
  }

  Future<void> _pickOption(CartLine line) async {
    final product = line.product;
    if (product.options.length < 2 && product.sizes.length < 2) return;
    String? option = line.item.option;
    String? size = line.item.size;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (product.options.length > 1) ...[
                  const SizedBox(height: 14),
                  const Text('Color', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in product.options)
                        ChoiceChip(
                          label: Text('${o.name} · ${Money.format(product.priceFor(o))}'),
                          selected: option == o.name,
                          onSelected: (_) => setSheet(() => option = o.name),
                        ),
                    ],
                  ),
                ],
                if (product.sizes.length > 1) ...[
                  const SizedBox(height: 14),
                  const Text('Size', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in product.sizes)
                        ChoiceChip(
                          label: Text(s),
                          selected: size == s,
                          onSelected: (_) => setSheet(() => size = s),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                AppButton(label: 'Update', onPressed: () => Navigator.pop(context, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) await cart.changeVariant(line, option: option, size: size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: AppHeader(
        title: 'Shopping Cart',
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => Get.toNamed(AppRoutes.search),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => Get.find<ShellController>().open(ShellTab.wishlist),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
        ],
      ),
      body: Obx(() {
        final lines = cart.lines;
        if (cart.isEmpty) {
          return Container(
            color: Colors.white,
            child: EmptyView(
              title: 'Your cart is empty',
              message: 'Browse the shop and add something you love.',
              icon: Icons.shopping_bag_outlined,
              action: AppButton(
                label: 'Continue shopping',
                expand: false,
                height: 44,
                onPressed: () => Get.find<ShellController>().open(ShellTab.home),
              ),
            ),
          );
        }
        final editing = cart.editing.value;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _FreeShippingBanner(subtotal: cart.subtotal),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: Row(
                children: [
                  Checkbox(
                    value: cart.allSelected,
                    onChanged: (value) => cart.selectAll(value ?? false),
                  ),
                  Text('Choose All (${lines.length})', style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => cart.editing.toggle(),
                    style: TextButton.styleFrom(foregroundColor: Appcolors.text),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        editing ? 'Done' : 'Edit List',
                        key: ValueKey(editing),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Column(
                children: staggered([
                  for (final line in lines)
                    _CartRow(
                      key: ValueKey(line.item.lineId),
                      line: line,
                      onToggle: () => cart.toggleSelected(line.item.lineId),
                      onIncrement: () => cart.increment(line.item.lineId),
                      onDecrement: () => cart.decrement(line.item.lineId),
                      onDelete: () => cart.removeLines([line.item.lineId]),
                      onVariant: () => _pickOption(line),
                    ),
                ], stepMs: 45, offset: const Offset(0.1, 0)),
              ),
            ),
            const SizedBox(height: 8),
            SectionCard(
              title: 'Calculate Shipping',
              child: Column(
                children: [
                  AppDropdown<String>(
                    items: Regions.countries,
                    value: _country,
                    labelOf: (v) => v,
                    onChanged: (v) => setState(() => _country = v ?? _country),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _postcode,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Postcode / ZIP'),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Update Total',
                    height: 46,
                    onPressed: _postcode.text.trim().length < 3
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            cart.updateEstimate(_country, _postcode.text);
                          },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    child: cart.estimateUpdated.value
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Standard delivery to ${cart.shippingPostcode.value}: '
                                    '${cart.deliveryFee == 0 ? 'FREE' : Money.format(cart.deliveryFee)}, 3–5 days',
                                    style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShakeX(
                    trigger: _promoShake,
                    child: _PromoField(
                      controller: _promo,
                      loading: cart.isApplyingCoupon.value,
                      applied: cart.coupon.value != null,
                      onApply: _applyPromo,
                      onRemove: () {
                        cart.removeCoupon();
                        _promo.clear();
                      },
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: cart.couponError.value.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              cart.couponError.value,
                              style: const TextStyle(fontSize: 12, color: Appcolors.sale),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  SummaryRow(
                    label: 'Subtotal (${cart.selectedCount} Items)',
                    value: cart.subtotal,
                    oldValue: cart.originalSubtotal,
                  ),
                  SummaryRow(label: 'Delivery Fee', value: cart.deliveryFee),
                  if (cart.couponDiscount > 0)
                    SummaryRow(label: 'Coupon', value: cart.couponDiscount, valueColor: Appcolors.sale),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: DashedDivider(),
                  ),
                  SummaryRow(label: 'Total', value: cart.total, bold: true),
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        if (cart.isEmpty) return const SizedBox.shrink();
        final editing = cart.editing.value;
        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: editing
                ? AppButton(
                    key: const ValueKey('delete'),
                    label: 'Delete selected (${cart.selectedLines.length})',
                    icon: Icons.delete_outline_rounded,
                    onPressed: cart.selectedLines.isEmpty
                        ? null
                        : () async {
                            await cart.removeSelected();
                            cart.editing.value = false;
                          },
                  )
                : AppButton(
                    key: const ValueKey('checkout'),
                    label: 'Proceed to Checkout',
                    onPressed: cart.selectedLines.isEmpty
                        ? null
                        : () => Get.toNamed(AppRoutes.checkout),
                  ),
          ),
        );
      }),
    );
  }
}

class _FreeShippingBanner extends StatelessWidget {
  const _FreeShippingBanner({required this.subtotal});

  final double subtotal;

  @override
  Widget build(BuildContext context) {
    const threshold = AppConfig.freeShippingThreshold;
    final progress = (subtotal / threshold).clamp(0.0, 1.0);
    final unlocked = progress >= 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: unlocked ? Appcolors.freeShipping : const Color(0xFF2E7D32),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedRotation(
                turns: unlocked ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    unlocked
                        ? 'You unlocked FREE shipping! 🎉'
                        : 'Add ${Money.format(threshold - subtotal)} more for FREE shipping',
                    key: ValueKey(unlocked),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    super.key,
    required this.line,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    required this.onVariant,
  });

  final CartLine line;
  final VoidCallback onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;
  final VoidCallback onVariant;

  @override
  Widget build(BuildContext context) {
    final product = line.product;
    final variant = line.item.variantLabel;
    final canChange = product.options.length > 1 || product.sizes.length > 1;
    return Dismissible(
      key: ValueKey('dismiss-${line.item.lineId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      background: Container(
        color: const Color(0xFFF44336),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
        child: Row(
          children: [
            Checkbox(value: line.item.selected, onChanged: (_) => onToggle()),
            PressableScale(
              onTap: () => openProduct(product),
              child: AppImage(line.image, width: 72, height: 72),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (variant.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: canChange ? onVariant : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: Appcolors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(variant, style: const TextStyle(fontSize: 11)),
                            if (canChange) const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PriceRow(
                          price: line.unitPrice,
                          oldPrice: line.unitOldPrice,
                          size: 13,
                        ),
                      ),
                      _QtyButton(icon: Icons.remove, onTap: onDecrement, filled: false),
                      SizedBox(
                        width: 26,
                        child: Center(
                          child: RollingText(
                            '${line.item.quantity}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _QtyButton(icon: Icons.add, onTap: onIncrement, filled: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap, required this.filled});

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      scale: 0.85,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: filled ? Appcolors.primary : Colors.white,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: Appcolors.border),
        ),
        child: Icon(icon, size: 14, color: filled ? Colors.white : Appcolors.text),
      ),
    );
  }
}

/// Promo code input with an inline Apply / Remove button.
class _PromoField extends StatelessWidget {
  const _PromoField({
    required this.controller,
    required this.loading,
    required this.applied,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final bool loading;
  final bool applied;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Appcolors.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !applied,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Promo Code',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                prefixIcon: applied
                    ? const Icon(Icons.check_circle_rounded, color: Appcolors.success, size: 18)
                    : null,
              ),
              onSubmitted: (_) => onApply(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: AppButton(
              label: applied ? 'Remove' : 'Apply',
              height: 36,
              expand: false,
              loading: loading,
              onPressed: applied ? onRemove : onApply,
            ),
          ),
        ],
      ),
    );
  }
}
