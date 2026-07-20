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
  final Map<String, String> optionSubtitles = {
    'receiver_pay': 'Расчет при передаче курьером',
    'fragile': 'Требуется бережная транспортировка',
    'large': 'Габариты превышают стандарт',
  };
  final Map<String, IconData> optionIcons = {
    'receiver_pay': Icons.payments_outlined,
    'fragile': Icons.wine_bar_rounded,
    'large': Icons.inventory_2_outlined,
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
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
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
        if (isPickup) {
          _pickupLocation = result;
        } else {
          _dropoffLocation = result;
        }
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

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: Color(0xFFD97706)),
      ),
    );

    try {
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('delivery_orders')
          .add(orderData);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError("Ошибка сохранения: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Срочная доставка',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('МАРШРУТ ДОСТАВКИ'),
                    const SizedBox(height: 12),
                    _buildAddressCard(
                      title: 'ТОЧКА А (ОТКУДА)',
                      hint: 'Нажмите, чтобы выбрать на карте',
                      location: _pickupLocation,
                      icon: Icons.my_location_rounded,
                      iconColor: const Color(0xFF0284C7),
                      onTap: () => _pickLocation(true),
                    ),
                    const SizedBox(height: 10),
                    _buildAddressCard(
                      title: 'ТОЧКА Б (КУДА)',
                      hint: 'Нажмите, чтобы выбрать на карте',
                      location: _dropoffLocation,
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFD97706),
                      onTap: () => _pickLocation(false),
                    ),
                    if (_isCalculatingRoute)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 13, color: Color(0xFFD97706)),
                        ),
                      )
                    else if (_rawDistanceKm > 0)
                      _routeInfoTile(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('ДОПОЛНИТЕЛЬНО'),
                    const SizedBox(height: 12),
                    ...allOptions.map(_buildOptionTile).toList(),
                  ],
                ),
              ),
            ),
            _bottomPricePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _routeInfoTile() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.alt_route_rounded, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Маршрут рассчитан',
                  style: TextStyle(
                    color: Color(0xFF78350F),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${_rawDistanceKm.toStringAsFixed(1)} км',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Text('  •  ', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                    Text(
                      '~$_rawDurationMin мин.',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
  }

  Widget _buildOptionTile(String optId) {
    bool isSelected = selectedOptions.contains(optId);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? selectedOptions.remove(optId) : selectedOptions.add(optId)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFD97706).withOpacity(0.06)
                  : const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD97706).withOpacity(0.12) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                optionIcons[optId] ?? Icons.extension_outlined,
                color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    optionTitles[optId]!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                  ),
                  if (optionSubtitles[optId] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      optionSubtitles[optId]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  optionPrices[optId] == 0 ? 'Бесплатно' : '+${optionPrices[optId]} Руб',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFD97706) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPricePanel() {
    final total = _calculateTotalPrice();
    final bool canOrder = _rawDistanceKm > 0 && !_isCalculatingRoute;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding > 0 ? bottomPadding + 8 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ИТОГО К ОПЛАТЕ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${total.toInt()} Руб',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canOrder ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
              foregroundColor: canOrder ? Colors.white : const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: canOrder ? 4 : 0,
              shadowColor: const Color(0xFFD97706).withOpacity(0.3),
            ),
            onPressed: canOrder ? _goToConfirmation : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ГОТОВО',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard({
    required String title,
    required String hint,
    required LatLng? location,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: location != null ? iconColor.withOpacity(0.6) : const Color(0xFFE2E8F0),
            width: location != null ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: location != null
                  ? iconColor.withOpacity(0.05)
                  : const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    location != null
                        ? "${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}"
                        : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: location != null ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                      color: location != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            ),
          ],
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
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(46.84, 29.61),
              initialZoom: 13,
              onTap: (_, latLng) => setState(() => selectedLatLng = latLng),
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
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 45),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.pin_drop_rounded, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Выбранные координаты',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedLatLng != null
                                  ? "${selectedLatLng!.latitude.toStringAsFixed(5)}, ${selectedLatLng!.longitude.toStringAsFixed(5)}"
                                  : 'Нажмите на карту для выбора',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: selectedLatLng != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedLatLng != null ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
                      foregroundColor: selectedLatLng != null ? Colors.white : const Color(0xFF94A3B8),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: selectedLatLng != null ? 3 : 0,
                      shadowColor: const Color(0xFFD97706).withOpacity(0.3),
                    ),
                    onPressed: selectedLatLng != null ? () => Navigator.pop(context, selectedLatLng) : null,
                    child: const Text(
                      'ПОДТВЕРДИТЬ ТОЧКУ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}