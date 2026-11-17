import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/onboarding_controller.dart';
import '../auth/widgets/auth_ui.dart';

class _Slide {
  const _Slide(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// First-launch welcome carousel. "Get Started" marks it as seen, after which
/// [AuthGate] shows the Sign In screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_Slide> _slides = [
    _Slide(
      'Find The Best Deals,\nEvery Single Day',
      'Unlock exclusive offers and discounts\non the brands you love most.',
    ),
    _Slide(
      'Discover All Your\nStyle, In One Place',
      'Explore endless choices your destination\nfor fashion and lifestyle.',
    ),
    _Slide(
      'Fast Delivery, Right\nTo Your Doorstep',
      'Order in seconds and track every\npackage until it arrives safely.',
    ),
  ];

  static const Duration _autoAdvance = Duration(seconds: 5);

  final OnboardingController onboarding = Get.find<OnboardingController>();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final image in _Collage.images) {
      precacheImage(AssetImage(image), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoAdvance, (_) {
      _goTo((_page + 1) % _slides.length, restartTimer: false);
    });
  }

  void _goTo(int page, {bool restartTimer = true}) {
    if (page < 0 || page >= _slides.length || page == _page) return;
    setState(() => _page = page);
    if (restartTimer) _restartTimer();
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 150) return;
    final forward = velocity < 0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    _goTo(_page + ((forward != isRtl) ? 1 : -1));
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleSwipe,
          child: Stack(
            children: [
              const Positioned.fill(child: _Collage()),
              Align(
                alignment: Alignment.bottomCenter,
                child: _BottomSheet(
                  page: _page,
                  count: _slides.length,
                  slide: slide,
                  onDotTap: _goTo,
                  onGetStarted: onboarding.complete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.page,
    required this.count,
    required this.slide,
    required this.onDotTap,
    required this.onGetStarted,
  });

  final int page;
  final int count;
  final _Slide slide;
  final ValueChanged<int> onDotTap;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageDots(page: page, count: count, onTap: onDotTap),
              const SizedBox(height: 52),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(slide.title),
                  children: [
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: AuthText.title,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      slide.subtitle,
                      textAlign: TextAlign.center,
                      style: AuthText.subtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 52),
              _GetStartedButton(onPressed: onGetStarted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.page,
    required this.count,
    required this.onTap,
  });

  final int page;
  final int count;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            selected: i == page,
            label: 'Slide ${i + 1} of $count',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: i == page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == page
                        ? AuthColors.black
                        : AuthColors.placeholderDot,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Black pill with a white circular arrow badge on the leading edge. On tap
/// the badge slides across the pill (a "swipe to start" feel) before the
/// action runs.
class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_controller.isAnimating) return;
    HapticFeedback.mediumImpact();
    await _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    return Semantics(
      button: true,
      label: 'Get Started',
      child: Material(
        color: AuthColors.black,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _handleTap,
          splashColor: Colors.white24,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final travel = constraints.maxWidth - 52;
                return AnimatedBuilder(
                  animation: curve,
                  builder: (context, _) {
                    final isRtl = Directionality.of(context) == TextDirection.rtl;
                    final dx = travel * curve.value * (isRtl ? -1 : 1);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 1 - curve.value,
                          child: const Text('Get Started', style: AuthText.button),
                        ),
                        PositionedDirectional(
                          start: 4,
                          top: 4,
                          bottom: 4,
                          child: Transform.translate(
                            offset: Offset(dx, 0),
                            child: Transform.rotate(
                              angle: curve.value * math.pi / 4,
                              child: Container(
                                width: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_outward_rounded,
                                  color: AuthColors.black,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of product photos tilted behind the sheet. Sizes are taken from the
/// 375pt-wide design and scaled to the screen width.
class _Collage extends StatefulWidget {
  const _Collage();

  static const String _dir = 'assets/images/onboarding';
  static const String _perfume = '$_dir/perfume.jpg';
  static const String _skincare = '$_dir/skincare.jpg';
  static const String _lipstick = '$_dir/lipstick.jpg';
  static const String _toteBag = '$_dir/tote_bag.jpg';
  static const String _fashion = '$_dir/fashion.jpg';
  static const String _earbuds = '$_dir/earbuds.jpg';

  static const List<String> images = [
    _perfume,
    _skincare,
    _lipstick,
    _toteBag,
    _fashion,
    _earbuds,
  ];

  /// Rows 1–2 are what the design shows; rows 0 and 3 only fill the corners
  /// the rotation would otherwise leave empty on tall or wide screens.
  static const List<List<String>> _grid = [
    [_earbuds, _toteBag, _skincare],
    [_perfume, _skincare, _lipstick],
    [_toteBag, _fashion, _earbuds],
    [_lipstick, _perfume, _fashion],
  ];

  static const double _designWidth = 375;
  static const double _cardWidth = 160;
  static const double _cardHeight = 250;
  static const double _gap = 14;
  static const double _gridCenterY = 227;
  static const double _angle = -7 * math.pi / 180;

  @override
  State<_Collage> createState() => _CollageState();
}

class _CollageState extends State<_Collage> with SingleTickerProviderStateMixin {
  static const _grid = _Collage._grid;
  static const _designWidth = _Collage._designWidth;
  static const _cardWidth = _Collage._cardWidth;
  static const _cardHeight = _Collage._cardHeight;
  static const _gap = _Collage._gap;
  static const _gridCenterY = _Collage._gridCenterY;
  static const _angle = _Collage._angle;

  /// Slow continuous drift so the collage feels alive behind the sheet.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / _designWidth;
        final cardWidth = _cardWidth * scale;
        final cardHeight = _cardHeight * scale;
        final gap = _gap * scale;
        final gridWidth = cardWidth * 3 + gap * 2;
        final gridHeight = cardHeight * _grid.length + gap * (_grid.length - 1);

        return ClipRect(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 1.06 - 0.06 * t, child: child),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: (constraints.maxWidth - gridWidth) / 2,
                  top: _gridCenterY * scale - gridHeight / 2,
                  width: gridWidth,
                  height: gridHeight,
                  child: AnimatedBuilder(
                    animation: _drift,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_drift.value);
                      return Transform.translate(
                        offset: Offset(-14 * scale * t, 22 * scale * t),
                        child: child,
                      );
                    },
                    child: Transform.rotate(
                    angle: _angle,
                    child: Column(
                      children: [
                        for (var row = 0; row < _grid.length; row++) ...[
                          if (row > 0) SizedBox(height: gap),
                          Row(
                            children: [
                              for (var col = 0; col < 3; col++) ...[
                                if (col > 0) SizedBox(width: gap),
                                _CollageCard(
                                  image: _grid[row][col],
                                  width: cardWidth,
                                  height: cardHeight,
                                  radius: 16 * scale,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollageCard extends StatelessWidget {
  const _CollageCard({
    required this.image,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String image;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        image,
        width: width,
        height: height,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            Container(width: width, height: height, color: AuthColors.field),
      ),
    );
  }
}
