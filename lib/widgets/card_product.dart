import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Screens/product_details.dart';
import '../core/animations/effects.dart';
import '../core/animations/motion.dart';
import '../models/products.dart';
import '../theme/app_colors.dart';
import 'common/app_image.dart';
import 'common/ui.dart';

/// Opens the details page; [heroTag] must be unique on the current screen.
void openProduct(Product product, {String? heroTag}) {
  Get.to(
    () => ProductDetailsPage(product: product, heroTag: heroTag),
    transition: Transition.cupertino,
    duration: const Duration(milliseconds: 380),
    preventDuplicates: false,
  );
}

String productHeroTag(String section, Product product) =>
    'product-$section-${product.id}';

/// Grid card: image, seller, name, rating, price (product listing & home).
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.section = 'grid',
    this.showSeller = true,
    this.isFavorite = false,
    this.onFavorite,
  });

  final Product product;
  final String section;
  final bool showSeller;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final tag = productHeroTag(section, product);
    return Semantics(
      button: true,
      label: '${product.name}, ${product.price}',
      child: PressableScale(
        onTap: () => openProduct(product, heroTag: tag),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: tag, child: AppImage(product.imageAt0)),
                  if (product.discount > 0)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _Tag(label: '-${product.discount}%'),
                    ),
                  if (!product.inStock)
                    const Positioned.fill(child: _SoldOutOverlay()),
                  if (onFavorite != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: HeartButton(
                        isFavorite: isFavorite,
                        onTap: onFavorite!,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (showSeller) ...[
              Text(
                product.seller.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                  color: Appcolors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            RatingStars(
              rating: product.rating,
              count: product.reviews,
              size: 11,
            ),
            const SizedBox(height: 6),
            PriceRow(
              price: product.price,
              oldPrice: product.oldPrice,
              size: 13.5,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal row used by the list view mode of product listings.
class ProductListTile extends StatelessWidget {
  const ProductListTile({
    super.key,
    required this.product,
    this.section = 'list',
  });

  final Product product;
  final String section;

  @override
  Widget build(BuildContext context) {
    final tag = productHeroTag(section, product);
    return PressableScale(
      scale: 0.98,
      onTap: () => openProduct(product, heroTag: tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Hero(tag: tag, child: AppImage(product.imageAt0)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.seller.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                      color: Appcolors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RatingStars(rating: product.rating, count: product.reviews),
                  const SizedBox(height: 8),
                  PriceRow(
                    price: product.price,
                    oldPrice: product.oldPrice,
                    showPercent: true,
                  ),
                  if (!product.inStock)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Out of stock',
                        style: TextStyle(color: Appcolors.sale, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flash-sale card with "Sold by", rating and an animated sold bar.
class FlashSaleCard extends StatelessWidget {
  const FlashSaleCard({super.key, required this.product});

  /// Height of everything below the square image (at text scale 1).
  static const double detailsHeight = 206;

  final Product product;

  @override
  Widget build(BuildContext context) {
    final tag = productHeroTag('flash', product);
    return PressableScale(
      onTap: () => openProduct(product, heroTag: tag),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Hero(tag: tag, child: AppImage(product.imageAt0, radius: 7)),
          ),
          const SizedBox(height: 20),
          // One line, shrunk if needed, so the card height stays fixed.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PriceRow(
              price: product.price,
              oldPrice: product.oldPrice,
              color: Appcolors.flash,
              size: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: 'Sold by: ',
              children: [
                TextSpan(
                  text: product.seller,
                  style: const TextStyle(color: Appcolors.link),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          RatingStars(rating: product.rating, count: product.reviews, size: 14),
          const SizedBox(height: 22),
          // Pill-shaped bar whose black fill grows to the share already sold.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: product.soldRatio),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Container(
              height: 8,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Appcolors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sold: ${product.sold}',
            style: const TextStyle(fontSize: 13, color: Appcolors.text),
          ),
        ],
      ),
    );
  }
}

/// Wishlist card with Remove and add-to-cart actions.
class WishlistCard extends StatelessWidget {
  const WishlistCard({
    super.key,
    required this.product,
    required this.onRemove,
    required this.onAddToCart,
    this.cartButtonKey,
  });

  final Product product;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;
  final GlobalKey? cartButtonKey;

  @override
  Widget build(BuildContext context) {
    final tag = productHeroTag('wish', product);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PressableScale(
          onTap: () => openProduct(product, heroTag: tag),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: tag, child: AppImage(product.imageAt0)),
                if (!product.inStock) const _SoldOutOverlay(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        PriceRow(price: product.price, oldPrice: product.oldPrice, size: 13.5),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Remove',
                outlined: true,
                height: 34,
                onPressed: onRemove,
              ),
            ),
            const SizedBox(width: 10),
            Material(
              key: cartButtonKey,
              color: product.inStock
                  ? Appcolors.primary
                  : const Color(0xFFBDBDBD),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: product.inStock ? onAddToCart : null,
                child: const SizedBox.square(
                  dimension: 34,
                  child: Icon(
                    Icons.add_shopping_cart_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Appcolors.sale,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoldOutOverlay extends StatelessWidget {
  const _SoldOutOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
        child: const Text(
          'Sold Out',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
