import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/preference_service.dart';
import '../models/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({String? category, String? searchQuery});
  Future<Product> getProductById(int id);
  Future<List<String>> getCategories();
}

class ProductRepositoryImpl implements ProductRepository {
  final DioClient dioClient;
  final PreferenceService preferenceService;

  ProductRepositoryImpl({
    required this.dioClient,
    required this.preferenceService,
  });

  @override
  Future<List<Product>> getProducts({
    String? category,
    String? searchQuery,
  }) async {
    final isUnfilteredCatalog =
        (searchQuery == null || searchQuery.trim().isEmpty) &&
        (category == null || category.isEmpty || category == 'All');

    try {
      String endpoint = ApiConstants.products;
      Map<String, dynamic> params = {};

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        endpoint = '${ApiConstants.products}/search';
        params['q'] = searchQuery.trim();
      } else if (category != null && category.isNotEmpty && category != 'All') {
        endpoint = '${ApiConstants.products}/category/$category';
      }

      final response = await dioClient.get(endpoint, queryParameters: params);
      final data = response.data;

      List<Product> products = [];
      if (data is List) {
        products = data
            .map((e) => Product.fromMap(e as Map<String, dynamic>))
            .toList();
      } else if (data is Map<String, dynamic> && data['products'] is List) {
        final List<dynamic> rawList = data['products'];
        products = rawList
            .map((item) => Product.fromMap(item as Map<String, dynamic>))
            .toList();
      }

      if (isUnfilteredCatalog && products.isNotEmpty) {
        await preferenceService.setCachedProducts(Product.encodeList(products));
      }

      return products;
    } on ApiException {
      if (isUnfilteredCatalog) {
        final cached = _readCachedProducts();
        if (cached.isNotEmpty) return cached;
      }
      throw Exception('Failed to fetch products');
    } catch (_) {
      if (isUnfilteredCatalog) {
        final cached = _readCachedProducts();
        if (cached.isNotEmpty) return cached;
      }
      throw Exception('Failed to fetch products');
    }
  }

  List<Product> _readCachedProducts() {
    final raw = preferenceService.getCachedProducts();
    if (raw == null || raw.isEmpty) return [];
    try {
      return Product.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Product> getProductById(int id) async {
    try {
      final response = await dioClient.get('${ApiConstants.products}/$id');
      if (response.data is Map<String, dynamic>) {
        return Product.fromMap(response.data as Map<String, dynamic>);
      }
      throw Exception('Product with ID $id not found');
    } catch (_) {
      final cached = _readCachedProducts();
      final match = cached.where((p) => p.id == id).firstOrNull;
      if (match != null) return match;
      throw Exception('Failed to fetch product with ID $id');
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final response = await dioClient.get(ApiConstants.productCategories);
      if (response.data is List) {
        return (response.data as List).map((e) {
          // DummyJSON category endpoint expects slug, not display name.
          if (e is Map<String, dynamic>) {
            final slug = e['slug']?.toString();
            if (slug != null && slug.isNotEmpty) return slug;
            final name = e['name']?.toString();
            if (name != null && name.isNotEmpty) {
              return name.toLowerCase().replaceAll(' ', '-');
            }
          }
          return e.toString();
        }).toList();
      }
      return ['All', 'beauty', 'fragrances', 'furniture', 'groceries'];
    } catch (_) {
      return ['All', 'beauty', 'fragrances', 'furniture', 'groceries'];
    }
  }
}
