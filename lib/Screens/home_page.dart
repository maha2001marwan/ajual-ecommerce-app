import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/product_controller.dart';
import '../controllers/product_filter.dart';
import '../controllers/shell_controller.dart';
import '../core/animations/effects.dart';
import '../core/animations/motion.dart';
import '../data/prodcuts.dart' as seed;
import '../models/products.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/card_product.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';
import '../widgets/common/countdown.dart';
import '../widgets/common/ui.dart';
import '../widgets/state_views.dart';
import 'products/product_list_screen.dart';

/// Orange used for "70% OFF", "20% OFF" and the sale sticker in the design.
const Color _promoOrange = Color(0xFFF0440A);

/// Home (design pages 2 & 11). Banner and promo tiles are laid out on the
/// design's 375-pt grid and scaled to the screen width.
/// Animations: twinkling ✨ in the header, auto-playing banner carousel whose
/// art and copy drift apart while swiping (parallax), wobbling "50% OFF"
/// sticker, rolling flash-sale countdown, growing sold bars, staggered
/// sections, pull-to-refresh and shimmer skeletons.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProductController products = Get.find<ProductController>();
  final ShellController shell = Get.find<ShellController>();
  final ScrollController _scroll = ScrollController();
  Worker? _reselect;

  @override
  void initState() {
    super.initState();
    _reselect = ever<int>(shell.reselect, (_) {
      if (shell.tab.value == ShellTab.home && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _reselect?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openList(String title, ProductFilter filter) {
    Get.to(
      () => ProductListScreen(title: title, initialFilter: filter),
      transition: Transition.cupertino,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const _HomeHeader(),
            Expanded(
              child: RefreshIndicator(
                color: Appcolors.primary,
                onRefresh: products.refreshCatalog,
                child: Obx(() {
                  if (products.isLoading.value && products.products.isEmpty) {
                    return ListView(
                      children: const [
                        _BannerSkeleton(),
                        ProductGridSkeleton(),
                      ],
                    );
                  }
                  if (products.errorMessage.value.isNotEmpty &&
                      products.products.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        ErrorView(
                          message: products.errorMessage.value,
                          onRetry: products.retry,
                        ),
                      ],
                    );
                  }
                  return _buildContent();
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final flash = products.flashSale;
    final recent = products.recentlyViewed;
    final sections = <Widget>[
      _BannerCarousel(onOpen: _openList),
      const SizedBox(height: 14),
      _PromoRow(onOpen: _openList),
      if (flash.isNotEmpty) ...[
        const SizedBox(height: 32),
        SectionHeader(
          title: 'Flash Sale',
          trailing: Obx(
            () => CountdownBoxes(
              endsAt: products.flashSaleEndsAt.value,
              onEnd: products.flashSaleEnded,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _PagedProducts(
          products: flash,
          perPage: 2,
          rows: 1,
          extraHeight: FlashSaleCard.detailsHeight,
          itemBuilder: (product) => FlashSaleCard(product: product),
        ),
      ],
      for (final category in seed.homeSections)
        if (products.inCategory(category).isNotEmpty) ...[
          const SizedBox(height: 40),
          SectionHeader(
            title: category,
            onAction: () =>
                _openList(category, ProductFilter(category: category)),
          ),
          const SizedBox(height: 20),
          _PagedProducts(
            products: products.inCategory(category),
            perPage: 4,
            rows: 2,
            extraHeight: 112,
            itemBuilder: (product) => ProductCard(
              product: product,
              section: 'home-$category',
              showSeller: false,
            ),
          ),
        ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 40),
        SectionHeader(
          title: 'Recently Viewed',
          onAction: () => Get.toNamed(AppRoutes.recentlyViewed),
        ),
        const SizedBox(height: 14),
        _RecentlyViewedStrip(products: recent),
      ],
      const SizedBox(height: 120),
    ];

    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      children: staggered(sections, stepMs: 60),
    );
  }
}

/// Black header: "Find Your ✨ Perfect Product", cart and bell, search field,
/// over two charcoal discs in the top-right corner.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Appcolors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -50,
            right: -178,
            child: _Disc(diameter: 334, color: Color(0xFF101010)),
          ),
          const Positioned(
            top: -10,
            right: -138,
            child: _Disc(diameter: 254, color: Color(0xFF181818)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 14, 6, 12),
            child: Column(
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _HeaderTitle()),
                    CartAction(dense: true),
                    NotificationAction(dense: true),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: HeaderSearchField(
                    heroTag: 'header-search',
                    onTap: () => Get.toNamed(AppRoutes.search),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    // Always two lines as in the design; shrinks instead of wrapping on
    // narrow phones with large text.
    return const FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          text: 'Find Your ',
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _Twinkle(),
            ),
            TextSpan(text: '\nPerfect Product'),
          ],
        ),
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The ✨ next to "Find Your" pulses and tilts like a twinkling star.
class _Twinkle extends StatefulWidget {
  const _Twinkle();

  @override
  State<_Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<_Twinkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final wave = math.sin(_controller.value * math.pi * 2);
          return Opacity(
            opacity: 0.8 + 0.2 * wave.abs(),
            child: Transform.rotate(
              angle: wave * 0.18,
              child: Transform.scale(scale: 1 + 0.14 * wave, child: child),
            ),
          );
        },
        child: const Text('✨', style: TextStyle(fontSize: 19, height: 1)),
      ),
    );
  }
}

class _BannerData {
  const _BannerData({
    required this.kicker,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.image,
    required this.filter,
    this.cutout = false,
  });

  final String kicker;
  final String title;
  final String highlight;
  final String subtitle;
  final String image;
  final ProductFilter filter;

  /// True for a transparent PNG drawn over the grey disc (design slide);
  /// photos are shown in a circular frame instead.
  final bool cutout;
}

/// Auto-playing hero banners. Art and copy move at different speeds while
/// swiping, and the copy fades as its slide leaves.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.onOpen});

  final void Function(String title, ProductFilter filter) onOpen;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  static final _banners = [
    const _BannerData(
      kicker: 'Winter Big Sale! 🔥',
      title: 'Up to',
      highlight: '70% OFF',
      subtitle: 'JACKET BRANDS',
      image: 'assets/images/home/winter_jacket.png',
      cutout: true,
      filter: ProductFilter(
        category: 'Clothing & Apparel',
        subcategories: {'Jackets & Coats'},
      ),
    ),
    _BannerData(
      kicker: 'Audio Week 🎧',
      title: 'Save up to',
      highlight: '22% OFF',
      subtitle: 'WIRELESS SPEAKERS',
      image: seed.catalogImage('marshall', width: 500, height: 500),
      filter: const ProductFilter(
        category: 'Consumer Electric',
        subcategories: {'Wireless Speakers'},
      ),
    ),
    _BannerData(
      kicker: 'Tech Deals ⚡',
      title: 'Starting from',
      highlight: '\$81.99',
      subtitle: 'LAPTOPS & GAMING',
      image: seed.catalogImage('cat-laptop', width: 500, height: 500),
      filter: const ProductFilter(category: 'Computers & Technologies'),
    ),
  ];

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  /// False while another route covers the home screen.
  ValueListenable<TickerModeData>? _tickerMode;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.getValuesNotifier(context);
    precacheImage(AssetImage(_banners.first.image), context);
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      if (!(_tickerMode?.value.enabled ?? true)) return;
      final next = (_index + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = MediaQuery.sizeOf(context).width / 375;
    return Column(
      children: [
        SizedBox(
          height: 261 * u,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) _restart();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: _banners.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  var delta = 0.0;
                  if (_controller.hasClients &&
                      _controller.position.haveDimensions) {
                    delta = (_controller.page ?? 0) - index;
                  }
                  return _BannerCard(
                    data: _banners[index],
                    parallax: delta.clamp(-1.0, 1.0),
                    onTap: () => widget.onOpen(
                      _banners[index].subtitle,
                      _banners[index].filter,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DotsIndicator(
          count: _banners.length,
          index: _index,
          size: 7,
          stretch: false,
          color: const Color(0xFFE3E3E3),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.data,
    required this.parallax,
    required this.onTap,
  });

  final _BannerData data;

  /// -1..1: how far this slide is from the centre of the carousel.
  final double parallax;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = MediaQuery.sizeOf(context).width / 375;
    final fade = (1 - parallax.abs() * 1.4).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: '${data.kicker} ${data.title} ${data.highlight} ${data.subtitle}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFEFEFEF)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Grey disc behind the art (behind the model's head).
              Positioned(
                left: 207 * u + parallax * 40 * u,
                top: 17 * u,
                width: 155 * u,
                height: 155 * u,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFD9D9D9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (data.cutout)
                Positioned(
                  left: 184 * u + parallax * 90 * u,
                  bottom: 0,
                  width: 193 * u,
                  height: 244 * u,
                  child: Image.asset(
                    data.image,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                  ),
                )
              else
                Positioned(
                  left: 176 * u + parallax * 90 * u,
                  top: 64 * u,
                  width: 176 * u,
                  height: 176 * u,
                  child: Container(
                    padding: EdgeInsets.all(5 * u),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x1A000000), blurRadius: 18),
                      ],
                    ),
                    child: ClipOval(child: AppImage(data.image, radius: 0)),
                  ),
                ),
              Positioned(
                left: 16 * u,
                top: 0,
                bottom: 0,
                width: 178 * u,
                child: Opacity(
                  opacity: fade,
                  child: Transform.translate(
                    offset: Offset(parallax * 60 * u, 0),
                    // The banner has a fixed height; its type already grows
                    // with the screen width, so cap accessibility scaling.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.1,
                      child: _BannerCopy(data: data, u: u, onTap: onTap),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kicker, headline, orange highlight, subtitle and the "Shop Now" pill,
/// positioned as in the design (button bottom 34 pt above the banner edge).
class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.data, required this.u, required this.onTap});

  final _BannerData data;
  final double u;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget oneLine(String text, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 44 * u),
        oneLine(
          data.kicker,
          TextStyle(fontSize: 14 * u, color: Appcolors.text),
        ),
        SizedBox(height: 20 * u),
        oneLine(
          data.title,
          TextStyle(fontSize: 20 * u, height: 1.1, fontWeight: FontWeight.w700),
        ),
        oneLine(
          data.highlight,
          TextStyle(
            fontSize: 26 * u,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: _promoOrange,
          ),
        ),
        SizedBox(height: 10 * u),
        oneLine(
          data.subtitle,
          TextStyle(
            fontSize: 17 * u,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: 124 * u),
          child: AppButton(
            label: 'Shop Now',
            onPressed: onTap,
            height: 43 * u,
            expand: false,
          ),
        ),
        SizedBox(height: 34 * u),
      ],
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final u = MediaQuery.sizeOf(context).width / 375;
    return Shimmer(child: SkeletonBox(height: 261 * u, radius: 0));
  }
}

/// "Most Trending Accessories" and "iPhone 14 Pro" promo tiles (127 pt tall,
/// edge to edge with an 8 pt gap, as in the design).
class _PromoRow extends StatelessWidget {
  const _PromoRow({required this.onOpen});

  final void Function(String title, ProductFilter filter) onOpen;

  @override
  Widget build(BuildContext context) {
    final products = Get.find<ProductController>();
    final u = MediaQuery.sizeOf(context).width / 375;
    final iphone = products.productById('iphone-14-pro');
    return SizedBox(
      height: 127 * u,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: _promoTiles(u, iphone),
      ),
    );
  }

  Widget _promoTiles(double u, Product? iphone) {
    return Row(
      children: [
        Expanded(
          child: _PromoTile(
            color: const Color(0xFFF9F4F1),
            onTap: () => onOpen(
              'Most Trending',
              const ProductFilter(
                sort: ProductSort.popular,
                highlights: {'promotion'},
              ),
            ),
            children: [
              Positioned(
                right: 8 * u,
                top: 14 * u,
                bottom: 10 * u,
                width: 66 * u,
                child: AppImage(
                  seed.catalogImage('accessories', width: 300, height: 450),
                ),
              ),
              Positioned(
                left: 16 * u,
                top: 16 * u,
                child: Text.rich(
                  const TextSpan(
                    text: 'Most Trending\n',
                    children: [
                      TextSpan(
                        text: 'Accessories',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 13.5 * u, height: 1.4),
                ),
              ),
              Positioned(
                left: 15 * u,
                top: 58 * u,
                child: _SaleSticker(size: 45 * u),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PromoTile(
            color: const Color(0xFFF8F5EE),
            onTap: () {
              if (iphone != null) {
                openProduct(iphone, heroTag: 'promo-iphone');
              } else {
                onOpen(
                  'Phones',
                  const ProductFilter(category: 'Phones & Accessories'),
                );
              }
            },
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 14 * u,
                child: Text.rich(
                  const TextSpan(
                    text: 'Iphone 14 Pro\n',
                    children: [
                      TextSpan(
                        text: 'Discount ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '20% OFF',
                        style: TextStyle(
                          color: _promoOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5 * u, height: 1.4),
                ),
              ),
              Positioned(
                top: 56 * u,
                bottom: 8 * u,
                left: 0,
                right: 0,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.45,
                    child: Hero(
                      tag: 'promo-iphone',
                      child: AppImage(
                        iphone?.imageAt0 ??
                            seed.catalogImage(
                              'iphone',
                              width: 300,
                              height: 300,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({
    required this.color,
    required this.onTap,
    required this.children,
  });

  final Color color;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: children),
      ),
    );
  }
}

/// Orange "50% OFF" sticker over a peeking yellow disc, with a slow wobble.
class _SaleSticker extends StatefulWidget {
  const _SaleSticker({required this.size});

  final double size;

  @override
  State<_SaleSticker> createState() => _SaleStickerState();
}

class _SaleStickerState extends State<_SaleSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
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
    final disc = size * 0.66;
    return SizedBox(
      width: size + disc * 0.5,
      height: size + disc * 0.3,
      child: Stack(
        children: [
          Positioned(
            left: size * 0.52,
            top: 0,
            child: Container(
              width: disc,
              height: disc,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC145),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: disc * 0.3,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Transform.rotate(
                angle: math.sin(_controller.value * math.pi) * 0.25 - 0.12,
                child: child,
              ),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4511E),
                  shape: BoxShape.circle,
                ),
                child: Text.rich(
                  TextSpan(
                    text: '50%\n',
                    style: TextStyle(fontSize: size * 0.27),
                    children: [
                      TextSpan(
                        text: 'OFF',
                        style: TextStyle(fontSize: size * 0.17),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Products paged horizontally, [perPage] per page in [rows] rows.
class _PagedProducts extends StatefulWidget {
  const _PagedProducts({
    required this.products,
    required this.perPage,
    required this.rows,
    required this.extraHeight,
    required this.itemBuilder,
  });

  final List<Product> products;
  final int perPage;
  final int rows;
  final double extraHeight;
  final Widget Function(Product product) itemBuilder;

  @override
  State<_PagedProducts> createState() => _PagedProductsState();
}

class _PagedProductsState extends State<_PagedProducts> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant _PagedProducts oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The catalogue can shrink while this page is shown (live stream).
    final pages = (widget.products.length / widget.perPage).ceil();
    if (_page >= pages) _page = math.max(0, pages - 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = (widget.products.length / widget.perPage).ceil();
    final columns = widget.perPage ~/ widget.rows;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - 32 - spacing * (columns - 1)) / columns;
        final cardHeight = cardWidth + widget.extraHeight * textScale;
        final height = cardHeight * widget.rows + 18 * (widget.rows - 1);
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                itemCount: pages,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, page) {
                  final start = page * widget.perPage;
                  final slice = widget.products.sublist(
                    start,
                    math.min(start + widget.perPage, widget.products.length),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: 18,
                      childAspectRatio: cardWidth / cardHeight,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < slice.length; i++)
                          FadeSlideIn(
                            delay: Motion.stagger(i, stepMs: 70),
                            offset: const Offset(0.15, 0),
                            child: widget.itemBuilder(slice[i]),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            DotsIndicator(
              count: pages,
              index: _page,
              size: 7,
              stretch: false,
              color: const Color(0xFFE3E3E3),
            ),
          ],
        );
      },
    );
  }
}

class _RecentlyViewedStrip extends StatelessWidget {
  const _RecentlyViewedStrip({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          final tag = productHeroTag('recent', product);
          return PressableScale(
            onTap: () => openProduct(product, heroTag: tag),
            child: SizedBox(
              width: 96,
              child: Hero(tag: tag, child: AppImage(product.imageAt0)),
            ),
          );
        },
      ),
    );
  }
}
