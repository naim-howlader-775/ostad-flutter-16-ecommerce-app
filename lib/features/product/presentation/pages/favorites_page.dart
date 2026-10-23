import 'package:ecommerce_app/core/router/app_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/product_provider.dart';
import '../widgets/product_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final favorites = productProvider.favoriteProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.homePath);
            }
          },
        ),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.heart,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No favorites yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart on a product to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.go(AppRouter.homePath),
                      icon: const Icon(CupertinoIcons.bag),
                      label: const Text('Browse products'),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                return ProductCard(product: favorites[index]);
              },
            ),
    );
  }
}
