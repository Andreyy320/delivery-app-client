import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Cart_data.dart';
import '../../models/cart_item.dart' hide CartItem;
import '../../models/cart_item.dart' as model;
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final String? shopId;
  final String? restaurantName;

  const CartScreen({
    super.key,
    this.shopId,
    this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Войдите в аккаунт')),
      );
    }

    final userId = user.uid;
    final cartNotifier = getCart(userId, shopId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Светлый фон для контраста
      appBar: AppBar(
        title: Text(
          restaurantName ?? 'Ваша корзина',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartNotifier,
        builder: (context, cart, _) {
          if (cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('В корзине пока пусто',
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return _buildCartItem(context, item, userId);
                  },
                ),
              ),
              _buildBottomSummary(context, userId, cart),
            ],
          );
        },
      ),
    );
  }

  // --- ВИДЖЕТ ЭЛЕМЕНТА КОРЗИНЫ ---
  Widget _buildCartItem(BuildContext context, CartItem item, String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Красивое изображение с тенью
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.dish.imagePath.startsWith('http')
                  ? Image.network(item.dish.imagePath, width: 85, height: 85, fit: BoxFit.cover)
                  : Image.asset(item.dish.imagePath, width: 85, height: 85, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          // Информация о товаре
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.dish.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.dish.price.toInt()} Руб',
                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ],
            ),
          ),
          // Контроллер количества (Stepper)
          Column(
            children: [
              _qtyButton(
                icon: item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                color: item.quantity == 1 ? Colors.redAccent : Colors.grey,
                onTap: () => removeFromCart(userId, item.shopId, item),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('${item.quantity}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              _qtyButton(
                icon: Icons.add,
                color: Colors.deepOrange,
                onTap: () => addToCartItem(userId, item.shopId, item.dish),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- НИЖНЯЯ ПАНЕЛЬ С ИТОГАМИ ---
  Widget _buildBottomSummary(BuildContext context, String userId, List<CartItem> cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, -10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого к оплате:',
                  style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600)),
              Text(
                '${getCartTotal(userId, shopId).toInt()} Руб',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Кнопка очистки (иконка)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  onPressed: () => clearCart(userId, shopId),
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.black54),
                  tooltip: 'Очистить корзину',
                ),
              ),
              const SizedBox(width: 12),
              // Кнопка оформления
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Colors.deepOrange, Color(0xFFFF7043)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            shopId: shopId ?? 'combined',
                            restaurantName: restaurantName ?? 'Общий заказ',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Оформить заказ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Кнопка +/- для количества
  Widget _qtyButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
