import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/orders_data.dart';
import '../Menu/Cart_data.dart';
import '../../models/order_model.dart';

class CheckoutScreen extends StatefulWidget {
  final String shopId;
  final Function(Order)? onOrderPlaced;
  final String restaurantName;

  const CheckoutScreen({
    super.key,
    required this.shopId,
    this.onOrderPlaced,
    required this.restaurantName,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  LatLng? _deliveryLocation;
  String _comment = '';
  String _selectedPayment = 'online';

  late final ValueNotifier<List<CartItem>> cartNotifier;
  String? userId;

  final paymentOptions = [
    {'id': 'online', 'label': 'Онлайн', 'icon': Icons.payment},
    {'id': 'cash', 'label': 'Наличными', 'icon': Icons.money},
    {'id': 'card', 'label': 'Клевер', 'icon': Icons.credit_card},
    {'id': 'qr', 'label': 'QR-код', 'icon': Icons.qr_code},
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      String? effectiveShopId = (widget.shopId == "" ||
          widget.shopId == "null" ||
          widget.shopId == "combined")
          ? null
          : widget.shopId;

      cartNotifier = getCart(userId!, effectiveShopId);
      cartNotifier.addListener(() {
        if (mounted) setState(() {});
      });
    } else {
      cartNotifier = ValueNotifier([]);
    }
  }

  double get total => cartNotifier.value
      .fold(0, (sum, item) => sum + item.dish.price * item.quantity);

  Future<void> _pickDeliveryLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null) setState(() => _deliveryLocation = result);
  }

  // --- НОВАЯ ЛОГИКА: СОХРАНЕНИЕ АДРЕСА В ИСТОРИЮ ---
  Future<void> _addToHistory(LatLng location) async {
    if (userId == null) return;

    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('address_history');

    // Проверяем, нет ли уже такой точки рядом, чтобы не дублировать
    final existing = await historyRef.get();
    bool exists = existing.docs.any((doc) {
      double lat = doc['lat'];
      double lng = doc['lng'];
      return (lat - location.latitude).abs() < 0.0001 && (lng - location.longitude).abs() < 0.0001;
    });

    if (!exists) {
      await historyRef.add({
        'lat': location.latitude,
        'lng': location.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _saveOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    if (_deliveryLocation == null || cartNotifier.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите адрес доставки')));
      return;
    }

    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.shopId)
          .get();

      final String shopCategory = shopDoc.data()?['category'] ?? 'restaurant';

      // Сохраняем адрес в историю перед созданием заказа
      await _addToHistory(_deliveryLocation!);

      await OrdersService.addOrder(
        userId!,
        cartNotifier.value,
        restaurantName: widget.restaurantName,
        shopId: widget.shopId,
        category: shopCategory,
        comment: _comment,
        paymentMethod: _selectedPayment,
        lat: _deliveryLocation!.latitude,
        lng: _deliveryLocation!.longitude,
      );

      clearCart(userId!, widget.shopId);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении заказа: $e')));
    }
  }

  // --- ВИДЖЕТ ИСТОРИИ АДРЕСОВ ---
  Widget _buildAddressHistory() {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('address_history')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text('Ранее использованные:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  LatLng loc = LatLng(doc['lat'], doc['lng']);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade200),
                      label: const Text('📍 Адрес из истории'),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      onPressed: () => setState(() => _deliveryLocation = loc),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Оформление заказа',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Доставка',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDeliveryLocation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.location_on,
                                color: Colors.deepOrange),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _deliveryLocation != null
                                  ? 'Точка на карте установлена'
                                  : 'Выберите адрес на карте',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: _deliveryLocation != null
                                      ? Colors.black
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  // ВСТАВЛЯЕМ СПИСОК ИСТОРИИ
                  _buildAddressHistory(),

                  const SizedBox(height: 24),
                  const Text('Комментарий',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      maxLines: 2,
                      onChanged: (value) => setState(() => _comment = value),
                      decoration: const InputDecoration(
                        hintText: 'Подъезд, код домофона...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Оплата',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: paymentOptions.length,
                    itemBuilder: (context, index) {
                      final option = paymentOptions[index];
                      final selected = _selectedPayment == option['id'];
                      return GestureDetector(
                        onTap: () => setState(() =>
                        _selectedPayment = option['id'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color:
                            selected ? Colors.deepOrange : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: selected
                                ? [
                              BoxShadow(
                                  color: Colors.deepOrange
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(option['icon'] as IconData,
                                  color:
                                  selected ? Colors.white : Colors.grey,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                option['label'] as String,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('К оплате:',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                    Text('${total.toStringAsFixed(0)} Руб',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _saveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('ОФОРМИТЬ ЗАКАЗ',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// Код OrderConfirmationScreen и SelectLocationScreen без изменений...

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 100),
            ),
            const SizedBox(height: 32),
            const Text(
              'Заказ оформлен!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Text(
              'Спасибо! Ваш заказ принят.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('ВЕРНУТЬСЯ В МЕНЮ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SelectLocationScreen остается без изменений, как в вашем коде...
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Выбор адреса',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
              initialZoom: 16,
              onTap: (tapPos, latLng) => setState(() => selectedLatLng = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.deepOrange,
                        size: 50,
                        shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (selectedLatLng == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.touch_app_outlined, size: 18, color: Colors.deepOrange),
                    SizedBox(width: 10),
                    Text(
                      'Нажмите на карту',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

          if (selectedLatLng != null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.deepOrange, Color(0xFFFF7043)],
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.pop(context, selectedLatLng),
                  child: const Text(
                    'ПОДТВЕРДИТЬ АДРЕС',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
