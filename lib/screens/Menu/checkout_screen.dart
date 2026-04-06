import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/orders_data.dart';
import '../Menu/Cart_data.dart';
import '../../models/order_model.dart';

class CheckoutScreen extends StatefulWidget {
  final String shopId; // корзина привязана к магазину
  final Function(Order)? onOrderPlaced;
  final String restaurantName;

  const CheckoutScreen({super.key, required this.shopId, this.onOrderPlaced, required this.restaurantName,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  LatLng? _deliveryLocation;
  String _comment = '';
  String _selectedPayment = 'online';

  late final ValueNotifier<List<CartItem>> cartNotifier;
  String? userId; // 🔹 для привязки к пользователю

  final paymentOptions = [
    {'id': 'online', 'label': 'Оплатить \nонлайн', 'icon': Icons.payment},
    {'id': 'cash', 'label': 'Наличными', 'icon': Icons.money},
    {'id': 'card', 'label': 'Карта \nКлевер', 'icon': Icons.credit_card},
    {'id': 'qr', 'label': 'QR', 'icon': Icons.qr_code},
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      cartNotifier = getCart(userId!, widget.shopId); // 🔹 привязка корзины к пользователю
    } else {
      cartNotifier = ValueNotifier([]);
    }
  }

  double get total =>
      cartNotifier.value.fold(0, (sum, item) => sum + item.dish.price * item.quantity);

  Future<void> _pickDeliveryLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null) setState(() => _deliveryLocation = result);
  }

  Future<void> _saveOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    if (_deliveryLocation == null || cartNotifier.value.isEmpty) return;

    try {
      // 🔹 добавляем заказ через OrdersService
      await OrdersService.addOrder(
        userId!,
        cartNotifier.value,
        restaurantName: widget.restaurantName, // название ресторана
        shopId: widget.shopId,
        comment: _comment,
        paymentMethod: _selectedPayment,
      );

      clearCart(userId!, widget.shopId); // очищаем корзину

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении заказа: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа'), backgroundColor: Colors.deepOrange),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Доставка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDeliveryLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _deliveryLocation != null
                            ? 'Широта: ${_deliveryLocation!.latitude}, Долгота: ${_deliveryLocation!.longitude}'
                            : 'Выберите адрес доставки',
                        style: TextStyle(
                            color: _deliveryLocation != null ? Colors.black : Colors.grey[600]),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Комментарий к заказу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                  hintText: 'Комментарий к заказу', border: OutlineInputBorder()),
              maxLines: 2,
              onChanged: (value) => setState(() => _comment = value),
            ),
            const SizedBox(height: 16),
            const Text('Оплата', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: paymentOptions.map((option) {
                final selected = _selectedPayment == option['id'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPayment = option['id'] as String),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: selected ? Colors.deepOrange : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: selected ? Colors.deepOrange : Colors.grey, width: 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(option['icon'] as IconData,
                                color: selected ? Colors.white : Colors.black, size: 28),
                            const SizedBox(height: 6),
                            Text(option['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: selected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('К оплате:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(0)} ₽',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveOrder,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Оформить заказ', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Остальная часть (OrderConfirmationScreen и SelectLocationScreen) без изменений


/// Экран подтверждения заказа
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white70,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/zakaz_oformlen.jpg', width: 300, height: 26),
            const SizedBox(height: 24),
            const Text('Заказ оформлен!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            const SizedBox(height: 12),
            const Text('Спасибо за ваш заказ. Курьер скоро доставит его по адресу.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              // Закрываем все до главного экрана
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбор локации на карте
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  LatLng? selectedLatLng;
  final MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите адрес'),
          backgroundColor: Colors.deepOrange),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(46.8410, 29.6470),
              initialZoom: 16,
              onTap: (tapPos, latLng) =>
                  setState(() => selectedLatLng = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(point: selectedLatLng!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                            Icons.location_on, color: Colors.red, size: 40))
                  ],
                ),
            ],
          ),
          if (selectedLatLng != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                onPressed: () => Navigator.pop(context, selectedLatLng),
                child: const Text('Выбрать этот адрес'),
              ),
            ),
        ],
      ),
    );
  }
}