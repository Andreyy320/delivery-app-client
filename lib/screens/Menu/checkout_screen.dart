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
    {'id': 'online', 'label': 'Онлайн', 'icon': Icons.payment_rounded},
    {'id': 'cash', 'label': 'Наличными', 'icon': Icons.payments_outlined},
    {'id': 'card', 'label': 'Клевер', 'icon': Icons.credit_card_rounded},
    {'id': 'qr', 'label': 'QR-код', 'icon': Icons.qr_code_scanner_rounded},
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Выберите адрес доставки'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      final shopDoc = await FirebaseFirestore.instance.collection('categories').doc(widget.shopId).get();
      final String shopCategory = shopDoc.data()?['category'] ?? 'store';

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

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(category: shopCategory),
        ),
      );
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
            const SizedBox(height: 14),
            const Text(
              'Ранее использованные:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  LatLng loc = LatLng(doc['lat'], doc['lng']);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _updateRouteAndMetrics(loc),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.02),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.history_rounded, size: 14, color: Color(0xFF6366F1)),
                            SizedBox(width: 6),
                            Text(
                              'Адрес из истории',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Оформление заказа',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Доставка'),
                  const SizedBox(height: 12),

                  // БЛОК ВЫБОРА АДРЕСА И КАРТЫ
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
                      children: [
                        InkWell(
                          onTap: _pickDeliveryLocation,
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(24),
                            bottom: Radius.circular(_deliveryLocation != null ? 0 : 24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _deliveryLocation != null ? 'Адрес установлен' : 'Указать адрес на карте',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _deliveryLocation != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      if (_deliveryLocation != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '~$_estimatedMinutes мин до доставки',
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_isLoadingRoute)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 26),
                              ],
                            ),
                          ),
                        ),
                        if (_deliveryLocation != null && _restaurantLocation != null)
                          Container(
                            height: 160,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
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
                                      Polyline(points: _routePoints, strokeWidth: 4, color: const Color(0xFF6366F1)),
                                    ]),
                                  MarkerLayer(markers: [
                                    Marker(point: _restaurantLocation!, child: const Icon(Icons.store_rounded, color: Color(0xFF0F172A), size: 22)),
                                    Marker(point: _deliveryLocation!, child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF6366F1), size: 28)),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  _buildAddressHistory(),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Комментарий продавцу'),
                  const SizedBox(height: 10),
                  _buildInputField((v) => setState(() => _restaurantComment = v), 'Пожелания к упаковке, комплектации...'),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Комментарий курьеру'),
                  const SizedBox(height: 10),
                  _buildInputField((v) => setState(() => _comment = v), 'Подъезд, код домофона, этаж...'),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Способ оплаты'),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildInputField(Function(String) onChanged, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        maxLines: 2,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildPaymentGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: paymentOptions.length,
      itemBuilder: (context, index) {
        final option = paymentOptions[index];
        final selected = _selectedPayment == option['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = option['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.transparent : Colors.black.withOpacity(0.05),
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  option['icon'] as IconData,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  option['label'] as String,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
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

    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
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
                const Text('Товары:', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                Text('$displayItemsTotal Руб', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Доставка (курьеру):', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  _deliveryLocation != null ? '$displayDelivery Руб' : '—',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF6366F1)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('К ОПЛАТЕ:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                Text('$displayGrandTotal Руб', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
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
                  onPressed: _saveOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'ОФОРМИТЬ ЗАКАЗ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  final String? category;

  const OrderConfirmationScreen({super.key, this.category});

  String _getConfirmationSubtitle() {
    switch (category?.toLowerCase()) {
      case 'restaurant':
        return 'Ваш заказ уже отправлен на кухню';

      case 'svetok':
        return 'Ваш заказ передан флористу';

      case 'electronika':
        return 'Ваш заказ передан на сборку';

      case 'product':
      case 'produkti':
        return 'Ваш заказ передан в магазин';

      case 'apteka':
        return 'Ваш заказ передан в аптеку';

      default:
        return 'Ваш заказ успешно передан продавцу';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 80),
              ),
              const SizedBox(height: 28),
              const Text(
                'Заказ оформлен!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                _getConfirmationSubtitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'ВЕРНУТЬСЯ НА ГЛАВНУЮ',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Укажите место доставки',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
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
                MarkerLayer(markers: [
                  Marker(
                    point: selectedLatLng!,
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 48),
                  )
                ]),
            ],
          ),
          if (selectedLatLng != null)
            Positioned(
              bottom: 34,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, selectedLatLng),
                    child: const Text(
                      'ПОДТВЕРДИТЬ ЭТОТ АДРЕС',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8, color: Colors.white),
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