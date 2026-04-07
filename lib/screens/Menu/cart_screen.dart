import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Cart_data.dart';
import '../../models/cart_item.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final String? shopId; // null = объединённая корзина
  final String? restaurantName; // название магазина

  const CartScreen({
    super.key,
    this.shopId,
    this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Войдите в аккаунт'));
    }
    final userId = user.uid;

    final cartNotifier = getCart(userId, shopId);

    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        // 1. Считаем сумму, используя num (он точнее работает с целыми и дробными)
        final double total = cart.fold<double>(
          0.0,
              (sum, item) {
            // Добавляем проверку, чтобы цена или количество не были null
            final price = item.dish.price ?? 0.0;
            final quantity = item.quantity ?? 0;
            return sum + (price * quantity);
          },
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Корзина'),
            backgroundColor: Colors.deepOrange,
          ),
          body: cart.isEmpty
              ? const Center(
            child: Text('Корзина пуста', style: TextStyle(fontSize: 18)),
          )
              : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              item.dish.imagePath,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.dish.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.dish.price.toStringAsFixed(0)} ₽',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  item.quantity == 1
                                      ? Icons.delete
                                      : Icons.remove,
                                  color: Colors.deepOrange,
                                ),
                                onPressed: () {
                                  if (item.quantity > 1) {
                                    item.quantity--;
                                  } else {
                                    removeFromCart(
                                        userId, shopId ?? '', item);
                                  }
                                  cartNotifier.value =
                                      List.from(cartNotifier.value);
                                },
                              ),
                              Text(item.quantity.toString(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add,
                                    color: Colors.deepOrange),
                                onPressed: () {
                                  item.quantity++;
                                  cartNotifier.value =
                                      List.from(cartNotifier.value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Секция Итого + кнопки
              Container(
                padding: const EdgeInsets.all(20), // Чуть больше отступов для солидности
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Итого сверху
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Итого', style: TextStyle(fontSize: 18, color: Colors.black)),
                        Text('${total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        // Кнопка ОТМЕНИТЬ
                        Expanded(
                          child: ElevatedButton(
                            onPressed: cart.isEmpty
                                ? null
                                : () {
                              clearCart(userId, shopId);
                              cartNotifier.value = List.from(cartNotifier.value);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200], // Светло-серый, не агрессивный
                              foregroundColor: Colors.black87,   // Цвет текста
                              elevation: 0,                      // Плоская кнопка выглядит современнее
                              minimumSize: const Size(0, 55),    // Фиксированная высота
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Отменить",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Кнопка ОФОРМИТЬ (Зеленоватая)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: cart.isEmpty
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CheckoutScreen(
                                    shopId: shopId ?? '',
                                    restaurantName: restaurantName ?? '',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange, // Красивый зеленый (Emerald)
                              foregroundColor: Colors.white,            // Белый текст
                              elevation: 2,
                              minimumSize: const Size(0, 55),           // Такая же высота!
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Оформить',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}