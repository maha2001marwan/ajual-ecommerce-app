import 'package:flutter/material.dart';

import '../../core/animations/effects.dart';
import '../../theme/app_colors.dart';

/// Catalogue images are URLs, except a few photos bundled under `assets/`.
bool isAssetImage(String source) => source.startsWith('assets/');

/// [ImageProvider] for a catalogue image source (network URL or asset path).
ImageProvider appImageProvider(String source) =>
    isAssetImage(source) ? AssetImage(source) : NetworkImage(source);

/// Catalogue image with a shimmer placeholder, a fade-in once decoded and a
/// neutral fallback when it fails. Accepts URLs and bundled asset paths.
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 6,
    this.background = Appcolors.field,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: background,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Appcolors.hint, size: 28),
    );
    final cacheWidth = width == null || width!.isInfinite
        ? null
        : (width! * MediaQuery.devicePixelRatioOf(context)).round();
    Widget fadeIn(
      BuildContext context,
      Widget child,
      int? frame,
      bool wasSync,
    ) {
      if (wasSync) return child;
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: child,
      );
    }

    final Widget image;
    if (url.isEmpty) {
      image = fallback;
    } else if (isAssetImage(url)) {
      image = Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        frameBuilder: fadeIn,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        frameBuilder: fadeIn,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Shimmer(
            child: Container(width: width, height: height, color: background),
          );
        },
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: background, child: image),
    );
  }
}
