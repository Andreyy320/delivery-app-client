import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔹 Подключаем Firestore
import 'Cart_data.dart';
import 'checkout_screen.dart';
import '../../Api_Servicess.dart'; // Подключаем сервис API для доступа к токену

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
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            'Войдите в аккаунт',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final userId = user.uid;

    // 🔹 Умное определение правильного shopId, чтобы экран не был пустым
    String? effectiveShopId = shopId;
    if (effectiveShopId == null || effectiveShopId.isEmpty || effectiveShopId == 'null') {
      effectiveShopId = getExistingShopId(userId);
    }

    final cartNotifier = getCart(userId, effectiveShopId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          restaurantName ?? 'Ваша корзина',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartNotifier,
        builder: (context, cart, _) {
          // 🔹 Если в текущем айдишнике пусто, проверяем общую комбинированную корзину
          final combinedCart = getCart(userId, null).value;
          final displayCart = cart.isNotEmpty ? cart : combinedCart;

          if (displayCart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'В корзине пока пусто',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Выберите товары из каталога',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Используем реальный shopId первого товара для корректного удаления и чекаута
          final activeShopId = effectiveShopId ?? (displayCart.isNotEmpty ? displayCart.first.shopId : '');

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayCart.length,
                  itemBuilder: (context, index) {
                    final item = displayCart[index];
                    return _buildCartItem(context, item, userId);
                  },
                ),
              ),
              _buildBottomSummary(context, userId, displayCart, activeShopId),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, String userId) {
    final sizeName = item.selectedSize;
    final hasModifiers = item.selectedModifiers != null && item.selectedModifiers!.isNotEmpty;

    double singleItemPriceWithMods = item.dish.price;
    if (hasModifiers) {
      for (var mod in item.selectedModifiers!) {
        if (mod is Map) {
          singleItemPriceWithMods += double.tryParse(mod['price']?.toString() ?? '0') ?? 0.0;
        } else {
          try {
            singleItemPriceWithMods += double.tryParse((mod as dynamic).price.toString()) ?? 0.0;
          } catch (_) {}
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.dish.imagePath.isNotEmpty
                      ? (item.dish.imagePath.startsWith('http')
                      ? Image.network(
                    item.dish.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  )
                      : Image.asset(
                    item.dish.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ))
                      : const Icon(
                    Icons.shopping_bag_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.dish.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (sizeName != null || (item.dish.weight.isNotEmpty && item.dish.weight != '0'))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          [
                            if (sizeName != null) 'Размер: $sizeName',
                            if (item.dish.weight.isNotEmpty && item.dish.weight != '0') 'Вес: ${item.dish.weight}'
                          ].join(' • '),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (hasModifiers) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Дополнительно:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...item.selectedModifiers!.map((mod) {
                    String modName = '';
                    double modPrice = 0.0;

                    if (mod is Map) {
                      modName = mod['name']?.toString() ?? '';
                      modPrice = double.tryParse(mod['price']?.toString() ?? '0') ?? 0.0;
                    } else {
                      try {
                        modName = (mod as dynamic).name.toString();
                        modPrice = double.tryParse((mod as dynamic).price.toString()) ?? 0.0;
                      } catch (_) {
                        modName = mod.toString();
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• $modName',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (modPrice > 0)
                            Text(
                              '+${modPrice.toInt()} Руб',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(singleItemPriceWithMods * item.quantity).toInt()} Руб',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyButton(
                      icon: item.quantity == 1
                          ? Icons.delete_outline_rounded
                          : Icons.remove_rounded,
                      color: item.quantity == 1
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF0F172A),
                      bgColor: item.quantity == 1
                          ? const Color(0xFFFEF2F2)
                          : Colors.white,
                      onTap: () => removeFromCart(userId, item.shopId, item),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    _qtyButton(
                      icon: Icons.add_rounded,
                      color: const Color(0xFF0F172A),
                      bgColor: Colors.white,
                      onTap: () => addToCartItem(
                        userId,
                        item.shopId,
                        item.dish,
                        selectedSize: item.selectedSize,
                        selectedModifiers: item.selectedModifiers,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary(
      BuildContext context, String userId, List<CartItem> cart, String activeShopId) {
    final currentRestaurantName = restaurantName ?? 'Заказ из заведения';
    final double currentTotal = getCartTotal(userId, activeShopId);

    // Получаем текущий список отображаемых товаров для передачи дальше
    final combinedCart = getCart(userId, null).value;
    final displayCart = cart.isNotEmpty ? cart : combinedCart;

    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Итого к оплате:',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(
                  child: Text(
                    '${currentTotal.toInt()} Руб',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => clearCart(userId, activeShopId),
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Color(0xFF64748B),
                      size: 24,
                    ),
                    tooltip: 'Очистить корзину',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        // 🔹 Получаем токен из сервиса
                        final token = AddressApiService.authToken ?? '';

                        // Переменные координат ресторана по умолчанию (Тирасполь)
                        double resLat = 46.838444;
                        double resLng = 29.588252;

                        // 🔹 Извлекаем точные координаты заведения из коллекции categories
                        if (activeShopId.isNotEmpty) {
                          try {
                            final doc = await FirebaseFirestore.instance
                                .collection('categories')
                                .doc(activeShopId)
                                .get();

                            if (doc.exists && doc.data() != null) {
                              final data = doc.data()!;
                              if (data['lat'] != null) {
                                resLat = double.tryParse(data['lat'].toString()) ?? resLat;
                              }
                              if (data['lng'] != null) {
                                resLng = double.tryParse(data['lng'].toString()) ?? resLng;
                              }
                            }
                          } catch (e) {
                            debugPrint('Ошибка получения координат ресторана из Firestore: $e');
                          }
                        }

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                shopId: activeShopId,
                                restaurantName: currentRestaurantName,
                                apiToken: token,
                                restaurantLat: resLat,
                                restaurantLng: resLng,
                                cartItems: displayCart,       // 👈 Передаем список товаров
                                productsTotal: currentTotal,  // 👈 Передаем общую сумму товаров
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Оформить заказ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}