import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/payment_controller.dart';
import '../../core/animations/motion.dart';
import '../../models/payment_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';
import '../../widgets/state_views.dart';
import 'add_card_screen.dart';
import 'card_sheet.dart';

/// My Wallet: saved cards (account menu). Not a separate page in the design;
/// built from the card sheet and Add New Card styles.
/// Animations: cards fan in with a stacked offset, swipe to delete, floating
/// empty state, add button press.
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payments = Get.find<PaymentController>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'My Wallet',
        actions: [
          IconButton(
            tooltip: 'Add card',
            onPressed: () => Get.to(() => const AddCardScreen()),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Obx(() {
        final cards = payments.cards.toList();
        if (cards.isEmpty) {
          return EmptyView(
            title: 'No saved cards',
            message:
                'Add a card for faster checkout. Payments are simulated on the free plan.',
            icon: Icons.account_balance_wallet_outlined,
            action: AppButton(
              label: 'Add new card',
              expand: false,
              height: 44,
              onPressed: () => Get.to(() => const AddCardScreen()),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...staggered(
              [
                for (final card in cards)
                  Dismissible(
                    key: ValueKey(card.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => payments.delete(card),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Appcolors.sale,
                      ),
                    ),
                    child: _WalletCard(card: card),
                  ),
              ],
              stepMs: 90,
              offset: const Offset(0, 0.3),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Appcolors.secondaryText,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Swipe a card to remove it. Only the last 4 digits are stored.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Appcolors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF3A3A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (card.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              const Spacer(),
              CardBrandLogo(brand: card.brand, light: true),
            ],
          ),
          const Spacer(),
          Text(
            '••••  ••••  ••••  ${card.last4}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  card.holder.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Text(
                card.expiry,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
