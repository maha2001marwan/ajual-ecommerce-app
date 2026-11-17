import 'package:flutter/material.dart';

import '../core/animations/effects.dart';
import '../core/animations/motion.dart';
import '../theme/app_colors.dart';
import 'common/ui.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Appcolors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: Appcolors.secondaryText)),
          ],
        ],
      ),
    );
  }
}

/// Grid of shimmering product placeholders.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 18,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1, child: SkeletonBox()),
            SizedBox(height: 10),
            SkeletonBox(height: 12, width: 120),
            SizedBox(height: 6),
            SkeletonBox(height: 12, width: 80),
            SizedBox(height: 10),
            SkeletonBox(height: 14, width: 60),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 52, color: Appcolors.hint),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Appcolors.secondaryText),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  height: 44,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state with a gently floating illustration icon.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: staggered([
            _FloatingIcon(icon: icon),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Appcolors.secondaryText, height: 1.4),
              ),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 20), child: action!),
          ]),
        ),
      ),
    );
  }
}

class _FloatingIcon extends StatefulWidget {
  const _FloatingIcon({required this.icon});

  final IconData icon;

  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<_FloatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -8 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.08, child: child),
        );
      },
      child: Container(
        width: 108,
        height: 108,
        decoration: const BoxDecoration(
          color: Appcolors.field,
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: 46, color: Appcolors.text),
      ),
    );
  }
}
