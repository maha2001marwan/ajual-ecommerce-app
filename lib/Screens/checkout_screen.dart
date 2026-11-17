import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/address_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/checkout_controller.dart';
import '../controllers/orders_controller.dart';
import '../controllers/payment_controller.dart';
import '../core/animations/motion.dart';
import '../core/utils/formatters.dart';
import '../core/utils/money.dart';
import '../models/address.dart';
import '../models/payment_card.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';
import '../widgets/common/ui.dart';
import 'checkout/add_address_screen.dart';
import 'checkout/card_sheet.dart';
import 'checkout/order_success_screen.dart';

/// Checkout (design pages 20 & 23).
/// Animations: staggered sections, shipping/payment options animate their
/// selected border and radio, airmail stripe under the address, totals count,
/// Place Order morphs through "Processing payment…" / "Placing order…".
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CartController cart = Get.find<CartController>();
  final AddressController addresses = Get.find<AddressController>();
  final PaymentController payments = Get.find<PaymentController>();
  late final CheckoutController checkout = Get.put(
    CheckoutController(cart, Get.find<OrdersController>(), addresses, payments),
  );
  final TextEditingController _promo = TextEditingController();
  int _promoShake = 0;

  @override
  void initState() {
    super.initState();
    _promo.text = cart.coupon.value?.code ?? '';
  }

  @override
  void dispose() {
    _promo.dispose();
    Get.delete<CheckoutController>();
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

  Future<void> _placeOrder() async {
    HapticFeedback.mediumImpact();
    final orderId = await checkout.placeOrder();
    if (orderId == null || !mounted) return;
    Get.off(
      () => OrderSuccessScreen(orderId: orderId),
      transition: Transition.zoom,
      duration: const Duration(milliseconds: 420),
    );
  }

  Future<void> _openCardSheet() async {
    final card = await showCardSheet(context, selectedId: checkout.card?.id);
    if (card != null) checkout.selectPayment(PaymentMethodType.card, card: card);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: const AppHeader(title: 'Checkout', actions: [SupportAction()]),
      body: Obx(() {
        final lines = cart.selectedLines;
        final address = checkout.address;
        final sections = <Widget>[
          SectionCard(
            title: 'Shipping Address',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                _AddressSummary(
                  address: address,
                  onChange: () => Get.toNamed(AppRoutes.addresses, arguments: {'select': true}),
                  onAdd: () => Get.to(() => const AddAddressScreen()),
                ),
                const SizedBox(height: 14),
                const _AirmailStripe(),
              ],
            ),
          ),
          SectionCard(
            child: Column(
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        AppImage(line.image, width: 64, height: 64),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              if (line.item.variantLabel.isNotEmpty)
                                Text(
                                  line.item.variantLabel,
                                  style: const TextStyle(fontSize: 11, color: Appcolors.secondaryText),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: PriceRow(
                                      price: line.unitPrice,
                                      oldPrice: line.unitOldPrice,
                                      size: 12.5,
                                    ),
                                  ),
                                  Text('Qty: ${line.item.quantity}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: 'Shipping Method',
            child: Column(
              children: [
                for (final method in ShippingMethod.all)
                  _OptionCard(
                    selected: checkout.shipping.id == method.id,
                    onTap: () => checkout.selectShipping(method),
                    title: method.label,
                    subtitle:
                        'Estimated delivery time: ${DateFormats.range(method.from, method.to)}',
                    trailing: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        cart.deliveryFeeFor(method.id) == 0
                            ? 'FREE'
                            : Money.format(cart.deliveryFeeFor(method.id)),
                        key: ValueKey(cart.deliveryFeeFor(method.id)),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: 'Payment Method',
            child: Column(
              children: [
                _PaymentRow(
                  selected: checkout.paymentType.value == PaymentMethodType.cashOnDelivery,
                  leading: const Icon(Icons.payments_outlined, size: 22),
                  label: 'Cash on Delivery',
                  onTap: () => checkout.selectPayment(PaymentMethodType.cashOnDelivery),
                ),
                const Divider(),
                _PaymentRow(
                  selected: checkout.paymentType.value == PaymentMethodType.card,
                  leading: CardBrandLogo(brand: checkout.card?.brand ?? CardBrand.visa),
                  label: checkout.card?.masked ?? 'Add a credit card',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    if (checkout.card == null) {
                      _openCardSheet();
                    } else {
                      checkout.selectPayment(PaymentMethodType.card);
                    }
                  },
                  onTrailing: _openCardSheet,
                ),
                const Divider(),
                _PaymentRow(
                  selected: checkout.paymentType.value == PaymentMethodType.paypal,
                  leading: const Icon(Icons.paypal, color: Color(0xFF003087), size: 22),
                  label: 'Paypal',
                  badge: const DemoBadge(),
                  onTap: () => checkout.selectPayment(PaymentMethodType.paypal),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Promo Code',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShakeX(
                  trigger: _promoShake,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promo,
                          enabled: cart.coupon.value == null,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(hintText: 'Enter your code'),
                          onSubmitted: (_) => _applyPromo(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: cart.coupon.value == null ? 'Apply' : 'Remove',
                        expand: false,
                        height: 44,
                        loading: cart.isApplyingCoupon.value,
                        onPressed: cart.coupon.value == null
                            ? _applyPromo
                            : () {
                                cart.removeCoupon();
                                _promo.clear();
                              },
                      ),
                    ],
                  ),
                ),
                if (cart.couponError.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      cart.couponError.value,
                      style: const TextStyle(fontSize: 12, color: Appcolors.sale),
                    ),
                  ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    await Get.toNamed(AppRoutes.coupons, arguments: {'select': true});
                    _promo.text = cart.coupon.value?.code ?? '';
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Coupons', style: TextStyle(fontSize: 13))),
                        if (checkout.discount > 0)
                          Text(
                            '- ${Money.format(checkout.discount)}',
                            style: const TextStyle(color: Appcolors.sale, fontSize: 13),
                          ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Order Summary',
            child: Column(
              children: [
                SummaryRow(
                  label: 'Subtotal (${cart.selectedCount} Items)',
                  value: checkout.subtotal,
                  oldValue: checkout.originalSubtotal,
                ),
                SummaryRow(label: 'Delivery Fee', value: checkout.deliveryFee),
                if (checkout.discount > 0)
                  SummaryRow(label: 'Coupon', value: checkout.discount, valueColor: Appcolors.sale),
                if (checkout.cashback > 0)
                  SummaryRow(
                    label: 'Cashback (after delivery)',
                    value: checkout.cashback,
                    valueColor: Appcolors.success,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: DashedDivider(),
                ),
                SummaryRow(label: 'Total', value: checkout.total, bold: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                AppButton(
                  label: 'Place Order',
                  loading: checkout.isPlacing.value,
                  loadingLabel: checkout.placingStep.value.isEmpty
                      ? null
                      : checkout.placingStep.value,
                  onPressed: lines.isEmpty ? null : _placeOrder,
                ),
                const EncryptedNote(),
              ],
            ),
          ),
        ];
        return ListView(
          padding: const EdgeInsets.only(top: 8),
          children: staggered(sections, stepMs: 55),
        );
      }),
    );
  }
}

class _AddressSummary extends StatelessWidget {
  const _AddressSummary({required this.address, required this.onChange, required this.onAdd});

  final Address? address;
  final VoidCallback onChange;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final a = address;
    if (a == null) {
      return PressableScale(
        onTap: onAdd,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: Appcolors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_location_alt_outlined),
              SizedBox(width: 8),
              Text('Add a shipping address', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Row(
        key: ValueKey(a.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: a.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    children: [
                      const TextSpan(text: '   |   ', style: TextStyle(color: Appcolors.hint)),
                      TextSpan(
                        text: a.fullPhone,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  a.singleLine,
                  style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onChange,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Change', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Red/blue dashed "airmail" stripe from the design, gently scrolling.
class _AirmailStripe extends StatefulWidget {
  const _AirmailStripe();

  @override
  State<_AirmailStripe> createState() => _AirmailStripeState();
}

class _AirmailStripeState extends State<_AirmailStripe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: const Size(double.infinity, 3),
            painter: _StripePainter(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const segment = 28.0;
    final paint = Paint();
    final offset = -segment * 2 * t;
    var x = offset;
    var i = 0;
    while (x < size.width) {
      paint.color = i.isEven ? const Color(0xFF9E9E9E) : const Color(0xFF90CAF9);
      canvas.drawRect(Rect.fromLTWH(x, 0, segment - 6, size.height), paint);
      x += segment;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) => oldDelegate.t != t;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: PressableScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          scale: 0.98,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? Appcolors.primary : Appcolors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioDot(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Appcolors.secondaryText)),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.selected,
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
    this.onTrailing,
    this.badge,
  });

  final bool selected;
  final Widget leading;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onTrailing;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            RadioDot(selected: selected),
            const SizedBox(width: 14),
            SizedBox(width: 34, child: Center(child: leading)),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
            if (badge != null) ...[const SizedBox(width: 8), badge!],
            const Spacer(),
            if (trailing != null)
              InkWell(onTap: onTrailing, child: trailing!),
          ],
        ),
      ),
    );
  }
}

/// Animated radio indicator (outer ring + growing inner dot).
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Appcolors.primary : Appcolors.hint,
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: Appcolors.primary, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
