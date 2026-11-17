import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/payment_controller.dart';
import '../../core/animations/motion.dart';
import '../../models/payment_card.dart';
import '../../theme/app_colors.dart';
import 'add_card_screen.dart';

/// "Credit Card" bottom sheet (design page 23). Returns the chosen card.
Future<PaymentCard?> showCardSheet(BuildContext context, {String? selectedId}) {
  return showModalBottomSheet<PaymentCard>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CardSheet(selectedId: selectedId),
  );
}

class _CardSheet extends StatelessWidget {
  const _CardSheet({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final payments = Get.find<PaymentController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Obx(() {
          final cards = payments.cards;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Credit Card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PressableScale(
                  onTap: () async {
                    final card = await Get.to<PaymentCard?>(
                      () => const AddCardScreen(),
                    );
                    if (card != null && context.mounted) {
                      Navigator.pop(context, card);
                    }
                  },
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Appcolors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card_rounded, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add new card',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...staggered([
                for (final card in cards)
                  Dismissible(
                    key: ValueKey(card.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => payments.delete(card),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: const Color(0xFFFDECEC),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Appcolors.sale,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, card),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              card.id == selectedId
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            CardBrandLogo(brand: card.brand),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                card.masked,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove card',
                              onPressed: () => payments.delete(card),
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Appcolors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Appcolors.sale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ], stepMs: 50),
              if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No saved cards yet.',
                    style: TextStyle(
                      color: Appcolors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Small brand mark drawn in code (no image assets needed).
class CardBrandLogo extends StatelessWidget {
  const CardBrandLogo({super.key, required this.brand, this.light = false});

  final CardBrand brand;
  final bool light;

  @override
  Widget build(BuildContext context) {
    switch (brand) {
      case CardBrand.mastercard:
        return SizedBox(
          width: 30,
          height: 20,
          child: Stack(
            children: [
              Positioned(
                left: 2,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: const Color(
                    0xFFEB001B,
                  ).withValues(alpha: 0.95),
                ),
              ),
              Positioned(
                left: 11,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: const Color(
                    0xFFF79E1B,
                  ).withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: light ? Colors.white : const Color(0xFF1A1F71),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            brand == CardBrand.unknown ? 'CARD' : brand.label.toUpperCase(),
            style: TextStyle(
              color: light ? const Color(0xFF1A1F71) : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
    }
  }
}
