# Architecture Guide: Immutable Model Classes in Flutter & Dart

## 1. What is an Immutable Model Class?

An object is **immutable** when its state **cannot be modified after creation**. In Dart, this means:
- All instance variables are declared as `final`.
- The class constructor is marked `const` where possible.
- The class is annotated with `@immutable` from `package:flutter/foundation.dart`.

```dart
// ❌ MUTABLE MODEL (Risky in Flutter)
class MutableProduct {
  int id;
  String title;
  double price;

  MutableProduct({required this.id, required this.title, required this.price});
}

// Any part of your app can do this without anyone knowing:
product.price = 0.0; 
```

```dart
// ✅ IMMUTABLE MODEL (Safe & Recommended)
@immutable
class Product {
  final int id;
  final String title;
  final double price;

  const Product({
    required this.id,
    required this.title,
    required this.price,
  });
}

// product.price = 0.0; -> ❌ Compilation Error! Cannot assign to a final variable.
```

---

## 2. Why is Immutability Essential for Models like `Product` & `CartItem`?

### 1. Zero Side-Effects Across Screens
In an e-commerce application, a single `Product` instance is typically referenced in multiple places at the same time:
- The **Product Catalog** (`ProductListScreen`)
- The **Product Details View** (`ProductDetailScreen`)
- The **Shopping Cart** (`CartItem.product`)
- The **Favorites List**

If `Product` were mutable, modifying a field (e.g. `product.isFavourite = true` or `product.price = 19.99`) inside the detail view directly modifies the same in-memory object stored in the cart or catalog without notifying their respective widgets, causing **state inconsistency bugs**.

With immutable models, no component can alter data behind another component's back.

---

### 2. Reliable State Management Rebuilds (`Provider`, `Bloc`, `Riverpod`)
Flutter state managers rely on detecting state changes to trigger widget rebuilds. Most state managers and diffing algorithms check for **reference equality**:

```dart
// In a Provider or Bloc state update:
if (previousProduct != nextProduct) {
  notifyListeners(); // or emit(nextState)
}
```

If you mutate an object in-place:
```dart
product.isFavourite = true; // Mutated the same instance
print(identical(product, product)); // true!
```
Because the reference is identical, state listeners may assume nothing changed and fail to rebuild your UI. 

With an immutable model, you use `copyWith` to generate a **new instance**:
```dart
final updatedProduct = product.copyWith(isFavourite: true);
```
The state change is clean, explicit, and instantly detectable.

---

### 3. Flutter Compiler & Widget Tree Optimization (`const`)
When an immutable class has all `final` fields, its constructor can be declared `const`:

```dart
const Product(id: 1, title: 'Sample', price: 9.99);
```

- **Canonical Instances:** Dart creates only one instance in memory for identical compile-time constants.
- **Skipped Rebuilds:** When a Flutter widget tree encounters `const` child widgets constructed with `const` models, Flutter skips layout and painting calculations for that entire subtree during rebuilds.

---

### 4. Concurrency & Asynchronous Safety
Modern Flutter apps perform heavy asynchronous operations:
- Fetching data with `Dio`
- Caching data to `SharedPreferences`
- Calculating totals or processing images in background `Isolates`

When multiple asynchronous tasks read from an immutable model, **race conditions are impossible** because none of them can write to it while another is reading.

---

### 5. Collection Integrity (`Set` and `Map` Keys)
If you place objects in a `Set` or use them as keys in a `Map`, their position in the hash table depends on their `hashCode`.

If a model is mutable and you change a property that affects its `hashCode`:
```dart
final cart = <Product, int>{};
cart[product] = 1;

// If product.id could be mutated:
product.id = 999; 

// Now cart[product] returns null because the hashCode changed! The item is lost!
```
With immutable models, an object's `hashCode` remains stable for its entire lifetime.

---

## 3. Anatomy of a Production-Grade Immutable Model

Here is the blueprint used in this repository (`ecommerce_app`):

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class Product {
  // 1. All fields are final and strictly typed
  final int id;
  final String title;
  final double price;
  final bool isFavourite;
  final List<String> images;

  // 2. Const constructor with safe defaults
  const Product({
    required this.id,
    required this.title,
    this.price = 0.0,
    this.isFavourite = false,
    this.images = const [],
  });

  // 3. copyWith for immutable modifications
  Product copyWith({
    int? id,
    String? title,
    double? price,
    bool? isFavourite,
    List<String>? images,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      isFavourite: isFavourite ?? this.isFavourite,
      images: images ?? this.images,
    );
  }

  // 4. Defensive boundary deserializer
  factory Product.fromMap(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isFavourite: json['isFavourite'] as bool? ?? false,
      images: json['images'] is List
          ? (json['images'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  // 5. Serializer
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'price': price,
    'isFavourite': isFavourite,
    'images': images,
  };

  // 6. JSON string helpers
  factory Product.fromJson(String source) =>
      Product.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());

  // 7. Value / Identity Equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          other.id == id;

  @override
  int get hashCode => id.hashCode;

  // 8. Informative toString for debugging
  @override
  String toString() =>
      'Product(id: $id, title: $title, price: $price, isFavourite: $isFavourite)';
}
```

---

## 4. Key Takeaways

1. **Immutability means read-only state:** Once built, it never changes.
2. **Updates happen via copy:** Always use `copyWith(...)` to produce a updated instance.
3. **No bang (`!`) operators needed in UI:** Handle nullability and sensible defaults in `fromMap`, so your widgets work with clean, guaranteed types.
4. **Annotate with `@immutable`:** The Dart analyzer will warn you at compile-time if any mutable field is accidentally introduced.
