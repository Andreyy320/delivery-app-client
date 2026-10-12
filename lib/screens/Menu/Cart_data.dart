import 'package:shared_preferences/shared_preferences.dart';

import '../../NEW_MODELS/User_Storage.dart';
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
  String? get selectedSizeName => selectedSize;

  // 🔹 Безопасный геттер для получения ID блюда
  String get id {
    try {
      final dynamic dishId = (dish as dynamic).id;
      if (dishId != null) return dishId.toString();
    } catch (_) {}

    try {
      if (dish is Map) {
        return (dish['id'] ?? '').toString();
      }
    } catch (_) {}

    return '';
  }

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

  // 🔹 Добавляем поддержку оператора '[]'
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
  if (itemA.dish.name.trim() != itemB.dish.name.trim()) return false;

  final sizeA = (itemA.selectedSize ?? '').trim().toLowerCase();
  final sizeB = (itemB.selectedSize ?? '').trim().toLowerCase();
  if (sizeA != sizeB) return false;

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

Future<void> clearCart(String userId, [String? shopId]) async {
  print('🗑️ [DEBUG CLEAR] === НАЧАЛО ОЧИСТКИ === для userId: $userId, shopId: $shopId');

  // 1. Очищаем оперативную память для переданного userId
  if (cartByUser.containsKey(userId)) {
    final userCarts = cartByUser[userId]!;
    if (shopId != null && userCarts.containsKey(shopId)) {
      userCarts[shopId]!.value = [];
    } else {
      userCarts.forEach((key, notifier) {
        notifier.value = [];
      });
      userCarts.clear();
    }
  }

  // 🔹 СТРАХОВКА: Проходим по всем сессиям в памяти
  cartByUser.forEach((mapKey, userCarts) {
    if (shopId != null && userCarts.containsKey(shopId)) {
      userCarts[shopId]!.value = [];
    } else {
      userCarts.forEach((key, notifier) {
        notifier.value = [];
      });
      userCarts.clear();
    }
  });

  // 🔴 ГАРАНТИЯ: Принудительно сбрасываем общую сводную корзину (shopId: null) в памяти,
  // чтобы интерфейс сразу видел пустой список и обнулял итоговую сумму.
  final combinedCart = getCart(userId, null);
  combinedCart.value = [];

  currentActiveShopId.value = null;

  // 2. Очищаем SharedPreferences (удаляем всё, что связано с этим магазином или юзером)
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.contains('cart_') && (shopId == null || key.contains('_$shopId'))) {
        await prefs.remove(key);
      }
    }
    print('🗑️ [DEBUG CLEAR] Корзина успешно удалена из SharedPreferences');
  } catch (e) {
    print('Ошибка при очистке корзины в SharedPreferences: $e');
  }

  print('🗑️ [DEBUG CLEAR] === КОНЕЦ ОЧИСТКИ. Все корзины сброшены ===');
}

void _syncCombinedCart(String userId) {
  final userCart = cartByUser[userId];

  // 🔹 Если корзина пуста или содержит только пустой null-ключ — просто обнуляем combined и выходим
  if (userCart == null || userCart.isEmpty || (userCart.length == 1 && userCart.containsKey(null))) {
    if (userCart != null && userCart.containsKey(null)) {
      userCart[null]?.value = [];
    } else {
      getCart(userId, null).value = [];
    }
    return;
  }

  final combinedItems = _combineAllCarts(userId);

  // 🔹 Дополнительная проверка: если объединенный список пуст, гарантированно очищаем
  final combinedCart = getCart(userId, null);
  if (combinedItems.isEmpty) {
    combinedCart.value = [];
  } else {
    combinedCart.value = List.from(combinedItems);
  }
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