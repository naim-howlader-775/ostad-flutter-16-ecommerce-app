import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../../cart/models/cart_item.dart';
import '../../../cart/provider/cart_provider.dart';
import '../../models/product.dart';
import '../../provider/product_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProductById(widget.productId);
    });
  }

  List<String> _galleryImages(Product product) {
    if (product.images.isNotEmpty) return product.images;
    if (product.thumbnail.isNotEmpty) return [product.thumbnail];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final product = productProvider.selectedProduct?.id == widget.productId
        ? productProvider.selectedProduct
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (product != null)
            IconButton(
              tooltip: product.isFavourite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              icon: Icon(
                product.isFavourite
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                color: product.isFavourite ? AppColors.error : null,
              ),
              onPressed: () => productProvider.toggleFavorite(product),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (product == null) {
            if (productProvider.errorMessage != null &&
                !productProvider.isLoading) {
              return Center(
                child: Text(
                  productProvider.errorMessage ?? 'Product not found',
                ),
              );
            }
            return const Center(child: CupertinoActivityIndicator());
          }

          final images = _galleryImages(product);
          final hasDiscount = product.discountPercentage > 0;
          final displayPrice = product.finalPrice;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: images.isEmpty ? 1 : images.length,
                        onPageChanged: (index) {
                          setState(() => _galleryIndex = index);
                        },
                        itemBuilder: (context, index) {
                          if (images.isEmpty) {
                            return Container(
                              color: isDark
                                  ? Colors.black38
                                  : Colors.grey.shade100,
                              child: const Center(
                                child: Icon(CupertinoIcons.photo, size: 48),
                              ),
                            );
                          }
                          return Container(
                            color: isDark
                                ? Colors.black38
                                : Colors.grey.shade100,
                            child: CustomCachedImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              iconSize: 60,
                            ),
                          );
                        },
                      ),
                      if (hasDiscount)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-${product.discountPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              final selected = index == _galleryIndex;
                              return Container(
                                width: selected ? 18 : 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white70,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                product.category.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 18,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product.rating} / 5.0',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.brand.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          product.brand,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${displayPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 10),
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                decoration: TextDecoration.lineThrough,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.availabilityStatus.isNotEmpty ||
                          product.stock > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          product.availabilityStatus.isNotEmpty
                              ? '${product.availabilityStatus} • ${product.stock} in stock'
                              : '${product.stock} in stock',
                          style: TextStyle(
                            fontSize: 13,
                            color: product.stock > 0
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (product.warrantyInformation.isNotEmpty ||
                          product.shippingInformation.isNotEmpty ||
                          product.returnPolicy.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (product.warrantyInformation.isNotEmpty)
                          _InfoRow(
                            icon: CupertinoIcons.shield,
                            label: 'Warranty',
                            value: product.warrantyInformation,
                            isDark: isDark,
                          ),
                        if (product.shippingInformation.isNotEmpty)
                          _InfoRow(
                            icon: CupertinoIcons.cube_box,
                            label: 'Shipping',
                            value: product.shippingInformation,
                            isDark: isDark,
                          ),
                        if (product.returnPolicy.isNotEmpty)
                          _InfoRow(
                            icon: CupertinoIcons.arrow_2_squarepath,
                            label: 'Returns',
                            value: product.returnPolicy,
                            isDark: isDark,
                          ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Quantity:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.minus,
                                    size: 16,
                                  ),
                                  onPressed: _quantity > 1
                                      ? () => setState(() => _quantity--)
                                      : null,
                                ),
                                Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.plus,
                                    size: 16,
                                  ),
                                  onPressed: () =>
                                      setState(() => _quantity++),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (product.reviews.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          'Reviews (${product.reviews.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...product.reviews.map(
                          (review) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review.reviewerName.isNotEmpty
                                            ? review.reviewerName
                                            : 'Customer',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: AppColors.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${review.rating}'),
                                  ],
                                ),
                                if (review.comment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    review.comment,
                                    style: TextStyle(
                                      height: 1.4,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: product == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<CartProvider>().addItem(
                      CartItem(product: product, quantity: _quantity),
                    );

                    context.push(AppRouter.cartPath);
                  },
                  icon: const Icon(CupertinoIcons.cart_badge_plus),
                  label: Text(
                    'Add to Cart • \$${(product.finalPrice * _quantity).toStringAsFixed(2)}',
                  ),
                ),
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
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
