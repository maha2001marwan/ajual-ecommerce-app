import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/cart_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/coupon.dart';
import '../../repositories/product_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';
import '../../widgets/state_views.dart';
import '../../core/utils/navigation.dart';

/// Coupons (design page 25): ticket-shaped vouchers with notches.
/// Animations: tickets drop in staggered, selected ticket lifts with a
/// border/radio morph, code field shakes when invalid, "Limited" tag pulses.
class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final CartController cart = Get.find<CartController>();
  final TextEditingController _code = TextEditingController();
  late final Future<List<Coupon>> _future = Get.find<ProductRepository>()
      .fetchCoupons();
  int _shake = 0;

  bool get _selecting {
    final args = Get.arguments;
    return args is Map && args['select'] == true;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    FocusScope.of(context).unfocus();
    final ok = await cart.applyCoupon(_code.text);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    AppFeedback.success('${cart.coupon.value?.code} applied');
    if (_selecting && mounted) popPage();
  }

  void _pick(Coupon coupon) {
    HapticFeedback.selectionClick();
    final problem = coupon.problemFor(cart.subtotal);
    if (problem != null) {
      AppFeedback.info(problem, title: 'Not eligible yet');
      return;
    }
    cart.selectCoupon(cart.coupon.value?.code == coupon.code ? null : coupon);
    if (_selecting && cart.coupon.value != null) {
      // Let the ticket's selected state show before returning to checkout.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) popPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.section,
      appBar: const AppHeader(title: 'Coupons'),
      body: FutureBuilder<List<Coupon>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load coupons.',
              onRetry: () => setState(() {}),
            );
          }
          final coupons = (snapshot.data ?? const <Coupon>[])
              .where((c) => !c.isExpired)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ShakeX(
                trigger: _shake,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _apply(),
                          decoration: const InputDecoration(
                            hintText: 'Enter your code',
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: Obx(
                          () => AppButton(
                            label: 'Apply',
                            height: 38,
                            expand: false,
                            loading: cart.isApplyingCoupon.value,
                            onPressed: _code.text.trim().isEmpty
                                ? null
                                : _apply,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Obx(
                () => cart.couponError.value.isEmpty
                    ? const SizedBox(height: 18)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                        child: Text(
                          cart.couponError.value,
                          style: const TextStyle(
                            color: Appcolors.sale,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
              if (coupons.isEmpty)
                const EmptyView(
                  message: 'No coupons available right now.',
                  icon: Icons.confirmation_number_outlined,
                )
              else
                Obx(() {
                  final selected = cart.coupon.value?.code;
                  final subtotal = cart.subtotal;
                  return Column(
                    children: staggered(
                      [
                        for (final coupon in coupons)
                          _Ticket(
                            coupon: coupon,
                            selected: coupon.code == selected,
                            eligible: coupon.problemFor(subtotal) == null,
                            onTap: () => _pick(coupon),
                          ),
                      ],
                      stepMs: 70,
                      offset: const Offset(0, -0.15),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.coupon,
    required this.selected,
    required this.eligible,
    required this.onTap,
  });

  final Coupon coupon;
  final bool selected;
  final bool eligible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedSlide(
          offset: selected ? const Offset(0, -0.02) : Offset.zero,
          duration: const Duration(milliseconds: 220),
          child: AnimatedOpacity(
            opacity: eligible ? 1 : 0.55,
            duration: const Duration(milliseconds: 220),
            child: CustomPaint(
              painter: _TicketPainter(selected: selected),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(top: 2),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Appcolors.primary
                                  : Appcolors.hint,
                              width: selected ? 5 : 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (coupon.limited) ...[
                                    const _LimitedTag(),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      coupon.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Min spend ${Money.format(coupon.minSpend)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Appcolors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: DashedDivider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        Text(
                          coupon.code,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Valid Until: ${DateFormats.date(coupon.validUntil)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Appcolors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White ticket with semicircle notches on both sides of the divider.
class _TicketPainter extends CustomPainter {
  _TicketPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 8.0;
    const notch = 8.0;
    final notchY = size.height - 44;
    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, notchY - notch)
      ..arcToPoint(
        Offset(size.width, notchY + notch),
        radius: const Radius.circular(notch),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: const Radius.circular(radius),
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(0, notchY + notch)
      ..arcToPoint(
        Offset(0, notchY - notch),
        radius: const Radius.circular(notch),
        clockwise: false,
      )
      ..lineTo(0, radius)
      ..arcToPoint(
        const Offset(radius, 0),
        radius: const Radius.circular(radius),
      )
      ..close();
    canvas.drawShadow(path, Colors.black12, selected ? 6 : 1, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.4 : 1
        ..color = selected ? Appcolors.primary : Appcolors.border,
    );
  }

  @override
  bool shouldRepaint(covariant _TicketPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class _LimitedTag extends StatefulWidget {
  const _LimitedTag();

  @override
  State<_LimitedTag> createState() => _LimitedTagState();
}

class _LimitedTagState extends State<_LimitedTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.65, end: 1).animate(_controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Appcolors.sale,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Limited',
          style: TextStyle(color: Colors.white, fontSize: 10.5),
        ),
      ),
    );
  }
}
