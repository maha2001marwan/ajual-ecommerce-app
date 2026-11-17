import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/shell_controller.dart';
import '../theme/app_colors.dart';
import 'home_page.dart';
import 'categories/categories_screen.dart';
import 'favorite_page.dart';
import 'profile_screen.dart';

/// Authenticated shell: four tabs under the floating black pill navigation
/// from the design. The bar hides while scrolling down and returns on scroll
/// up; switching tabs cross-fades the content.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  final ShellController shell = Get.find<ShellController>();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  Worker? _tabWorker;
  bool _navVisible = true;

  static const List<Widget> _pages = [
    HomePage(),
    CategoriesScreen(),
    FavoritesPage(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabWorker = ever<ShellTab>(shell.tab, (_) {
      _fade.forward(from: 0.35);
      if (!_navVisible) setState(() => _navVisible = true);
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _fade.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final direction = notification.direction;
    if (direction == ScrollDirection.reverse && _navVisible) {
      setState(() => _navVisible = false);
    } else if (direction == ScrollDirection.forward && !_navVisible) {
      setState(() => _navVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tab = shell.tab.value;
      return PopScope(
        canPop: tab == ShellTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) shell.select(ShellTab.home);
        },
        child: Scaffold(
          extendBody: true,
          body: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: IndexedStack(index: tab.index, children: _pages),
            ),
          ),
          bottomNavigationBar: AnimatedSlide(
            offset: _navVisible ? Offset.zero : const Offset(0, 1.6),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Center(
                heightFactor: 1,
                child: _PillNavBar(
                  current: tab,
                  onSelect: (value) {
                    HapticFeedback.selectionClick();
                    shell.select(value);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _PillNavBar extends StatelessWidget {
  const _PillNavBar({required this.current, required this.onSelect});

  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;

  static const double _item = 46;
  static const double _gap = 8;

  static const Map<ShellTab, (IconData, String)> _items = {
    ShellTab.home: (CupertinoIcons.house, 'Home'),
    ShellTab.categories: (Icons.grid_view_rounded, 'Categories'),
    ShellTab.wishlist: (CupertinoIcons.heart, 'Wishlist'),
    ShellTab.account: (Icons.menu_rounded, 'Account'),
  };

  @override
  Widget build(BuildContext context) {
    final tabs = ShellTab.values;
    const width = _item * 4 + _gap * 3 + 12;
    return Container(
      width: width,
      height: _item + 12,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Appcolors.primary,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sliding white bubble behind the active icon.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            left: current.index * (_item + _gap),
            top: 0,
            child: Container(
              width: _item,
              height: _item,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              for (final tab in tabs) ...[
                if (tab.index > 0) const SizedBox(width: _gap),
                Semantics(
                  button: true,
                  selected: tab == current,
                  label: _items[tab]!.$2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(tab),
                    child: SizedBox.square(
                      dimension: _item,
                      child: Center(
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(
                            end: tab == current ? Appcolors.primary : Colors.white,
                          ),
                          duration: const Duration(milliseconds: 260),
                          builder: (context, color, _) => AnimatedScale(
                            scale: tab == current ? 1.08 : 1,
                            duration: const Duration(milliseconds: 260),
                            child: Icon(_items[tab]!.$1, color: color, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
