import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled1/screens/Menu/Cart_data.dart';
import '../../models/dish_model.dart';
import '../../models/orders_data.dart';
import '../../models/order_model.dart';


class CheckoutsScreen extends StatefulWidget {
  final String shopId;
  final Function(Order)? onOrderPlaced;
  final String restaurantName;

  const CheckoutsScreen({
    super.key,
    required this.shopId,
    this.onOrderPlaced,
    required this.restaurantName,
  });

  @override
  State<CheckoutsScreen> createState() => _CheckoutsScreenState();
}

class _CheckoutsScreenState extends State<CheckoutsScreen> {
  final MapController _mapController = MapController();

  LatLng? _deliveryLocation;
  String? _deliveryAddressName; // Название улицы/адреса для отображения
  LatLng? _restaurantLocation;
  List<LatLng> _routePoints = [];
  double _deliveryPrice = 0.0;
  int _estimatedMinutes = 0;
  double _roadDistanceKm = 0.0; // 🔹 Храним точное расстояние в км для вывода
  bool _isLoadingRoute = false;

  final String _logisticsTariff = 'Стандарт';
  final double _tariffExtraFee = 0.0;
  final bool _requiresDispatcher = false;

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

      // 1. Пробуем получить корзину для конкретного магазина
      cartNotifier = getCart(userId!, effectiveShopId);

      // 2. 🛡️ Страховка: если магазин передал пустую корзину, но в общем стейте есть товары — подтягиваем их!
      if (cartNotifier.value.isEmpty) {
        debugPrint('⚠️ Внимание: по shopId "$effectiveShopId" корзина пуста. Проверяем общую корзину...');
        cartNotifier = getCart(userId!, null); // Пробуем взять без фильтра по shopId
      }

      cartNotifier.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      cartNotifier = ValueNotifier([]);
    }
  }



  Future<void> _addToHistory(LatLng location, String addressName) async {
    if (userId == null) return;
    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('address_history');

    final existing = await historyRef.get();
    bool exists = existing.docs.any((doc) {
      double lat = (doc['lat'] as num).toDouble();
      double lng = (doc['lng'] as num).toDouble();
      return (lat - location.latitude).abs() < 0.0001 && (lng - location.longitude).abs() < 0.0001;
    });

    if (!exists) {
      await historyRef.add({
        'lat': location.latitude,
        'lng': location.longitude,
        'address': addressName, // Сохраняем текстовое название улицы
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _updateRouteAndMetrics(LatLng destination, {String? addressName}) async {
    setState(() {
      _isLoadingRoute = true;
      _deliveryLocation = destination;
      if (addressName != null) {
        _deliveryAddressName = addressName;
      }
    });

    try {
      final shopDoc = await FirebaseFirestore.instance.collection('categories').doc(widget.shopId).get();
      if (!shopDoc.exists || shopDoc.data()?['lat'] == null) {
        _restaurantLocation = const LatLng(46.8410, 29.6470);
      } else {
        _restaurantLocation = LatLng((shopDoc.data()!['lat'] as num).toDouble(), (shopDoc.data()!['lng'] as num).toDouble());
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
        _routePoints = geometry.map((coord) => LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble())).toList();

        double roadDistanceKm = (route['distance'] as num).toDouble() / 1000.0;
        double travelTimeMin = (route['duration'] as num).toDouble() / 60.0;

        // 🔹 Считаем цену через единый метод в OrdersService
        double calculatedPrice = OrdersService.calculateTaxiPrice(
          distanceKm: roadDistanceKm,
          durationMin: travelTimeMin.round(),
        );

        setState(() {
          _roadDistanceKm = roadDistanceKm;
          _deliveryPrice = calculatedPrice;
          _estimatedMinutes = travelTimeMin.round();
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
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null && result['latLng'] != null) {
      await _updateRouteAndMetrics(
        result['latLng'] as LatLng,
        addressName: result['address'] as String?,
      );
    }
  }

// 🔹 Исправленный геттер для подсчета суммы с учетом модификаторов
  double get totalItemsPrice {
    return (cartNotifier.value ?? []).fold(0.0, (acc, item) {
      // Безопасно суммируем модификаторы, если они есть и список не null
      final double modifiersPrice = (item.selectedModifiers ?? []).fold(0.0, (modAcc, mod) => modAcc + mod.price);

      // Считаем общую стоимость позиции (база + модификаторы) * количество
      double itemTotal = (item.dish.price + modifiersPrice) * item.quantity;

      return acc + itemTotal;
    });
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
      // 1. Получаем данные магазина (включая координаты, адрес и категорию) из Firestore
      final shopDoc = await FirebaseFirestore.instance.collection('categories').doc(widget.shopId).get();
      final shopData = shopDoc.data();

      final String shopCategory = shopData?['category'] ?? 'store';
      final String restaurantAddress = shopData?['address'] ?? shopData?['pickupAddress'] ?? 'Адрес заведения не указан';

      // Достаем координаты заведения (с дефолтными значениями на крайний случай)
      final double restaurantLat = (shopData?['lat'] as num?)?.toDouble() ?? 46.8410;
      final double restaurantLng = (shopData?['lng'] as num?)?.toDouble() ?? 29.6470;

      final String finalAddress = _deliveryAddressName ?? 'Точка доставки';

      // Сохраняем в историю с названием улицы
      await _addToHistory(_deliveryLocation!, finalAddress);

      double itemsPrice = totalItemsPrice.roundToDouble();
      double deliveryPrice = _deliveryPrice.roundToDouble();
      double totalOrderPrice = itemsPrice + deliveryPrice + _tariffExtraFee;

      // 2. Передаем координаты и адрес заведения вместе с заказом
      await OrdersService.addOrder(
        userId!,
        cartNotifier.value,
        restaurantName: widget.restaurantName,
        shopId: widget.shopId,
        category: shopCategory,
        type: 'standard_order',
        comment: _comment,
        restaurantComment: _restaurantComment,
        paymentMethod: _selectedPayment,
        lat: _deliveryLocation!.latitude,
        lng: _deliveryLocation!.longitude,
        address: finalAddress,
        itemsPrice: itemsPrice,
        deliveryPrice: deliveryPrice,
        totalPrice: totalOrderPrice,
        distanceKm: _roadDistanceKm,
        durationMin: _estimatedMinutes,
        restaurantAddress: restaurantAddress,
        restaurantLat: restaurantLat,
        restaurantLng: restaurantLng,
      );

      String? effectiveShopId = (widget.shopId == "" || widget.shopId == "null" || widget.shopId == "combined") ? null : widget.shopId;
      clearCart(userId!, effectiveShopId);

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

  Widget _buildTotalPanel() {
    int displayItemsTotal = totalItemsPrice.round();
    int displayDelivery = _deliveryPrice.round();
    int displayExtraFee = _tariffExtraFee.round();
    int displayGrandTotal = displayItemsTotal + displayDelivery + displayExtraFee;

    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Доставка (курьеру):', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                    if (_deliveryLocation != null)
                      Text(
                        'Расстояние: ${_roadDistanceKm.toStringAsFixed(2)} км',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                Text(
                  _deliveryLocation != null ? '$displayDelivery Руб' : '—',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF6366F1)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Тариф 15-17: ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(_logisticsTariff, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
                Text(
                  displayExtraFee > 0 ? '+$displayExtraFee Руб' : '0 Руб',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF10B981)),
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
              child: ElevatedButton(
                onPressed: _saveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Оформить заказ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  var data = doc.data() as Map<String, dynamic>;

                  LatLng loc = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());

                  String savedAddress = (data.containsKey('address') && data['address'] != null)
                      ? data['address']
                      : 'Адрес из истории';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _updateRouteAndMetrics(loc, addressName: savedAddress),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 14, color: Color(0xFFEF4444)),
                            const SizedBox(width: 6),
                            Text(
                              savedAddress,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
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
                                        _deliveryLocation != null
                                            ? (_deliveryAddressName ?? 'Адрес установлен')
                                            : 'Указать адрес на карте',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _deliveryLocation != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_deliveryLocation != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_roadDistanceKm.toStringAsFixed(1)} км • ~$_estimatedMinutes мин',
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
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _deliveryLocation!,
                                  initialZoom: 13,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
                                  ),
                                  if (_routePoints.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: _routePoints,
                                          strokeWidth: 8.5,
                                          color: const Color(0xFFD97706).withValues(alpha: 0.2),
                                        ),
                                        Polyline(
                                          points: _routePoints,
                                          strokeWidth: 4.5,
                                          color: const Color(0xFF1E293B),
                                          borderStrokeWidth: 1.5,
                                          borderColor: const Color(0xFFF59E0B),
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(markers: [
                                    Marker(
                                      point: _restaurantLocation!,
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.storefront_rounded,
                                          color: Color(0xFFF59E0B),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    Marker(
                                      point: _deliveryLocation!,
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_pin,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
                color: selected ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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


}

class OrderConfirmationScreen extends StatelessWidget {
  final String? category;

  const OrderConfirmationScreen({super.key, this.category});

  String _getConfirmationSubtitle() {
    switch (category?.toLowerCase()) {
      case 'restaurant':
        return 'Ваш заказ уже отправлен на кухню';
      case 'svetok':
        return 'Ваш заказ передан флористам';
      default:
        return 'Ваш заказ успешно оформлен';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Заказ принят!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getConfirmationSubtitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'На главную',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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


// Экран выбора точки на карте с автоматическим определением улицы (Reverse Geocoding)
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});
  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final MapController _mapController = MapController();

  LatLng? _currentCenterCoord;
  String? _resolvedAddress;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentCenterCoord = const LatLng(46.8410, 29.6470);
    _onMapPositionChanged(_currentCenterCoord!, true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Метод отслеживания движения карты с debounce (защита от частых запросов)
  void _onMapPositionChanged(LatLng center, bool isInitial) {
    setState(() {
      _currentCenterCoord = center;
      if (!isInitial) {
        _isLoadingAddress = true;
        _resolvedAddress = 'Определяем точный адрес...';
      }
    });

    if (isInitial) {
      _fetchAddressFromCoordinates(center);
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchAddressFromCoordinates(center);
      });
    }
  }

  // Метод для запроса названия улицы/адреса по координатам через OpenStreetMap Nominatim
  Future<void> _fetchAddressFromCoordinates(LatLng latLng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=ru&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterAppDeliveryOrder/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          String road = address['road'] ?? address['pedestrian'] ?? address['street'] ?? address['path'] ?? '';
          String houseNumber = address['house_number'] ?? address['building'] ?? '';
          String suburb = address['suburb'] ?? address['neighbourhood'] ?? address['city_district'] ?? '';
          String city = address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'] ?? address['county'] ?? '';

          List<String> parts = [];
          if (road.isNotEmpty) {
            if (houseNumber.isNotEmpty) {
              parts.add('$road, $houseNumber');
            } else {
              parts.add(road);
            }
          } else if (suburb.isNotEmpty) {
            parts.add(suburb);
          }

          if (city.isNotEmpty && !parts.contains(city)) {
            parts.add(city);
          }

          if (mounted) {
            setState(() {
              if (parts.isNotEmpty) {
                _resolvedAddress = parts.join(', ');
              } else {
                String rawName = data['display_name'] ?? '';
                List<String> splitName = rawName.split(', ');
                if (splitName.length > 3) splitName.removeLast();
                _resolvedAddress = splitName.isNotEmpty ? splitName.join(', ') : 'Координаты: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
              }
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _resolvedAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _resolvedAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)} (Лимит)';
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка геокодинга: $e');
      if (mounted) {
        setState(() {
          _resolvedAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

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
          // Карта с отслеживанием центра
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  _onMapPositionChanged(position.center!, false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
              ),
            ],
          ),

          // Роскошная красная/коралловая булавка строго по центру экрана с тенью
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 38), // компенсируем «ножку» иконки
              child: Icon(
                Icons.location_on_rounded,
                color: Color(0xFFEF4444), // Красивый современный красный (Red-500)
                size: 52,
              ),
            ),
          ),

          // Премиальная плашка с отображением найденной улицы сверху карты
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.place_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _resolvedAddress ?? 'Переместите карту для выбора...',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isLoadingAddress) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Роскошная кнопка подтверждения точки внизу экрана с градиентом
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: SizedBox(
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _currentCenterCoord != null
                        ? () => Navigator.pop(context, {
                      'latLng': _currentCenterCoord,
                      'address': _resolvedAddress,
                    })
                        : null,
                    child: const Text(
                      'ПОДТВЕРДИТЬ ЭТОТ АДРЕС',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
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