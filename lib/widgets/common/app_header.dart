import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/notifications_controller.dart';
import '../../core/animations/effects.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

/// The black top bar used across the app ("Shopping Cart", "Checkout"…).
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.bottomHeight = 0,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? bottom;
  final double bottomHeight;

  @override
  Size get preferredSize => Size.fromHeight(60 + bottomHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Appcolors.primary,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 16,
      toolbarHeight: 60,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      leading: showBack
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      title:
          titleWidget ??
          (title == null
              ? null
              : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis)),
      actions: [...actions, const SizedBox(width: 6)],
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: bottom!,
            ),
    );
  }
}

/// Shopping-bag icon with a live count badge. Pass a [GlobalKey] as [key] to
/// use it as the target of a fly-to-cart animation.
class CartAction extends StatelessWidget {
  const CartAction({
    super.key,
    this.color = Colors.white,
    this.onTap,
    this.dense = false,
  });

  final Color color;
  final VoidCallback? onTap;

  /// Tighter spacing for the home header, where the icons sit side by side.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      final count = cart.itemCount;
      return IconButton(
        tooltip: 'Cart',
        visualDensity: dense ? VisualDensity.compact : null,
        onPressed: onTap ?? () => Get.toNamed(AppRoutes.cart),
        icon: BumpOnSignal(
          signal: CartBump.signal,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.shopping_bag_outlined, color: color),
              // Design: small black counter ringed in the icon colour, tucked
              // into the bag's bottom-right corner.
              Positioned(
                right: -3,
                bottom: -3,
                child: AnimatedScale(
                  scale: count > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Appcolors.primary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color, width: 1.2),
                    ),
                    child: RollingTextBadge(count > 99 ? '99+' : '$count'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Bell icon with the unread notification count.
class NotificationAction extends StatelessWidget {
  const NotificationAction({
    super.key,
    this.color = Colors.white,
    this.dense = false,
  });

  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final notifications = Get.find<NotificationsController>();
    return Obx(() {
      final count = notifications.unreadCount;
      return IconButton(
        tooltip: 'Notifications',
        visualDensity: dense ? VisualDensity.compact : null,
        onPressed: () => Get.toNamed(AppRoutes.notifications),
        icon: Badge(
          isLabelVisible: count > 0,
          backgroundColor: Appcolors.sale,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(CupertinoIcons.bell, color: color),
        ),
      );
    });
  }
}

class SupportAction extends StatelessWidget {
  const SupportAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Customer service',
      onPressed: () => Get.toNamed(AppRoutes.customerService),
      icon: const Icon(Icons.headset_mic_outlined),
    );
  }
}

/// Small text that slides when the badge count changes.
class RollingTextBadge extends StatelessWidget {
  const RollingTextBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Text(
        text,
        key: ValueKey(text),
        style: const TextStyle(
          fontSize: 9,
          height: 1.2,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// White rounded search field shown inside black headers. When [onTap] is
/// set it behaves as a button that opens the search screen.
class HeaderSearchField extends StatelessWidget {
  const HeaderSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'I’m shopping for...',
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.showCamera = false,
    this.heroTag,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool showCamera;

  /// Shared-element tag so the field flies into the search screen.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final readOnly = onTap != null;
    final field = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                autofocus: autofocus,
                onTap: onTap,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: Appcolors.text),
                cursorColor: Appcolors.primary,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Appcolors.secondaryText,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            if (showCamera)
              IconButton(
                tooltip: 'Search by image',
                onPressed: () => Get.snackbar(
                  'Visual search',
                  'Image search needs a paid ML API — demo only.',
                  snackPosition: SnackPosition.TOP,
                  margin: const EdgeInsets.all(12),
                ),
                icon: const Icon(
                  Icons.photo_camera_outlined,
                  color: Appcolors.secondaryText,
                  size: 20,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: Appcolors.primary,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: readOnly
                      ? onTap
                      : () => onSubmitted?.call(controller?.text ?? ''),
                  child: const SizedBox.square(
                    dimension: 40,
                    child: Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return heroTag == null ? field : Hero(tag: heroTag!, child: field);
  }
}
