import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/app_image.dart' show appImageProvider;

/// Moving highlight used for skeleton loading states.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + 3 * t, -0.3),
            end: Alignment(-0.5 + 3 * t, 0.3),
            colors: const [
              Color(0xFFEFEFEF),
              Color(0xFFFAFAFA),
              Color(0xFFEFEFEF),
            ],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 6});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Animates a product thumbnail along an arc from [from] into the cart icon
/// identified by [to], then bumps the icon.
class FlyToCart {
  FlyToCart._();

  static Future<void> run({
    required BuildContext context,
    required GlobalKey to,
    GlobalKey? from,
    Rect? fromRect,
    String? imageUrl,
  }) async {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      CartBump.bump();
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final targetBox = to.currentContext?.findRenderObject() as RenderBox?;
    final sourceBox = from?.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || targetBox == null || !targetBox.attached) return;

    final start =
        fromRect ??
        (sourceBox != null && sourceBox.attached
            ? sourceBox.localToGlobal(Offset.zero) & sourceBox.size
            : null);
    if (start == null) return;
    final end = targetBox.localToGlobal(targetBox.size.center(Offset.zero));

    HapticFeedback.lightImpact();
    final controller = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 720),
    );
    final entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(controller.value);
          final startCenter = start.center;
          // Quadratic Bézier with the control point above the path.
          final control = Offset(
            (startCenter.dx + end.dx) / 2,
            math.min(startCenter.dy, end.dy) - 140,
          );
          final p = Offset(
            _bezier(startCenter.dx, control.dx, end.dx, t),
            _bezier(startCenter.dy, control.dy, end.dy, t),
          );
          final size = 72 * (1 - t) + 18 * t;
          return Positioned(
            left: p.dx - size / 2,
            top: p.dy - size / 2,
            child: IgnorePointer(
              child: Opacity(
                opacity: t > 0.92 ? (1 - t) / 0.08 : 1,
                child: Transform.rotate(
                  angle: t * math.pi * 0.6,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12),
                      ],
                      image: imageUrl == null || imageUrl.isEmpty
                          ? null
                          : DecorationImage(
                              image: appImageProvider(imageUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Icon(Icons.shopping_bag, size: 18)
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(entry);
    try {
      await controller.forward();
    } finally {
      entry.remove();
      controller.dispose();
    }
    CartBump.bump();
  }

  static double _bezier(double a, double b, double c, double t) =>
      (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c;
}

/// Global pulse signal for cart icons ([BumpOnSignal] listens to it).
class CartBump {
  CartBump._();

  static final ValueNotifier<int> signal = ValueNotifier<int>(0);

  static void bump() => signal.value++;
}

/// Pops its child (e.g. the cart icon) whenever [signal] changes.
class BumpOnSignal extends StatefulWidget {
  const BumpOnSignal({super.key, required this.signal, required this.child});

  final ValueListenable<int> signal;
  final Widget child;

  @override
  State<BumpOnSignal> createState() => _BumpOnSignalState();
}

class _BumpOnSignalState extends State<BumpOnSignal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    widget.signal.addListener(_play);
  }

  void _play() => _controller.forward(from: 0);

  @override
  void dispose() {
    widget.signal.removeListener(_play);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1 + math.sin(t * math.pi) * 0.35;
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

/// Heart toggle with a scale pop and a ring of particles when favourited.
class HeartButton extends StatefulWidget {
  const HeartButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.size = 22,
    this.inactiveColor = Appcolors.text,
  });

  final bool isFavorite;
  final VoidCallback onTap;
  final double size;
  final Color inactiveColor;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didUpdateWidget(covariant HeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFavorite && widget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      toggled: widget.isFavorite,
      label: widget.isFavorite ? 'Remove from wishlist' : 'Add to wishlist',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: SizedBox.square(
          dimension: size * 1.9,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final pop = t == 0
                  ? 1.0
                  : 1 + math.sin(math.min(t * 1.6, 1) * math.pi) * 0.4;
              return CustomPaint(
                painter: t == 0 || t == 1 ? null : _BurstPainter(t),
                child: Center(
                  child: Transform.scale(
                    scale: pop,
                    child: Icon(
                      widget.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: size,
                      color: widget.isFavorite
                          ? Appcolors.pink
                          : widget.inactiveColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  static const List<Color> _colors = [
    Appcolors.pink,
    Color(0xFFFFB400),
    Color(0xFF7C4DFF),
    Color(0xFF00BFA5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.25 + size.width * 0.45 * t;
    final paint = Paint();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final offset = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(offset, 2.6 * (1 - t) + 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.t != t;
}

/// Draws a check mark inside a circle progressively — used after an order is
/// placed or a password is reset.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    this.size = 96,
    this.color = Appcolors.success,
  });

  final double size;
  final Color color;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _CheckPainter(_controller.value, widget.color),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final circleT = Curves.easeOutBack.transform((t / 0.5).clamp(0.0, 1.0));
    final checkT = Curves.easeOutCubic.transform(
      ((t - 0.45) / 0.55).clamp(0.0, 1.0),
    );
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius * circleT,
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawCircle(center, radius * 0.72 * circleT, Paint()..color = color);

    if (checkT <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.33, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.63)
      ..lineTo(size.width * 0.68, size.height * 0.40);
    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * checkT);
    canvas.drawPath(
      extract,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

/// One-shot confetti burst that falls behind content.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  final List<_Piece> _pieces = List.generate(60, (i) {
    final random = math.Random(i * 7919);
    return _Piece(
      x: random.nextDouble(),
      speed: 0.6 + random.nextDouble() * 0.8,
      drift: (random.nextDouble() - 0.5) * 0.3,
      spin: random.nextDouble() * math.pi * 4,
      color: const [
        Color(0xFFE13D5C),
        Color(0xFFFFB400),
        Color(0xFF1FB57A),
        Color(0xFF3B82F6),
        Color(0xFF111111),
      ][i % 5],
      delay: random.nextDouble() * 0.25,
    );
  });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_controller.value, _pieces),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.color,
    required this.delay,
  });

  final double x;
  final double speed;
  final double drift;
  final double spin;
  final Color color;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.pieces);

  final double t;
  final List<_Piece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final piece in pieces) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * piece.speed * size.height;
      final x = (piece.x + piece.drift * local) * size.width;
      paint.color = piece.color.withValues(alpha: 1 - local * 0.8);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * local);
      canvas.drawRect(const Rect.fromLTWH(-4, -2, 8, 4), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
