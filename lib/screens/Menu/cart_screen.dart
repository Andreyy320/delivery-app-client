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
        final total = cart.fold<double>(
          0,
              (sum, item) => sum + item.dish.price * item.quantity,
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Итого сверху
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Итого', style: TextStyle(fontSize: 18)),
                        Text('${total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Оформить заказ
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
                                    restaurantName:
                                    restaurantName ?? '',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Оформить заказ',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Отменить заказ (для конкретного магазина или всей корзины)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: cart.isEmpty
                                ? null
                                : () {
                              clearCart(userId, shopId);
                              cartNotifier.value =
                                  List.from(cartNotifier.value);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Отменить",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white),
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