import '../../models/dish_model.dart';
import 'package:flutter/material.dart';

class CartItem {
  final Dish dish;
  int quantity;
  final String shopId;

  CartItem({
    required this.dish,
    this.quantity = 1,
    required this.shopId,
  });
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

void addToCartItem(String userId, String shopId, Dish dish, {BuildContext? context}) {
  final existingShopId = getExistingShopId(userId);

  if (existingShopId != null && existingShopId != shopId) {
    if (context != null) {
      _showClearCartDialog(context, userId, shopId, dish);
    }
    return;
  }

  final cart = getCart(userId, shopId);
  final index = cart.value.indexWhere((e) => e.dish.name == dish.name);

  if (index == -1) {
    cart.value.add(CartItem(dish: dish, shopId: shopId));
  } else {
    cart.value[index].quantity++;
  }

  cart.value = List.from(cart.value);
  currentActiveShopId.value = shopId;
  _syncCombinedCart(userId);
}

void _showClearCartDialog(BuildContext context, String userId, String newShopId, Dish dish) {
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
            addToCartItem(userId, newShopId, dish);
          },
          child: const Text("Очистить и добавить", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

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
    _syncCombinedCart(userId);
  }
}

void deleteFromCart(String userId, String shopId, String dishName) {
  final cart = getCart(userId, shopId);
  cart.value.removeWhere((item) => item.dish.name == dishName);
  cart.value = List.from(cart.value);
  _syncCombinedCart(userId);
}

double getCartTotal(String userId, [String? shopId]) {
  if (shopId == null || shopId == "" || shopId == "null") {
    final userCarts = cartByUser[userId];
    if (userCarts == null) return 0;
    double total = 0;
    userCarts.forEach((key, notifier) {
      if (key != null) {
        for (var item in notifier.value) {
          total += item.dish.price * item.quantity;
        }
      }
    });
    return total;
  }
  final cart = getCart(userId, shopId);
  return cart.value.fold(0, (sum, item) => sum + (item.dish.price * item.quantity));
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
          shopId: item.shopId
      ));
    }
  }
  return combined;
}
