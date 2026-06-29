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
  final MapController _mapController = MapController();

  LatLng? _deliveryLocation;
  LatLng? _restaurantLocation;
  List<LatLng> _routePoints = [];
  double _deliveryPrice = 0.0;
  int _estimatedMinutes = 0;
  bool _isLoadingRoute = false;

  String _comment = '';
  String _restaurantComment = '';
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
    _loadInitialData();
  }

  void _loadInitialData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      String? effectiveShopId = (widget.shopId == "" || widget.shopId == "null" || widget.shopId == "combined") ? null : widget.shopId;
      cartNotifier = getCart(userId!, effectiveShopId);
      cartNotifier.addListener(() { if (mounted) setState(() {}); });
    } else {
      cartNotifier = ValueNotifier([]);
    }
  }

  double get totalItemsPrice => cartNotifier.value.fold(0, (sum, item) => sum + item.dish.price * item.quantity);

  Future<void> _addToHistory(LatLng location) async {
    if (userId == null) return;
    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('address_history');

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

  Future<void> _updateRouteAndMetrics(LatLng destination) async {
    setState(() => _isLoadingRoute = true);
    try {
      final shopDoc = await FirebaseFirestore.instance.collection('categories').doc(widget.shopId).get();
      if (!shopDoc.exists || shopDoc.data()?['lat'] == null) {
        _restaurantLocation = const LatLng(46.8410, 29.6470);
      } else {
        _restaurantLocation = LatLng(shopDoc.data()!['lat'], shopDoc.data()!['lng']);
      }

      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
              '${_restaurantLocation!.longitude},${_restaurantLocation!.latitude};'
              '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];

        final geometry = route['geometry']['coordinates'] as List;
        _routePoints = geometry.map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())).toList();

        double roadDistanceKm = route['distance'] / 1000.0;
        double travelTimeMin = route['duration'] / 60.0;

        setState(() {
          _deliveryLocation = destination;
          _deliveryPrice = 100.0 + (roadDistanceKm * 10.0);
          _estimatedMinutes = travelTimeMin.round() + 10;
        });

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(_restaurantLocation!, _deliveryLocation!),
            padding: const EdgeInsets.all(40),
          ),
        );
      }
    } catch (e) {
      debugPrint("Ошибка маршрута: $e");
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _pickDeliveryLocation() async {
    final LatLng? result = await Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null) await _updateRouteAndMetrics(result);
  }

  Future<void> _saveOrder() async {
    if (userId == null || _deliveryLocation == null || cartNotifier.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите адрес доставки')));
      return;
    }
    try {
      final shopDoc = await FirebaseFirestore.instance.collection('categories').doc(widget.shopId).get();
      final String shopCategory = shopDoc.data()?['category'] ?? 'restaurant';

      await _addToHistory(_deliveryLocation!);

      double itemsPrice = totalItemsPrice.roundToDouble();
      double deliveryPrice = _deliveryPrice.roundToDouble();
      double totalOrderPrice = itemsPrice + deliveryPrice;

      await OrdersService.addOrder(
        userId!, cartNotifier.value,
        restaurantName: widget.restaurantName,
        shopId: widget.shopId,
        category: shopCategory,
        comment: _comment,
        restaurantComment: _restaurantComment,
        paymentMethod: _selectedPayment,
        lat: _deliveryLocation!.latitude,
        lng: _deliveryLocation!.longitude,
        itemsPrice: itemsPrice,
        deliveryPrice: deliveryPrice,
        totalPrice: totalOrderPrice,
      );

      clearCart(userId!, widget.shopId);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Widget _buildAddressHistory() {
    if (userId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('address_history')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text('Ранее использованные:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                      onPressed: () => _updateRouteAndMetrics(loc),
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
        title: const Text('Оформление заказа', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Доставка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDeliveryLocation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: _deliveryLocation != null ? const BorderRadius.vertical(top: Radius.circular(16)) : BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.deepOrange),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _deliveryLocation != null ? 'Адрес установлен' : 'Выберите адрес на карте',
                                  style: TextStyle(fontWeight: FontWeight.w500, color: _deliveryLocation != null ? Colors.black : Colors.grey),
                                ),
                                if (_deliveryLocation != null)
                                  Text('~$_estimatedMinutes мин до доставки', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (_isLoadingRoute)
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange))
                          else
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  if (_deliveryLocation != null && _restaurantLocation != null)
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _deliveryLocation!,
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'),
                            if (_routePoints.isNotEmpty)
                              PolylineLayer(polylines: [
                                Polyline(points: _routePoints, strokeWidth: 4, color: Colors.deepOrange),
                              ]),
                            MarkerLayer(markers: [
                              Marker(point: _restaurantLocation!, child: const Icon(Icons.store, color: Colors.black, size: 20)),
                              Marker(point: _deliveryLocation!, child: const Icon(Icons.person_pin_circle, color: Colors.deepOrange, size: 24)),
                            ]),
                          ],
                        ),
                      ),
                    ),

                  _buildAddressHistory(),

                  const SizedBox(height: 24),
                  const Text('Комментарий заведению', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _buildInputField((v) => setState(() => _restaurantComment = v), 'Без лука, поострее...'),

                  const SizedBox(height: 24),
                  const Text('Комментарий курьеру', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _buildInputField((v) => setState(() => _comment = v), 'Подъезд, код домофона...'),

                  const SizedBox(height: 24),
                  const Text('Оплата', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _buildPaymentGrid(),
                ],
              ),
            ),
          ),
          _buildTotalPanel(),
        ],
      ),
    );
  }

  Widget _buildInputField(Function(String) onChanged, String hint) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: TextField(
        maxLines: 2,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.all(16), hintStyle: TextStyle(color: Colors.grey.shade400)),
      ),
    );
  }

  Widget _buildPaymentGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemCount: paymentOptions.length,
      itemBuilder: (context, index) {
        final option = paymentOptions[index];
        final selected = _selectedPayment == option['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = option['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(color: selected ? Colors.deepOrange : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: selected ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 8)] : []),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(option['icon'] as IconData, color: selected ? Colors.white : Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(option['label'] as String, style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalPanel() {
    int displayItemsTotal = totalItemsPrice.round();
    int displayDelivery = _deliveryPrice.round();
    int displayGrandTotal = displayItemsTotal + displayDelivery;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Товары (заведению):', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              Text('$displayItemsTotal Руб', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Доставка (курьеру):', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              Text(_deliveryLocation != null ? '$displayDelivery Руб' : '—', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          const Divider(height: 32, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('К ОПЛАТЕ:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text('$displayGrandTotal Руб', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.deepOrange)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: _saveOrder,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              child: const Text('ОФОРМИТЬ ЗАКАЗ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 100),
              const SizedBox(height: 32),
              const Text('Заказ оформлен!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Ваш заказ уже готовится', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('ВЕРНУТЬСЯ В МЕНЮ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});
  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  LatLng? selectedLatLng;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Укажите место доставки'), centerTitle: true),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
              initialZoom: 15,
              onTap: (tapPos, latLng) => setState(() => selectedLatLng = latLng),
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'),
              if (selectedLatLng != null)
                MarkerLayer(markers: [Marker(point: selectedLatLng!, child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 45))]),
            ],
          ),
          if (selectedLatLng != null)
            Positioned(
              bottom: 40, left: 24, right: 24,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5),
                onPressed: () => Navigator.pop(context, selectedLatLng),
                child: const Text('ПОДТВЕРДИТЬ ЭТОТ АДРЕС', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
        ],
      ),
    );
  }
}
