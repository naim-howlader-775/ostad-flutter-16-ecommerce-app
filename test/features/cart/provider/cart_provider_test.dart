import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/models/cart_item.dart';
import 'package:ecommerce_app/features/cart/models/cloud_cart_dto.dart';
import 'package:ecommerce_app/features/cart/provider/cart_provider.dart';
import 'package:ecommerce_app/features/product/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCartRepository implements CartRepository {
  List<CartItem> stored = [];
  int? cloudCartId;
  bool pending = false;
  DateTime? lastSync;

  @override
  Future<List<CartItem>> loadCart() async => List.of(stored);

  @override
  Future<void> saveCart(List<CartItem> items) async {
    stored = List.of(items);
  }

  @override
  Future<void> clearCart() async {
    stored = [];
  }

  @override
  Future<CloudCartDto?> fetchRemoteCart({required int userId}) async => null;

  @override
  Future<CloudCartDto> pushCartToCloud({
    required int userId,
    required List<CartItem> items,
  }) async =>
      CloudCartDto(
        id: 1,
        products: const [],
        total: 0,
        discountedTotal: 0,
        userId: userId,
        totalProducts: items.length,
        totalQuantity: items.fold(0, (s, i) => s + i.quantity),
      );

  @override
  Future<void> deleteCloudCart() async {}

  @override
  int? getCloudCartId() => cloudCartId;

  @override
  Future<void> setCloudCartId(int? id) async {
    cloudCartId = id;
  }

  @override
  DateTime? getLastSyncTime() => lastSync;

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    lastSync = time;
  }

  @override
  bool hasPendingSync() => pending;

  @override
  Future<void> setPendingSync(bool value) async {
    pending = value;
  }
}

void main() {
  late FakeCartRepository repository;
  late CartProvider provider;

  const productA = Product(id: 1, title: 'A', price: 10);
  const productB = Product(id: 2, title: 'B', price: 20);

  setUp(() {
    repository = FakeCartRepository();
    provider = CartProvider(cartRepository: repository, autoLoad: false);
  });

  tearDown(() {
    provider.dispose();
  });

  test('addItem appends new product and updates totals', () async {
    await provider.addItem(const CartItem(product: productA, quantity: 2));

    expect(provider.items.length, 1);
    expect(provider.itemCount, 2);
    expect(provider.subtotal, 20);
    expect(provider.tax, 20 * 0.08);
    expect(provider.total, provider.subtotal + provider.tax);
    expect(repository.stored.length, 1);
  });

  test('addItem merges quantity for existing product', () async {
    await provider.addItem(const CartItem(product: productA, quantity: 1));
    await provider.addItem(const CartItem(product: productA, quantity: 3));

    expect(provider.items.length, 1);
    expect(provider.items.first.quantity, 4);
  });

  test('updateQuantity changes quantity and removeItem clears product', () async {
    await provider.addItem(const CartItem(product: productA, quantity: 1));
    await provider.addItem(const CartItem(product: productB, quantity: 1));

    await provider.updateQuantity(1, 5);
    expect(provider.items.firstWhere((i) => i.product.id == 1).quantity, 5);

    await provider.removeItem(2);
    expect(provider.items.length, 1);
    expect(provider.items.first.product.id, 1);
  });

  test('updateQuantity to zero removes item', () async {
    await provider.addItem(const CartItem(product: productA, quantity: 2));
    await provider.updateQuantity(1, 0);

    expect(provider.items, isEmpty);
  });

  test('clearCart empties local and repository state', () async {
    await provider.addItem(const CartItem(product: productA, quantity: 1));
    await provider.clearCart();

    expect(provider.items, isEmpty);
    expect(repository.stored, isEmpty);
  });

  test('syncUser on logout clears cloud cart id', () async {
    repository.cloudCartId = 99;
    provider.syncUser(5);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    provider.syncUser(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.userId, 1);
    expect(repository.cloudCartId, isNull);
  });
}
