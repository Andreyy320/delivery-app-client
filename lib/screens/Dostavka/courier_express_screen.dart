import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'order_confirmation_screen.dart';

class ExpressDeliveryScreen extends StatefulWidget {
  const ExpressDeliveryScreen({super.key});

  @override
  State<ExpressDeliveryScreen> createState() => _ExpressDeliveryScreenState();
}

class _ExpressDeliveryScreenState extends State<ExpressDeliveryScreen> {
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  Set<String> selectedOptions = {};

  double _rawDistanceKm = 0.0;
  int _rawDurationMin = 0;
  bool _isCalculatingRoute = false;

  final List<String> allOptions = ['receiver_pay', 'fragile', 'large'];
  final Map<String, String> optionTitles = {
    'receiver_pay': 'Оплатит получатель',
    'fragile': 'Хрупкий груз',
    'large': 'Крупный габарит',
  };
  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 50,
    'large': 100,
  };

  Future<void> _getRouteMetrics() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    setState(() {
      _isCalculatingRoute = true;
      _rawDistanceKm = 0.0;
    });

    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${_pickupLocation!.longitude},${_pickupLocation!.latitude};'
            '${_dropoffLocation!.longitude},${_dropoffLocation!.latitude}'
            '?overview=full&geometries=geojson&annotations=true');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          setState(() {
            _rawDistanceKm = route['distance'] / 1000.0;
            _rawDurationMin = (route['duration'] / 60.0).round();
          });
        }
      }
    } catch (e) {
      _showError("Проблема с расчетом пути");
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  double _calculateRoadPrice() {
    double base = 150.0;
    double kmRate = 25.0;
    return base + (_rawDistanceKm * kmRate);
  }

  double _calculateTotalPrice() {
    double roadPrice = _calculateRoadPrice();
    double optionsCost = 0;
    for (var opt in selectedOptions) {
      optionsCost += optionPrices[opt] ?? 0;
    }
    return roadPrice + optionsCost;
  }

  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null) {
      setState(() {
        if (isPickup) _pickupLocation = result;
        else _dropoffLocation = result;
      });
      _getRouteMetrics();
    }
  }

  Future<void> _goToConfirmation() async {
    if (_pickupLocation == null || _dropoffLocation == null || _rawDistanceKm == 0) {
      _showError('Сначала постройте маршрут');
      return;
    }

    final bool? confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpressOrderConfirmationScreen(
          pickup: _pickupLocation!,
          dropoff: _dropoffLocation!,
          options: selectedOptions,
          totalCost: _calculateTotalPrice(),
          distanceKm: _rawDistanceKm,
          durationMin: _rawDurationMin,
        ),
      ),
    );

    if (confirmed == true) {
      _finalSaveToFirebase();
    }
  }

  Future<void> _finalSaveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Показываем индикатор сразу
    showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 15))
    );

    try {
      // 1. Получаем данные пользователя максимально быстро (Source.serverAndCache)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      final userData = userDoc.data() ?? {};
      final String clientName = userData['name'] ?? 'Не указано';
      final String clientPhone = userData['phone'] ?? 'Не указано';

      final roadPrice = _calculateRoadPrice();
      final totalCost = _calculateTotalPrice();

      final orderData = {
        'pickup': {'lat': _pickupLocation!.latitude, 'lng': _pickupLocation!.longitude},
        'dropoff': {'lat': _dropoffLocation!.latitude, 'lng': _dropoffLocation!.longitude},
        'distance_km': double.parse(_rawDistanceKm.toStringAsFixed(2)),
        'duration_min': _rawDurationMin,
        'options': selectedOptions.toList(),
        'roadPrice': roadPrice.toInt(),
        'totalCost': totalCost.toInt(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'type': 'delivery',
      };

      // 2. Сохраняем в коллекцию
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('delivery_orders')
          .add(orderData);

      // Закрываем диалог и экран
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Убираем лоадер
        Navigator.pop(context); // Уходим с экрана заказа
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError("Ошибка сохранения: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Срочная доставка',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
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
                  _buildAddressCard(
                    title: 'ТОЧКА А (ОТКУДА)',
                    hint: 'Нажмите, чтобы выбрать на карте',
                    location: _pickupLocation,
                    icon: Icons.circle_outlined,
                    iconColor: Colors.blue,
                    onTap: () => _pickLocation(true),
                  ),
                  const SizedBox(height: 12),
                  _buildAddressCard(
                    title: 'ТОЧКА Б (КУДА)',
                    hint: 'Нажмите, чтобы выбрать на карте',
                    location: _dropoffLocation,
                    icon: Icons.location_on,
                    iconColor: Colors.deepOrange,
                    onTap: () => _pickLocation(false),
                  ),
                  if (_isCalculatingRoute)
                    const Padding(padding: EdgeInsets.only(top: 25), child: Center(child: CupertinoActivityIndicator(radius: 15)))
                  else if (_rawDistanceKm > 0)
                    _routeInfoTile(),
                  const SizedBox(height: 32),
                  const Text('ДОПОЛНИТЕЛЬНО', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  ...allOptions.map(_buildOptionTile).toList(),
                ],
              ),
            ),
          ),
          _bottomPricePanel(),
        ],
      ),
    );
  }

  Widget _routeInfoTile() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.blue.withOpacity(0.15))),
      child: Row(children: [
        const Icon(Icons.navigation_rounded, color: Colors.blue, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text('Дистанция по дорогам: ${_rawDistanceKm.toStringAsFixed(1)} км\nПримерное время: ~$_rawDurationMin мин.', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w800, fontSize: 14))),
      ]),
    );
  }

  Widget _buildOptionTile(String optId) {
    bool isSelected = selectedOptions.contains(optId);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? selectedOptions.remove(optId) : selectedOptions.add(optId)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: isSelected ? Colors.deepOrange : Colors.transparent, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Row(children: [
          Icon(isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline, color: isSelected ? Colors.deepOrange : Colors.grey[400]),
          const SizedBox(width: 14),
          Expanded(child: Text(optionTitles[optId]!, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('+${optionPrices[optId]} Руб', style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Widget _bottomPricePanel() {
    final total = _calculateTotalPrice();
    final bool canOrder = _rawDistanceKm > 0 && !_isCalculatingRoute;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(35)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('ИТОГО К ОПЛАТЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)),
            Text('${total.toInt()} Руб', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          ]),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: canOrder ? 5 : 0),
            onPressed: canOrder ? _goToConfirmation : null,
            child: const Text('ГОТОВО', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard({required String title, required String hint, required LatLng? location, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(location != null ? "${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}" : hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: location != null ? Colors.black : Colors.black26)),
          ])),
          const Icon(Icons.map_rounded, color: Colors.black12, size: 22),
        ]),
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
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(46.84, 29.61),
            initialZoom: 13,
            onTap: (_, latLng) => setState(() => selectedLatLng = latLng),
          ),
          children: [
            TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
            if (selectedLatLng != null) MarkerLayer(markers: [Marker(point: selectedLatLng!, width: 80, height: 80, child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 45))]),
          ],
        ),
        Positioned(bottom: 40, left: 25, right: 25, child: AnimatedOpacity(duration: const Duration(milliseconds: 300), opacity: selectedLatLng == null ? 0.5 : 1.0, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 65), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), elevation: 10),
          onPressed: selectedLatLng != null ? () => Navigator.pop(context, selectedLatLng) : null,
          child: const Text('ПОДТВЕРДИТЬ ТОЧКУ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ))),
      ]),
    );
  }
}