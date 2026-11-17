import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/address_controller.dart';
import '../../controllers/checkout_controller.dart';
import '../../core/animations/motion.dart';
import '../../models/address.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';
import '../../widgets/state_views.dart';
import 'add_address_screen.dart';
import '../../core/utils/navigation.dart';

/// Delivery Address (design page 21). Opened from checkout it picks the
/// shipping address; from the account menu it manages the address book.
/// Animations: staggered cards, selected border + radio morph, swipe to
/// delete, floating empty state.
class AddressListScreen extends StatelessWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final addresses = Get.find<AddressController>();
    final args = Get.arguments;
    final selecting =
        args is Map &&
        args['select'] == true &&
        Get.isRegistered<CheckoutController>();
    final checkout = selecting ? Get.find<CheckoutController>() : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'Delivery Address',
        actions: [
          IconButton(
            tooltip: 'Add address',
            onPressed: () => Get.to(() => const AddAddressScreen()),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (addresses.isLoading.value && addresses.addresses.isEmpty) {
          return const LoadingView();
        }
        final list = addresses.addresses.toList();
        if (list.isEmpty) {
          return EmptyView(
            title: 'No saved addresses',
            message: 'Add an address to speed up checkout.',
            icon: Icons.location_on_outlined,
            action: AppButton(
              label: 'Add address',
              expand: false,
              height: 44,
              onPressed: () => Get.to(() => const AddAddressScreen()),
            ),
          );
        }
        final selectedId =
            checkout?.address?.id ?? addresses.defaultAddress?.id;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: staggered([
            for (final address in list)
              Dismissible(
                key: ValueKey(address.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => addresses.delete(address),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Appcolors.sale,
                  ),
                ),
                child: _AddressCard(
                  address: address,
                  selected: address.id == selectedId,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (checkout != null) {
                      checkout.selectAddress(address);
                      popPage();
                    }
                  },
                  onEdit: () =>
                      Get.to(() => AddAddressScreen(initial: address)),
                ),
              ),
          ], stepMs: 60),
        );
      }),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This address will be removed from your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Appcolors.sale),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Appcolors.primary : Appcolors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    key: ValueKey(selected),
                    size: 20,
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
                        Flexible(
                          child: Text(
                            address.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          '   |   ',
                          style: TextStyle(color: Appcolors.hint, fontSize: 12),
                        ),
                        Text(
                          address.fullPhone,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address.singleLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Appcolors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Appcolors.field,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(fontSize: 10.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit address',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_note_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
