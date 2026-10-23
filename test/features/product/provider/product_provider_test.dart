import 'package:ecommerce_app/core/storage/preference_service.dart';
import 'package:ecommerce_app/features/product/data/product_repository.dart';
import 'package:ecommerce_app/features/product/models/product.dart';
import 'package:ecommerce_app/features/product/provider/product_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProductRepository implements ProductRepository {
  List<Product> products = const [
    Product(id: 1, title: 'Phone', category: 'smartphones', price: 100),
    Product(id: 2, title: 'Chair', category: 'furniture', price: 50),
  ];
  List<String> categories = const ['beauty', 'furniture'];
  bool shouldThrow = false;
  String? lastCategory;
  String? lastQuery;

  @override
  Future<List<Product>> getProducts({
    String? category,
    String? searchQuery,
  }) async {
    lastCategory = category;
    lastQuery = searchQuery;
    if (shouldThrow) throw Exception('network');
    var result = List<Product>.from(products);
    if (category != null && category.isNotEmpty && category != 'All') {
      result = result.where((p) => p.category == category).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = result
          .where(
            (p) => p.title.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }
    return result;
  }

  @override
  Future<Product> getProductById(int id) async {
    return products.firstWhere((p) => p.id == id);
  }

  @override
  Future<List<String>> getCategories() async => categories;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProductRepository repository;
  late PreferenceService preferenceService;
  late ProductProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferenceService = await PreferenceService.init();
    repository = MockProductRepository();
    provider = ProductProvider(
      productRepository: repository,
      preferenceService: preferenceService,
      autoFetch: false,
    );
  });

  tearDown(() {
    provider.dispose();
  });

  test('starts idle when autoFetch is false', () {
    expect(provider.isLoading, isFalse);
    expect(provider.products, isEmpty);
    expect(provider.errorMessage, isNull);
  });

  test('fetchProducts loads catalog and clears loading', () async {
    await provider.fetchProducts();

    expect(provider.isLoading, isFalse);
    expect(provider.products.length, 2);
    expect(provider.products.first.title, 'Phone');
    expect(provider.errorMessage, isNull);
  });

  test('fetchProducts sets errorMessage on failure', () async {
    repository.shouldThrow = true;

    await provider.fetchProducts();

    expect(provider.products, isEmpty);
    expect(provider.errorMessage, contains('network'));
    expect(provider.isLoading, isFalse);
  });

  test('search forwards query to repository', () async {
    provider.search('phone');
    // search() kicks off fetchProducts asynchronously; wait for it.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(provider.searchQuery, 'phone');
    expect(repository.lastQuery, 'phone');
  });

  test('selectCategory filters via repository category slug', () async {
    provider.selectCategory('furniture');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.lastCategory, 'furniture');
    expect(provider.selectedCategory, 'furniture');
    expect(provider.products.every((p) => p.category == 'furniture'), isTrue);
  });

  test('toggleFavorite persists and exposes favoriteProducts', () async {
    await provider.fetchProducts();
    final product = provider.products.first;

    await provider.toggleFavorite(product);

    expect(provider.isFavorite(product.id), isTrue);
    expect(provider.favoriteProducts.length, 1);
    expect(preferenceService.getFavoriteProductIds(), [product.id]);

    await provider.toggleFavorite(product);

    expect(provider.isFavorite(product.id), isFalse);
    expect(provider.favoriteProducts, isEmpty);
  });

  test('fetchCategories prepends All', () async {
    await provider.fetchCategories();

    expect(provider.categories.first, 'All');
    expect(provider.categories.contains('furniture'), isTrue);
  });
}
