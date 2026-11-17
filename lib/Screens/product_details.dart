import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/cart_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/product_filter.dart';
import '../controllers/review_controller.dart';
import '../core/animations/effects.dart';
import '../core/animations/motion.dart';
import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/formatters.dart';
import '../core/utils/money.dart';
import '../core/utils/validators.dart';
import '../models/products.dart';
import '../models/review.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/card_product.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';
import '../widgets/common/ui.dart';
import 'products/product_list_screen.dart';

/// Product details (design page 17).
/// Animations: shared-element image (Hero), gallery counter roll, heart burst,
/// fly-to-cart, price morph on variant change, quantity roll, expandable
/// description, staggered sections, bottom bar slide-in.
class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.product, this.heroTag});

  final Product product;
  final String? heroTag;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final CartController cart = Get.find<CartController>();
  final FavoritesController favorites = Get.find<FavoritesController>();
  final ProductController products = Get.find<ProductController>();
  final ReviewController reviews = Get.find<ReviewController>();

  final GlobalKey _cartKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();
  final PageController _gallery = PageController();

  int _image = 0;
  int _quantity = 1;
  late ProductOption? _option = widget.product.options.isEmpty
      ? null
      : widget.product.options.first;
  late String? _size = widget.product.sizes.isEmpty
      ? null
      : widget.product.sizes.first;
  bool _adding = false;

  /// Latest catalogue copy (prices/stock may change while open).
  Product get product =>
      products.productById(widget.product.id) ?? widget.product;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      products.markViewed(widget.product.id);
    });
  }

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  void _selectOption(ProductOption option) {
    HapticFeedback.selectionClick();
    setState(() => _option = option);
    if (_gallery.hasClients && option.imageIndex < product.images.length) {
      _gallery.animateToPage(
        option.imageIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _addToCart({bool buyNow = false}) async {
    if (_adding || !product.inStock) return;
    setState(() => _adding = true);
    try {
      if (buyNow) {
        await cart.buyNow(
          product.id,
          quantity: _quantity,
          option: _option?.name,
          size: _size,
        );
        if (mounted) Get.toNamed(AppRoutes.checkout);
      } else {
        final fly = FlyToCart.run(
          context: context,
          from: _imageKey,
          to: _cartKey,
          imageUrl: product.images.isEmpty
              ? null
              : product.images[_image < product.images.length ? _image : 0],
        );
        await cart.addProduct(
          product.id,
          quantity: _quantity,
          option: _option?.name,
          size: _size,
        );
        await fly;
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _share(String channel) {
    Clipboard.setData(
      ClipboardData(text: '${AppConfig.shareBaseUrl}${product.id}'),
    );
    AppFeedback.success('Link copied — paste it in $channel.', title: 'Share');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'Back to Shop',
        actions: [
          CartAction(key: _cartKey),
          const NotificationAction(),
        ],
      ),
      body: Obx(() {
        final p = product;
        final isFav = favorites.isFavorite(p.id);
        final price = p.priceFor(_option);
        final oldPrice = p.oldPriceFor(_option);
        final related = products.related(p);
        final together = products.boughtTogether(p);
        final recent = products.recentlyViewed
            .where((r) => r.id != p.id)
            .toList();

        final sections = <Widget>[
          _gallerySection(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Brand: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Appcolors.secondaryText,
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => Get.to(
                                    () => ProductListScreen(
                                      title: p.brand,
                                      initialFilter: ProductFilter(
                                        brands: {p.brand},
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    p.brand,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Appcolors.link,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RatingStars(rating: p.rating, count: p.reviews),
                        ],
                      ),
                    ),
                    HeartButton(
                      isFavorite: isFav,
                      onTap: () => favorites.toggleFavorite(p),
                      size: 20,
                    ),
                    IconButton(
                      tooltip: 'Compare',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => AppFeedback.demo(
                        'Product comparison is coming soon.',
                      ),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 20),
                    ),
                  ],
                ),
                const Divider(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: PriceRow(
                    key: ValueKey('$price-$oldPrice'),
                    price: price,
                    oldPrice: oldPrice,
                    size: 20,
                    showPercent: true,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    text: 'Status: ',
                    children: [
                      TextSpan(
                        text: p.inStock ? 'In Stock' : 'Out of Stock',
                        style: TextStyle(
                          color: p.inStock ? Appcolors.flash : Appcolors.sale,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                for (final feature in p.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7, right: 8),
                          child: CircleAvatar(
                            radius: 2,
                            backgroundColor: Appcolors.secondaryText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Appcolors.secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (p.options.isNotEmpty) _optionsSection(p),
          if (p.sizes.isNotEmpty) _sizesSection(p),
          _quantitySection(p),
          _metaSection(p),
          if (together != null)
            _TogetherSection(main: p, other: together, cartKey: _cartKey),
          _StoreCard(product: p),
          _DescriptionSection(product: p),
          _ReviewsSection(product: p, controller: reviews),
          if (related.isNotEmpty)
            _strip('Related Products', related, 'related'),
          if (recent.isNotEmpty)
            _strip(
              'Recently Viewed',
              recent.take(8).toList(),
              'pd-recent',
              compact: true,
            ),
          const SizedBox(height: 24),
        ];

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            sections.first,
            ...staggered(sections.sublist(1), stepMs: 60),
          ],
        );
      }),
      bottomNavigationBar: FadeSlideIn(
        delay: const Duration(milliseconds: 250),
        offset: const Offset(0, 1),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Appcolors.divider)),
          ),
          child: Obx(() {
            final inStock = product.inStock;
            return Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: inStock ? 'Add to Cart' : 'Out of Stock',
                    outlined: true,
                    height: 48,
                    loading: _adding,
                    onPressed: inStock ? () => _addToCart() : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Buy Now',
                    height: 48,
                    onPressed: inStock && !_adding
                        ? () => _addToCart(buyNow: true)
                        : null,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _gallerySection(Product p) {
    final images = p.images.isEmpty ? [''] : p.images;
    return SizedBox(
      key: _imageKey,
      height: MediaQuery.sizeOf(context).width * 0.85,
      child: Stack(
        children: [
          PageView.builder(
            controller: _gallery,
            itemCount: images.length,
            onPageChanged: (value) => setState(() => _image = value),
            itemBuilder: (context, index) {
              final image = AppImage(images[index], radius: 0);
              return index == 0 && widget.heroTag != null
                  ? Hero(tag: widget.heroTag!, child: image)
                  : image;
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RollingText(
                        '${_image + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        ' / ${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (p.discount > 0)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Appcolors.sale,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '-${p.discount}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionsSection(Product p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Color: ',
              children: [
                TextSpan(
                  text: _option?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final option = p.options[index];
                final selected = option.name == _option?.name;
                // Options without their own photo show a colour swatch rather
                // than borrowing another colour's picture.
                final hasPhoto = option.imageIndex < p.images.length;
                return PressableScale(
                  onTap: () => _selectOption(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFF8EC) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFF2A93B)
                            : Appcolors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        hasPhoto
                            ? AppImage(
                                p.images[option.imageIndex],
                                width: 44,
                                height: 44,
                                radius: 4,
                              )
                            : _ColorSwatch(hex: option.hex),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              Money.format(p.priceFor(option)),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizesSection(Product p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Size', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in p.sizes)
                PressableScale(
                  onTap: () => setState(() => _size = size),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _size == size ? Appcolors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _size == size
                            ? Appcolors.primary
                            : Appcolors.border,
                      ),
                    ),
                    child: Text(
                      size,
                      style: TextStyle(
                        fontSize: 12,
                        color: _size == size ? Colors.white : Appcolors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantitySection(Product p) {
    final max = p.stock <= 0 ? 1 : (p.stock > 99 ? 99 : p.stock);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          const Text('Quantity:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Appcolors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Decrease',
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Expanded(
                    child: Center(
                      child: RollingText(
                        _quantity.toString().padLeft(2, '0'),
                        up: true,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Increase',
                    onPressed: _quantity < max
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaSection(Product p) {
    const label = TextStyle(fontSize: 12, color: Appcolors.secondaryText);
    final channels = <(IconData, String, Color)>[
      (Icons.facebook, 'Facebook', const Color(0xFF1877F2)),
      (Icons.camera_alt_rounded, 'Instagram', const Color(0xFFE1306C)),
      (Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366)),
      (Icons.mail_outline_rounded, 'Email', Appcolors.text),
      (Icons.link_rounded, 'any app', Appcolors.text),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Category: ', style: label),
              Expanded(
                child: InkWell(
                  onTap: () => Get.to(
                    () => ProductListScreen(
                      title: p.subcategory.isEmpty ? p.category : p.subcategory,
                      initialFilter: ProductFilter(
                        category: p.category,
                        subcategories: p.subcategory.isEmpty
                            ? const {}
                            : {p.subcategory},
                      ),
                    ),
                  ),
                  child: Text(
                    p.subcategory.isEmpty ? p.category : p.subcategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Appcolors.link),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SKU: ${p.sku.isEmpty ? p.id.toUpperCase() : p.sku}',
            style: label,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final channel in channels)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: PressableScale(
                    onTap: () => _share(channel.$2),
                    child: Tooltip(
                      message: 'Share on ${channel.$2}',
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: channel.$3 == Appcolors.text
                              ? Appcolors.field
                              : channel.$3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          channel.$1,
                          size: 17,
                          color: channel.$3 == Appcolors.text
                              ? Appcolors.text
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strip(
    String title,
    List<Product> items,
    String section, {
    bool compact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
            height: compact ? 96 : 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: compact ? 96 : 150,
                child: compact
                    ? PressableScale(
                        onTap: () => openProduct(items[index]),
                        child: AppImage(items[index].imageAt0),
                      )
                    : ProductCard(
                        product: items[index],
                        section: '$section-${widget.product.id}',
                        showSeller: false,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Appcolors.field,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Color(0xFF000000 | value),
          shape: BoxShape.circle,
          border: Border.all(color: Appcolors.border),
        ),
      ),
    );
  }
}

class _TogetherSection extends StatelessWidget {
  const _TogetherSection({
    required this.main,
    required this.other,
    required this.cartKey,
  });

  final Product main;
  final Product other;
  final GlobalKey cartKey;

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    final favorites = Get.find<FavoritesController>();
    final total = main.price + other.price;
    Widget item(Product p) => Expanded(
      child: PressableScale(
        onTap: () => openProduct(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1, child: AppImage(p.imageAt0)),
            const SizedBox(height: 8),
            Text(
              p.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
            const SizedBox(height: 4),
            Text(
              Money.format(p.price),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Appcolors.divider, width: 8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frequently Bought Together',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(main),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 40, 8, 0),
                child: Icon(Icons.add, size: 18),
              ),
              item(other),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Total Price: ', style: TextStyle(fontSize: 12)),
              AnimatedNumber(
                value: total,
                format: Money.format,
                style: const TextStyle(
                  color: Appcolors.sale,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Add to wishlist',
                  outlined: true,
                  height: 42,
                  onPressed: () async {
                    for (final p in [main, other]) {
                      if (!favorites.isFavorite(p.id)) {
                        await favorites.toggleFavorite(p);
                      }
                    }
                    AppFeedback.success('Both items saved to your wishlist.');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Add to cart',
                  height: 42,
                  onPressed: () async {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null && box.attached) {
                      FlyToCart.run(
                        context: context,
                        fromRect:
                            box.localToGlobal(const Offset(16, 40)) &
                            const Size(80, 80),
                        to: cartKey,
                        imageUrl: other.imageAt0,
                      );
                    }
                    if (main.inStock) {
                      await cart.addProduct(main.id, notify: false);
                    }
                    if (other.inStock) await cart.addProduct(other.id);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    // Demo store metrics derived from the catalogue (no seller backend).
    final positive = (80 + product.rating * 3).round().clamp(0, 99);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Appcolors.field,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Appcolors.secondaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.seller.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$positive% Positive customer\'s rating',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Appcolors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                RatingStars(
                  rating: product.rating,
                  count: product.reviews * 13,
                  size: 11,
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Visit',
            height: 32,
            expand: false,
            onPressed: () => Get.to(
              () => ProductListScreen(
                title: product.seller,
                initialFilter: ProductFilter(sellers: {product.seller}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.product});

  final Product product;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  static const _bodyStyle = TextStyle(
    fontSize: 12,
    color: Appcolors.secondaryText,
    height: 1.6,
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final paragraphs = p.description
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Appcolors.divider, width: 8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const Divider(height: 24),
          if (p.features.isNotEmpty)
            Text(
              p.features.first,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final paragraph in paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(paragraph, style: _bodyStyle),
                        ),
                      if (p.images.length > 1)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: AppImage(p.images[1]),
                        ),
                    ],
                  )
                : Text(
                    paragraphs.join('\n\n'),
                    maxLines: 5,
                    overflow: TextOverflow.fade,
                    style: _bodyStyle,
                  ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(foregroundColor: Appcolors.text),
              icon: AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 260),
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              label: Text(
                _expanded ? 'Show Less' : 'Learn More',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.product, required this.controller});

  final Product product;
  final ReviewController controller;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _body = TextEditingController();
  double _rating = 0;
  int _photos = 0;
  int _shake = 0;
  late final Stream<List<Review>> _stream = widget.controller.watchProduct(
    widget.product.id,
  );

  @override
  void initState() {
    super.initState();
    final mine = widget.controller.myReviewFor(widget.product.id);
    if (mine != null) {
      _rating = mine.rating;
      _body.text = mine.body;
      _name.text = mine.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _rating < 1) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      if (_rating < 1) {
        AppFeedback.info(
          'Tap the stars to rate this product.',
          title: 'Rating needed',
        );
      }
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await widget.controller.submit(
      productId: widget.product.id,
      productName: widget.product.name,
      rating: _rating,
      name: _name.text,
      body: _body.text,
      photoCount: _photos,
    );
    if (ok && mounted) setState(() => _photos = 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return StreamBuilder<List<Review>>(
      stream: _stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Review>[];
        final total = p.reviews + list.length;
        final sum =
            p.rating * p.reviews + list.fold<double>(0, (s, r) => s + r.rating);
        final average = total == 0 ? 0.0 : sum / total;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Appcolors.divider, width: 8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reviews ($total)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedNumber(
                    value: average,
                    format: (v) => v.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 34,
                      color: Appcolors.flash,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RatingStars(rating: average, size: 16),
                        Text(
                          '$total Reviews',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Appcolors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'SUBMIT YOUR REVIEW',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Your rating of this product: ',
                    style: TextStyle(fontSize: 11),
                  ),
                  RatingInput(
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShakeX(
                trigger: _shake,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          hintText: 'Your Name',
                        ),
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Your Email Address',
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _body,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 600,
                        decoration: const InputDecoration(
                          hintText: 'Write your review ...',
                        ),
                        validator: (v) => (v ?? '').trim().length < 10
                            ? 'Write at least 10 characters'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.photo_camera_outlined,
                      label: _photos == 0
                          ? 'Add photo'
                          : '$_photos photo${_photos == 1 ? '' : 's'}',
                      onTap: () {
                        setState(() => _photos = (_photos + 1) % 4);
                        AppFeedback.demo(
                          'Photos stay on the device: uploading needs Cloud Storage (Blaze plan).',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.videocam_outlined,
                      label: 'Add video',
                      onTap: () => AppFeedback.demo(
                        'Video uploads need Cloud Storage (Blaze plan).',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Obx(
                () => AppButton(
                  label: widget.controller.myReviewFor(p.id) == null
                      ? 'Submit Review'
                      : 'Update Review',
                  height: 44,
                  loading: widget.controller.isSubmitting.value,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Top reviews',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No written reviews yet — be the first to share your thoughts.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Appcolors.secondaryText,
                    ),
                  ),
                )
              else
                for (var i = 0; i < list.length && i < 5; i++)
                  FadeSlideIn(
                    key: ValueKey(list[i].id),
                    delay: Motion.stagger(i),
                    child: _ReviewTile(review: list[i]),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Appcolors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                key: ValueKey(label),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Appcolors.field,
                child: Text(
                  review.name.isEmpty ? '?' : review.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: Appcolors.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    RatingStars(rating: review.rating, size: 11),
                  ],
                ),
              ),
              if (review.createdAt != null)
                Text(
                  DateFormats.relative(review.createdAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Appcolors.secondaryText,
                  ),
                ),
            ],
          ),
          if (review.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            review.body,
            style: const TextStyle(
              fontSize: 12,
              color: Appcolors.secondaryText,
              height: 1.5,
            ),
          ),
          if (review.photoCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${review.photoCount} photo(s) attached on device',
              style: const TextStyle(fontSize: 11, color: Appcolors.hint),
            ),
          ],
        ],
      ),
    );
  }
}
