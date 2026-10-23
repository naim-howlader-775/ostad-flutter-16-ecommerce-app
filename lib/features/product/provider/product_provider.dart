import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/preference_service.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository productRepository;
  final PreferenceService? preferenceService;
  final bool autoFetch;

  List<Product> _products = [];
  List<String> _categories = ['All'];
  final Set<int> _favoriteIds = {};
  final Map<int, Product> _favoriteProductCache = {};
  Product? _selectedProduct;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  ProductProvider({
    required this.productRepository,
    this.preferenceService,
    this.autoFetch = true,
  }) {
    _loadFavoriteIds();
    if (autoFetch) {
      fetchProducts();
      fetchCategories();
    }
  }

  UnmodifiableListView<Product> get products =>
      UnmodifiableListView(_products.map(_withFavoriteFlag));

  UnmodifiableListView<String> get categories =>
      UnmodifiableListView(_categories);

  UnmodifiableListView<Product> get favoriteProducts {
    final fromCatalog = _products
        .where((p) => _favoriteIds.contains(p.id))
        .map(_withFavoriteFlag)
        .toList();
    final catalogIds = fromCatalog.map((p) => p.id).toSet();
    final extras = _favoriteProductCache.values
        .where((p) => _favoriteIds.contains(p.id) && !catalogIds.contains(p.id))
        .map(_withFavoriteFlag);
    return UnmodifiableListView([...fromCatalog, ...extras]);
  }

  Product? get selectedProduct =>
      _selectedProduct == null ? null : _withFavoriteFlag(_selectedProduct!);

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavorite(int productId) => _favoriteIds.contains(productId);

  void _loadFavoriteIds() {
    final ids = preferenceService?.getFavoriteProductIds() ?? const [];
    _favoriteIds
      ..clear()
      ..addAll(ids);
  }

  Product _withFavoriteFlag(Product product) =>
      product.copyWith(isFavourite: _favoriteIds.contains(product.id));

  Future<void> toggleFavorite(Product product) async {
    if (_favoriteIds.contains(product.id)) {
      _favoriteIds.remove(product.id);
      _favoriteProductCache.remove(product.id);
    } else {
      _favoriteIds.add(product.id);
      _favoriteProductCache[product.id] = product;
    }

    if (_selectedProduct?.id == product.id) {
      _selectedProduct = _withFavoriteFlag(product);
    }

    await preferenceService?.setFavoriteProductIds(_favoriteIds.toList());
    notifyListeners();
  }

  Future<void> fetchProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await productRepository.getProducts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      for (final product in _products) {
        if (_favoriteIds.contains(product.id)) {
          _favoriteProductCache[product.id] = product;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      final fetched = await productRepository.getCategories();
      if (!fetched.contains('All')) {
        _categories = ['All', ...fetched];
      } else {
        _categories = fetched;
      }
      notifyListeners();
    } catch (_) {
      // Fallback already handled in repository
    }
  }

  Future<void> fetchProductById(int id) async {
    if (_selectedProduct?.id != id) {
      _selectedProduct = _products.where((p) => p.id == id).firstOrNull;
    }

    _isLoading = _selectedProduct == null;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await productRepository.getProductById(id);
      _selectedProduct = fetched;
      if (_favoriteIds.contains(fetched.id)) {
        _favoriteProductCache[fetched.id] = fetched;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    fetchProducts();
  }

  void search(String query) {
    _searchQuery = query;
    fetchProducts();
  }

  @visibleForTesting
  void reset() {
    _products = [];
    _categories = ['All'];
    _favoriteIds.clear();
    _favoriteProductCache.clear();
    _selectedProduct = null;
    _selectedCategory = 'All';
    _searchQuery = '';
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
