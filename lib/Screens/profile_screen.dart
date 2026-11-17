import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/orders_controller.dart';
import '../controllers/review_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/animations/motion.dart';
import '../core/utils/money.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/avatar.dart';
import '../widgets/state_views.dart';

/// Account tab (design page 32).
/// Animations: avatar springs in, order shortcut badges pop, staggered menu
/// rows, sheets for currency/language with animated check marks.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final orders = Get.find<OrdersController>();
    final reviews = Get.find<ReviewController>();
    final settings = Get.find<SettingsController>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Appcolors.section,
        body: Obx(() {
          final profile = auth.profile.value;
          if (profile == null) {
            return auth.isProfileLoading.value
                ? const LoadingView()
                : ErrorView(
                    message: 'Your profile is not available right now.',
                    onRetry: auth.refreshProfile,
                  );
          }
          final top = MediaQuery.paddingOf(context).top;
          final rows = <Widget>[
            _Group(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    InkWell(
                      onTap: () => Get.toNamed(AppRoutes.orders),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Shortcut(
                      icon: Icons.inventory_2_outlined,
                      label: 'Ongoing',
                      count: orders.ongoing.length,
                      onTap: () => Get.toNamed(AppRoutes.orders, arguments: {'tab': 1}),
                    ),
                    _Shortcut(
                      icon: Icons.local_shipping_outlined,
                      label: 'Completed',
                      count: orders.completed.length,
                      onTap: () => Get.toNamed(AppRoutes.orders, arguments: {'tab': 2}),
                    ),
                    _Shortcut(
                      icon: Icons.rate_review_outlined,
                      label: 'Reviews',
                      count: reviews.myReviews.length,
                      onTap: () => Get.toNamed(AppRoutes.myReviews),
                    ),
                    _Shortcut(
                      icon: Icons.keyboard_return_rounded,
                      label: 'Returns',
                      count: orders.returns.length,
                      onTap: () => Get.toNamed(AppRoutes.orders, arguments: {'tab': 3}),
                    ),
                  ],
                ),
              ],
            ),
            _Group(
              children: [
                _MenuRow(icon: Icons.location_on_outlined, label: 'Manage Address',
                    onTap: () => Get.toNamed(AppRoutes.addresses)),
                _MenuRow(icon: Icons.account_balance_wallet_outlined, label: 'My Wallet',
                    onTap: () => Get.toNamed(AppRoutes.payments)),
                _MenuRow(icon: Icons.confirmation_number_outlined, label: 'My Coupons',
                    onTap: () => Get.toNamed(AppRoutes.coupons)),
                _MenuRow(icon: Icons.history_rounded, label: 'Recently Viewed',
                    onTap: () => Get.toNamed(AppRoutes.recentlyViewed)),
              ],
            ),
            _Group(
              title: 'Support',
              children: [
                _MenuRow(icon: Icons.help_outline_rounded, label: 'Help Center',
                    onTap: () => Get.toNamed(AppRoutes.helpCenter)),
                _MenuRow(icon: Icons.headset_mic_outlined, label: 'Customer Service',
                    onTap: () => Get.toNamed(AppRoutes.customerService)),
              ],
            ),
            _Group(
              title: 'Setting',
              children: [
                _MenuRow(
                  icon: Icons.attach_money_rounded,
                  label: 'Currency',
                  value: settings.currency.value.code,
                  onTap: () => _pickCurrency(context, settings),
                ),
                _MenuRow(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: SettingsController.languages[settings.language.value],
                  onTap: () => _pickLanguage(context, settings),
                ),
                _MenuRow(icon: Icons.person_outline_rounded, label: 'Edit Profile',
                    onTap: () => Get.toNamed(AppRoutes.editProfile)),
              ],
            ),
            _Group(
              children: [
                _MenuRow(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  onTap: () async {
                    if (await _confirm(context, 'Sign out', 'Are you sure you want to sign out?', 'Sign out')) {
                      await auth.signOut();
                    }
                  },
                ),
                _MenuRow(
                  icon: Icons.delete_forever_outlined,
                  label: 'Delete account',
                  danger: true,
                  onTap: () async {
                    if (await _confirm(
                      context,
                      'Delete account',
                      'This permanently deletes your account and cannot be undone.',
                      'Delete',
                      destructive: true,
                    )) {
                      await auth.deleteAccount();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 110),
          ];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, top + 16, 6, 18),
                decoration: const BoxDecoration(
                  color: Appcolors.primary,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.editProfile),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) => Transform.scale(scale: value, child: child),
                        child: Stack(
                          children: [
                            Hero(tag: 'profile-avatar', child: UserAvatar(profile: profile)),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.edit_rounded, size: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.isAnonymous ? 'Guest' : profile.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const CartAction(),
                    const NotificationAction(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...staggered(rows, stepMs: 60),
            ],
          );
        }),
      ),
    );
  }

  static Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
    String action, {
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: TextStyle(color: destructive ? Appcolors.sale : null)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<T?> _sheet<T>(
    BuildContext context, {
    required String title,
    required List<(T, String, String?)> items,
    required T selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...staggered([
              for (final item in items)
                ListTile(
                  title: Text(item.$2),
                  subtitle: item.$3 == null ? null : Text(item.$3!),
                  trailing: AnimatedScale(
                    scale: item.$1 == selected ? 1 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: const Icon(Icons.check_circle_rounded),
                  ),
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ], stepMs: 40),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickCurrency(BuildContext context, SettingsController settings) async {
    final value = await _sheet<AppCurrency>(
      context,
      title: 'Currency',
      selected: settings.currency.value,
      items: [
        for (final c in AppCurrency.values)
          (c, '${c.code} (${c.symbol.trim()})', c == AppCurrency.usd ? c.label : '${c.label} · demo rate'),
      ],
    );
    if (value != null) await settings.setCurrency(value);
  }

  static Future<void> _pickLanguage(BuildContext context, SettingsController settings) async {
    final value = await _sheet<String>(
      context,
      title: 'Language',
      selected: settings.language.value,
      items: [
        ('en', 'English', null),
        ('ar', 'العربية', 'Arabic translation coming soon'),
      ],
    );
    if (value != null) await settings.setLanguage(value);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Column(
        children: [
          Badge(
            isLabelVisible: count > 0,
            backgroundColor: Appcolors.sale,
            label: RollingTextBadge('$count'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Appcolors.field, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 22),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Appcolors.sale : Appcolors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: color))),
            if (value != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  value!,
                  key: ValueKey(value),
                  style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText),
                ),
              ),
            const Icon(CupertinoIcons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}
