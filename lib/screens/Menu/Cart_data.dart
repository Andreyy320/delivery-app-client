import '../../models/dish_model.dart';
import 'package:flutter/material.dart';

class CartItem {
  final Dish dish;
  int quantity;
  final String shopId;
  final String? selectedSize;        // Поле размера
  final List<dynamic>? selectedModifiers; // Поле модификаторов

  CartItem({
    required this.dish,
    this.quantity = 1,
    required this.shopId,
    this.selectedSize,
    this.selectedModifiers,
  });

  // Удобные геттеры для совместимости со всеми возможными вариантами в UI
  List<dynamic>? get modifiers => selectedModifiers;
  List<dynamic>? get addons => selectedModifiers;
  List<dynamic>? get selectedAddons => selectedModifiers;

  // Удобный геттер для совместимости со словом size и selectedSizeName
  String? get size => selectedSize;
  String? get selectedSizeName => selectedSize; // 👈 Добавлено для полной совместимости



  // 🔹 Метод для безопасного преобразования в Map<String, dynamic>
  Map<String, dynamic> toMap() {
    return {
      'dish': dish,
      'quantity': quantity,
      'shopId': shopId,
      'selectedSize': selectedSize,
      'size': selectedSize,
      'modifiers': selectedModifiers,
      'selectedModifiers': selectedModifiers,
      'addons': selectedModifiers,
      'selectedAddons': selectedModifiers,
    };
  }

  // 🔹 Добавляем поддержку оператора '[]', чтобы старый код с item['...'] не выдавал ошибок
  dynamic operator [](String key) {
    switch (key) {
      case 'dish':
        return dish;
      case 'quantity':
        return quantity;
      case 'shopId':
        return shopId;
      case 'selectedSize':
      case 'size':
        return selectedSize;
      case 'modifiers':
      case 'selectedModifiers':
      case 'addons':
      case 'selectedAddons':
        return selectedModifiers;
      default:
        return null;
    }
  }

  /// Вспомогательный геттер для расчета стоимости одной позиции с учетом модификаторов
  double get itemTotalWithModifiers {
    double basePrice = dish.price;
    double modifiersSum = 0;

    if (selectedModifiers != null) {
      for (var mod in selectedModifiers!) {
        if (mod is Map && mod['price'] != null) {
          modifiersSum += double.tryParse(mod['price'].toString()) ?? 0.0;
        } else {
          try {
            modifiersSum += double.tryParse((mod as dynamic).price.toString()) ?? 0.0;
          } catch (_) {}
        }
      }
    }
    return (basePrice + modifiersSum) * quantity;
  }
}

ValueNotifier<String?> currentActiveShopId = ValueNotifier<String?>(null);
final Map<String, Map<String?, ValueNotifier<List<CartItem>>>> cartByUser = {};

ValueNotifier<List<CartItem>> getCart(String userId, [String? shopId]) {
  final userCart = cartByUser.putIfAbsent(userId, () => {});
  return userCart.putIfAbsent(shopId, () => ValueNotifier([]));
}

String? getExistingShopId(String userId) {
  final userCarts = cartByUser[userId];
  if (userCarts == null) return null;

  for (var entry in userCarts.entries) {
    if (entry.key != null && entry.value.value.isNotEmpty) {
      return entry.key; // Нашли магазин, в котором уже есть товары
    }
  }
  return null;
}

// 🔹 Абсолютно надежная функция сравнения товаров
bool _areDishesEqual(CartItem itemA, CartItem itemB) {
  // 1. Имя блюда должно совпадать строго
  if (itemA.dish.name.trim() != itemB.dish.name.trim()) return false;

  // 2. Сравнение размеров с нормализацией
  final sizeA = (itemA.selectedSize ?? '').trim().toLowerCase();
  final sizeB = (itemB.selectedSize ?? '').trim().toLowerCase();
  if (sizeA != sizeB) return false;

  // 3. Нормализация и сбор модификаторов в строковый массив для точного сравнения
  List<String> extractMods(List<dynamic>? mods) {
    if (mods == null || mods.isEmpty) return [];
    final list = <String>[];
    for (var m in mods) {
      String name = '';
      String price = '0';
      if (m is Map) {
        name = m['name']?.toString().trim().toLowerCase() ?? '';
        price = m['price']?.toString().trim() ?? '0';
      } else {
        try {
          name = (m as dynamic).name.toString().trim().toLowerCase();
          price = (m as dynamic).price.toString().trim();
        } catch (_) {
          name = m.toString().trim().toLowerCase();
        }
      }
      list.add('$name:$price');
    }
    list.sort();
    return list;
  }

  final modsA = extractMods(itemA.selectedModifiers);
  final modsB = extractMods(itemB.selectedModifiers);

  if (modsA.length != modsB.length) return false;

  for (int i = 0; i < modsA.length; i++) {
    if (modsA[i] != modsB[i]) return false;
  }

  return true;
}

void addToCartItem(
    String userId,
    String shopId,
    Dish dish, {
      BuildContext? context,
      String? selectedSize,
      List<dynamic>? selectedModifiers,
    }) {
  final existingShopId = getExistingShopId(userId);

  if (existingShopId != null && existingShopId != shopId) {
    if (context != null) {
      _showClearCartDialog(context, userId, shopId, dish, selectedSize: selectedSize, selectedModifiers: selectedModifiers);
    }
    return;
  }

  final cart = getCart(userId, shopId);

  final newItem = CartItem(
    dish: dish,
    shopId: shopId,
    selectedSize: selectedSize,
    selectedModifiers: selectedModifiers,
  );

  // Ищем товар с учетом имени, размера и модификаторов
  final index = cart.value.indexWhere((e) => _areDishesEqual(e, newItem));

  if (index == -1) {
    cart.value.add(newItem);
  } else {
    cart.value[index].quantity++;
  }

  cart.value = List.from(cart.value);
  currentActiveShopId.value = shopId;
  _syncCombinedCart(userId);
}

void _showClearCartDialog(
    BuildContext context,
    String userId,
    String newShopId,
    Dish dish, {
      String? selectedSize,
      List<dynamic>? selectedModifiers,
    }) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Сменить заведение?"),
      content: const Text("В корзине уже есть товары из другого места. Очистить корзину, чтобы добавить этот товар?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Отмена", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            clearCart(userId);
            Navigator.pop(context);
            addToCartItem(userId, newShopId, dish, selectedSize: selectedSize, selectedModifiers: selectedModifiers);
          },
          child: const Text("Очистить и добавить", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void removeFromCart(String userId, String shopId, CartItem item) {
  final cart = getCart(userId, shopId);
  final index = cart.value.indexWhere((e) => _areDishesEqual(e, item));

  if (index != -1) {
    if (cart.value[index].quantity > 1) {
      cart.value[index].quantity--;
    } else {
      cart.value.removeAt(index);
    }
    cart.value = List.from(cart.value);
    _syncCombinedCart(userId);
  }
}

void deleteFromCart(String userId, String shopId, CartItem item) {
  final cart = getCart(userId, shopId);
  cart.value.removeWhere((e) => _areDishesEqual(e, item));
  cart.value = List.from(cart.value);
  _syncCombinedCart(userId);
}

/// Сумма корзины с учетом (база + модификаторы) * количество
double getCartTotal(String userId, [String? shopId]) {
  if (shopId == null || shopId == "" || shopId == "null") {
    final userCarts = cartByUser[userId];
    if (userCarts == null) return 0;
    double total = 0;
    userCarts.forEach((key, notifier) {
      if (key != null) {
        for (var item in notifier.value) {
          total += item.itemTotalWithModifiers;
        }
      }
    });
    return total;
  }
  final cart = getCart(userId, shopId);
  return cart.value.fold(0, (sum, item) => sum + item.itemTotalWithModifiers);
}

void clearCart(String userId, [String? shopId]) {
  if (shopId != null) {
    getCart(userId, shopId).value = [];
  } else {
    cartByUser[userId]?.forEach((key, notifier) {
      notifier.value = [];
    });
    currentActiveShopId.value = null;
  }
  _syncCombinedCart(userId);
}

void _syncCombinedCart(String userId) {
  final combinedCart = getCart(userId, null);
  combinedCart.value = List.from(_combineAllCarts(userId));
}

List<CartItem> _combineAllCarts(String userId) {
  final userCart = cartByUser[userId];
  if (userCart == null) return [];

  final combined = <CartItem>[];
  for (var entry in userCart.entries) {
    if (entry.key == null) continue;
    for (var item in entry.value.value) {
      combined.add(CartItem(
        dish: item.dish,
        quantity: item.quantity,
        shopId: item.shopId,
        selectedSize: item.selectedSize,
        selectedModifiers: item.selectedModifiers,
      ));
    }
  }
  return combined;
}