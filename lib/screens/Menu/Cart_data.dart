import '../../models/dish_model.dart';
import 'package:flutter/material.dart';

class CartItem {
  final Dish dish;
  int quantity;
  final String shopId; // 🔹 добавлено

  CartItem({
    required this.dish,
    this.quantity = 1,
    required this.shopId, // 🔹 обязательное поле
  });
}

// 🔹 Карта корзин по пользователю и shopId
// null shopId → объединённая корзина всех магазинов
final Map<String, Map<String?, ValueNotifier<List<CartItem>>>> cartByUser = {};

// Получаем корзину текущего пользователя
ValueNotifier<List<CartItem>> getCart(String userId, [String? shopId]) {
  final userCart = cartByUser.putIfAbsent(userId, () => {});
  return userCart.putIfAbsent(shopId, () => ValueNotifier([]));
}

// Добавление блюда в корзину пользователя
void addToCartItem(String userId, String shopId, Dish dish) {
  final cart = getCart(userId, shopId);
  final index = cart.value.indexWhere((e) => e.dish.name == dish.name);
  if (index == -1) {
    cart.value.add(CartItem(dish: dish, shopId: shopId));
  } else {
    cart.value[index].quantity++;
  }
  cart.value = List.from(cart.value);

  // Обновляем объединённую корзину
  final combinedCart = getCart(userId, null);
  combinedCart.value = _combineAllCarts(userId);
}

// Удаление блюда с уменьшением количества
void removeFromCart(String userId, String shopId, CartItem item) {
  final cart = getCart(userId, shopId);
  final index = cart.value.indexWhere((e) => e.dish.name == item.dish.name);
  if (index != -1) {
    if (cart.value[index].quantity > 1) {
      cart.value[index].quantity--;
    } else {
      cart.value.removeAt(index);
    }
    cart.value = List.from(cart.value);
  }

  // Обновляем объединённую корзину
  final combinedCart = getCart(userId, null);
  combinedCart.value = _combineAllCarts(userId);
}

// Очистка корзины
void clearCart(String userId, [String? shopId]) {
  if (shopId != null) {
    final cart = getCart(userId, shopId);
    cart.value.clear();
    cart.value = List.from(cart.value);
  } else {
    final userCart = cartByUser[userId];
    if (userCart != null) {
      for (var c in userCart.values) {
        c.value.clear();
        c.value = List.from(c.value);
      }
    }
  }

  // Обновляем объединённую корзину
  final combinedCart = getCart(userId, null);
  combinedCart.value = _combineAllCarts(userId);
}

// 🔹 функция объединяет все корзины пользователя
List<CartItem> _combineAllCarts(String userId) {
  final userCart = cartByUser[userId];
  if (userCart == null) return [];
  final combined = <CartItem>[];
  for (var entry in userCart.entries) {
    if (entry.key == null) continue; // пропускаем объединённую корзину
    for (var item in entry.value.value) {
      final index = combined.indexWhere((e) => e.dish.name == item.dish.name);
      if (index == -1) {
        combined.add(CartItem(dish: item.dish, quantity: item.quantity, shopId: item.shopId));
      } else {
        combined[index].quantity += item.quantity;
      }
    }
  }
  return combined;
}
