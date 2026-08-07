import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../Api_Servicess.dart';
import '../../models/Search_adress_individ.dart';

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../Api_Servicess.dart';
import '../../models/Search_adress_individ.dart';

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../Api_Servicess.dart';
import '../../models/Search_adress_individ.dart';

class ExpressDeliveryScreen extends StatefulWidget {
  const ExpressDeliveryScreen({super.key});

  @override
  State<ExpressDeliveryScreen> createState() => _ExpressDeliveryScreenState();
}

class _ExpressDeliveryScreenState extends State<ExpressDeliveryScreen> {
  String _selectedTaskType = 'buy'; // 'pickup', 'buy', 'task'

  int? _selectedTownId;
  String _selectedTownName = 'Загрузка города...';

  // Для отправления
  final TextEditingController _pickupController = TextEditingController();
  int? _pickupAddressId;
  LatLng? _pickupLocation;

  // Для назначения
  final TextEditingController _dropoffController = TextEditingController();
  int? _dropoffAddressId;
  LatLng? _dropoffLocation;

  // Описание заказа
  final TextEditingController _descriptionController = TextEditingController();

  double _rawDistanceKm = 0.0;
  int _rawDurationMin = 0;
  double _apiRoutePrice = 200.0;
  bool _isCalculatingRoute = false;

  // Список точек для отрисовки линии маршрута
  List<LatLng> _routePoints = [];

  static const Color _bgMain = Color(0xFFF4F5F7);
  static const Color _cardSurface = Colors.white;
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _initTown();
  }

  Future<void> _initTown() async {
    try {
      await AddressApiService.auth();
      final towns = await AddressApiService.getTowns();
      if (towns.isNotEmpty && mounted) {
        setState(() {
          _selectedTownId = towns[0]['id'] ?? towns[0]['townId'];
          _selectedTownName = towns[0]['name'] ?? 'Город';
        });
        debugPrint('🌍 Town initialized: ID = $_selectedTownId, Name = $_selectedTownName');
      } else {
        setState(() {
          _selectedTownName = 'Город не найден';
        });
      }
    } catch (e) {
      debugPrint('💥 Town init error: $e');
      if (mounted) {
        setState(() {
          _selectedTownName = 'Ошибка загрузки';
        });
      }
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Метод расчета финальной стоимости по вашей логике для ВСЕХ типов заданий
  double _calculateFinalPrice() {
    // Тариф таксометра: старт 18 р. + 6.15 р. за каждый км
    const double baseFare = 18.0;
    const double perKmRate = 6.15;

    double calculatedByMeter = baseFare + (_rawDistanceKm * perKmRate);

    // Если по таксометру вышло меньше 45 рублей, ставим минимум 45 рублей
    if (calculatedByMeter < 45.0) {
      return 45.0;
    }
    return calculatedByMeter;
  }

  Future<void> _pickLocationFromMap(bool isPickup) async {
    final MapPickerResult? result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: isPickup ? (_selectedTaskType == 'buy' ? 'Где купить?' : 'Откуда') : 'Куда',
          initialCenter: isPickup ? _pickupLocation : _dropoffLocation,
          townId: _selectedTownId,
          isPickupMarker: isPickup,
        ),
      ),
    );

    if (result == null) return;

    debugPrint('📍 Location selected from map [isPickup: $isPickup]:');
    debugPrint('   - LatLng: ${result.latLng}');
    debugPrint('   - Address Name: ${result.addressName}');
    debugPrint('   - Address ID: ${result.addressId}');

    setState(() {
      if (isPickup) {
        _pickupLocation = result.latLng;
        _pickupController.text = result.addressName;
        _pickupAddressId = result.addressId;
      } else {
        _dropoffLocation = result.latLng;
        _dropoffController.text = result.addressName;
        _dropoffAddressId = result.addressId;
      }
    });

    if (_pickupAddressId != null && _dropoffAddressId != null) {
      _calculateApiRoute();
    }
  }

  Future<void> _openManualSearch(bool isPickup) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const IndividualAddressScreen(),
      ),
    );

    if (result != null) {
      final String addressName = result['name'] ?? result['street'] ?? result['address'] ?? '';
      final int? addressId = result['id'] is int ? result['id'] : int.tryParse(result['id'].toString());

      if (addressName.isNotEmpty) {
        setState(() {
          if (isPickup) {
            _pickupController.text = addressName;
            _pickupAddressId = addressId;
          } else {
            _dropoffController.text = addressName;
            _dropoffAddressId = addressId;
          }
        });

        if (_pickupAddressId != null && _dropoffAddressId != null) {
          _calculateApiRoute();
        }
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;

      if (latitude.abs() > 90.0 || longitude.abs() > 180.0) {
        latitude = lat / 1E6;
        longitude = lng / 1E6;
      }

      if (latitude.abs() <= 90.0 && longitude.abs() <= 180.0) {
        points.add(LatLng(latitude, longitude));
      }
    }
    return points;
  }

  Future<void> _calculateApiRoute() async {
    if (_pickupAddressId == null || _dropoffAddressId == null) return;

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      debugPrint('🚗 Calculating route between IDs: pickup=$_pickupAddressId, dropoff=$_dropoffAddressId');

      final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final routeResult = await AddressApiService.getRoute(
        groupId: 328,
        time: currentTime,
        addressIds: [_pickupAddressId!, _dropoffAddressId!],
      );

      debugPrint('🚗 Route result response: $routeResult');

      if (routeResult != null && mounted) {
        final String? geometryStr = routeResult['geometry'];
        List<LatLng> decodedPoints = [];
        if (geometryStr != null && geometryStr.isNotEmpty) {
          decodedPoints = _decodePolyline(geometryStr);
        }

        setState(() {
          _apiRoutePrice = (routeResult['price'] ?? 200.0).toDouble();
          final dist = routeResult['distance'] ?? 0;
          _rawDistanceKm = dist is int ? dist / 1000.0 : (dist is double ? dist : 3.5);

          final dur = routeResult['time'] ?? routeResult['duration'] ?? 600;
          _rawDurationMin = (dur is int ? dur : int.tryParse(dur.toString()) ?? 600) ~/ 60;

          _routePoints = decodedPoints;
        });
      }
    } catch (e) {
      debugPrint('💥 Route calculation error: $e');
      _showError('Не удалось рассчитать маршрут');
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _textMain,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _createOrder() async {
    if (_pickupAddressId == null || _dropoffAddressId == null) {
      _showError('Укажите точки отправления и назначения');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Ошибка: Пользователь не авторизован');
      return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: _textMain),
      ),
    );

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      final userData = userDoc.data() ?? {};

      final String clientName = userData['name'] ??
          userData['fullName'] ??
          userData['userName'] ??
          userData['displayName'] ??
          user.displayName ??
          'Не указано';

      final String clientPhone = userData['phone'] ??
          userData['phoneNumber'] ??
          userData['tel'] ??
          userData['mobile'] ??
          user.phoneNumber ??
          'Не указано';

      final commentText = _descriptionController.text.trim().isEmpty
          ? 'Без описания'
          : _descriptionController.text.trim();

      final orderData = {
        'type': 'delivery',
        'subType': _selectedTaskType,
        'pickupAddress': _pickupController.text.trim(),
        'dropoffAddress': _dropoffController.text.trim(),
        'pickupAddressId': _pickupAddressId,
        'dropoffAddressId': _dropoffAddressId,
        'description': commentText,
        'distance_km': double.parse(_rawDistanceKm.toStringAsFixed(2)),
        'duration_min': _rawDurationMin,
        'totalCost': _calculateFinalPrice().toInt(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'clientId': user.uid,
        'clientName': clientName,
        'name': clientName,
        'clientPhone': clientPhone,
        'phone': clientPhone,
      };

      // 🚀 1. Отправляем в диспетчерскую со ВСЕМИ параметрами
      await AddressApiService.addOrder(
        addressId: _pickupAddressId!,         // Откуда забираем
        destinationId: _dropoffAddressId!,    // Куда везем (вторая точка)
        groupId: 328,
        phone: clientPhone,
        comment: commentText,                 // Примечание (например, «молоко»)
        carType: 1,                           // Укажи свою переменную типа машины, если есть
        carServices: [],                      // Передай список ID выбранных услуг (например, [5])
        radugaId: 0,                          // Если используется radugaId
      );

      // 2. Сохраняем локально в Firestore
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
      debugPrint('💥 Order creation error: $e');
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError("Ошибка сохранения: $e");
    }
  }

  Widget _buildRouteMapPreview() {
    if (_pickupLocation == null && _dropoffLocation == null) {
      return const SizedBox.shrink();
    }

    final LatLng center = _pickupLocation ?? _dropoffLocation ?? const LatLng(46.8403, 29.6433);

    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderSubtle, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          if (_routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  color: const Color(0xFF2563EB),
                  strokeWidth: 4.5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (_pickupLocation != null)
                Marker(
                  point: _pickupLocation!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'А',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_dropoffLocation != null)
                Marker(
                  point: _dropoffLocation!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Б',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgMain,
      appBar: AppBar(
        backgroundColor: _bgMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: _cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: _borderSubtle, width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          _selectedTownName,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.4,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTaskTypeSelector(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('МАРШРУТ'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _borderSubtle, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: _textMain.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildAddressPickerBlock(
                            title: _selectedTaskType == 'buy' ? 'ГДЕ КУПИТЬ?' : 'ОТКУДА',
                            controller: _pickupController,
                            icon: Icons.my_location_rounded,
                            onMapTap: () => _pickLocationFromMap(true),
                            onManualTap: () => _openManualSearch(true),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildAddressPickerBlock(
                            title: 'КУДА',
                            controller: _dropoffController,
                            icon: Icons.location_on_rounded,
                            onMapTap: () => _pickLocationFromMap(false),
                            onManualTap: () => _openManualSearch(false),
                          ),
                        ],
                      ),
                    ),
                    _buildRouteMapPreview(),
                    if (_isCalculatingRoute)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _cardSurface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _textMain.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const CupertinoActivityIndicator(radius: 13, color: _textMain),
                          ),
                        ),
                      )
                    else if (_pickupAddressId != null && _dropoffAddressId != null)
                      _routeInfoTile(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(_selectedTaskType == 'buy' ? 'СПИСОК ПОКУПОК' : 'ЧТО ВЕЗЕМ?'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _borderSubtle, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: _textMain.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textMain),
                        decoration: InputDecoration(
                          hintText: _selectedTaskType == 'buy'
                              ? 'Например: молоко 2.5%, хлеб, вода'
                              : 'Например: документы, личные вещи',
                          hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, fontWeight: FontWeight.w500),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 40, left: 12, right: 8),
                            child: Icon(Icons.inventory_2_outlined, color: _textMain, size: 22),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildTaskTypeSelector() {
    final types = [
      {'id': 'pickup', 'title': 'Забрать', 'icon': Icons.card_giftcard_rounded},
      {'id': 'buy', 'title': 'Купить', 'icon': Icons.shopping_bag_outlined},
      {'id': 'task', 'title': 'Поручение', 'icon': Icons.task_alt_rounded},
    ];

    return Row(
      children: types.map((t) {
        bool isSelected = _selectedTaskType == t['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTaskType = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: t['id'] != 'task' ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? _textMain : _cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _textMain : _borderSubtle,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _textMain.withValues(alpha: isSelected ? 0.12 : 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    t['icon'] as IconData,
                    color: isSelected ? Colors.white : _textMuted,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['title'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textMain,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddressPickerBlock({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onMapTap,
    required VoidCallback onManualTap,
  }) {
    bool hasValue = controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Material(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderSubtle, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(icon, color: _textMain, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: onMapTap,
                        child: Text(
                          hasValue ? controller.text : 'Указать точку на карте',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: hasValue ? _textMain : const Color(0xFFCBD5E1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onMapTap,
                      icon: const Icon(Icons.map_rounded, color: _textMuted, size: 20),
                      tooltip: 'Выбрать на карте',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onManualTap,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text(
                      'Ручной ввод',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textMain,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _routeInfoTile() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Text(
          'Расстояние: ${_rawDistanceKm.toStringAsFixed(1)} км',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _bottomPricePanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: _cardSurface,
        boxShadow: [
          BoxShadow(
            color: _textMain.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Итого к оплате',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pickupAddressId != null && _dropoffAddressId != null
                        ? '${_calculateFinalPrice().toInt()} Руб'
                        : 'Укажите точки на карте',
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _textMain.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isCalculatingRoute ? null : _createOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _textMain,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                ),
                child: const Text(
                  'Заказать',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
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
class MapPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialCenter;
  final int? townId;
  final bool isPickupMarker; // true для точки А (синий), false для точки В (зеленый)

  const MapPickerScreen({
    super.key,
    required this.title,
    this.initialCenter,
    this.townId,
    required this.isPickupMarker,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;

  String _currentAddressText = 'Определение адреса...';
  int? _currentAddressId;
  bool _isFetchingAddress = false;
  bool _isLocatingUser = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialCenter ?? const LatLng(46.8403, 29.6433);
    _resolveAddress(_currentCenter);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _goToMyCurrentLocation() async {
    setState(() => _isLocatingUser = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // 🚀 СКОРОСТЬ: используем среднюю точность и ставим жесткий таймаут в 3 секунды
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Быстрее, чем .high
        timeLimit: const Duration(seconds: 3),    // Не ждем вечно
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      // Двигаем карту (если есть контроллер)
      _mapController.move(userLatLng, 16.0);
      setState(() {
        _currentCenter = userLatLng;
      });

      // Запрос к твоему API
      final addressData = await AddressApiService.locateAddress(
        position.latitude,
        position.longitude,
      );

      if (addressData != null && mounted) {
        setState(() {
          _currentAddressText = addressData['name'] ?? 'Мое местоположение';
          _currentAddressId = addressData['id'] is int ? addressData['id'] : int.tryParse(addressData['id'].toString());
        });
      }
    } catch (e) {
      debugPrint('💥 Error getting location quickly: $e');
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  Future<void> _resolveAddress(LatLng position) async {
    if (_isFetchingAddress) return;

    if (mounted) {
      setState(() {
        _isFetchingAddress = true;
      });
    }

    String resolvedName = '';
    int? resolvedId;

    try {
      final int mapLatInt = (position.latitude * 1000000).round();
      final int mapLonInt = (position.longitude * 1000000).round();

      final locateRes = await AddressApiService.locateAddress(mapLatInt, mapLonInt);

      if (locateRes != null && locateRes['id'] != null) {
        resolvedName = locateRes['name'] ?? locateRes['address'] ?? '';
        resolvedId = locateRes['id'] is int ? locateRes['id'] : int.tryParse(locateRes['id'].toString());
      }

      if (resolvedName.isEmpty || resolvedId == null) {
        if (widget.townId != null) {
          final queryStr = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
          final checkRes = await AddressApiService.checkAddress(queryStr, widget.townId!);

          if (checkRes != null) {
            resolvedName = checkRes['name'] ?? checkRes['address'] ?? '';
            resolvedId = checkRes['id'] is int ? checkRes['id'] : int.tryParse(checkRes['id'].toString());
          }
        }
      }

      if (resolvedName.isEmpty) {
        resolvedName = 'Точка: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }
    } catch (e) {
      resolvedName = 'Точка: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    }

    if (mounted) {
      setState(() {
        _currentAddressText = resolvedName;
        _currentAddressId = resolvedId;
        _isFetchingAddress = false;
      });
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _resolveAddress(_currentCenter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color markerColor = widget.isPickupMarker ? const Color(0xFF2563EB) : const Color(0xFF16A34A);
    final String markerLetter = widget.isPickupMarker ? 'А' : 'В';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
            ],
          ),
          // КРАСИВЫЙ МИНИАТЮРНЫЙ МАРКЕР ПО ЦЕНТРУ КАРТЫ
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: markerColor.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          markerLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 3,
                        height: 8,
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FloatingActionButton(
                        heroTag: 'loc_btn',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 4,
                        onPressed: _isLocatingUser ? null : _goToMyCurrentLocation,
                        child: _isLocatingUser
                            ? const CupertinoActivityIndicator(radius: 10)
                            : const Icon(Icons.my_location_rounded, size: 20),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ВЫБРАННЫЙ АДРЕС',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: markerColor, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _isFetchingAddress
                                  ? const Align(
                                alignment: Alignment.centerLeft,
                                child: CupertinoActivityIndicator(radius: 10),
                              )
                                  : Text(
                                _currentAddressText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isFetchingAddress
                                ? null
                                : () {
                              Navigator.pop(
                                context,
                                MapPickerResult(
                                  latLng: _currentCenter,
                                  addressName: _currentAddressText,
                                  addressId: _currentAddressId,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Подтвердить выбор',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class MapPickerResult {
  final LatLng latLng;
  final String addressName;
  final int? addressId;

  MapPickerResult({
    required this.latLng,
    required this.addressName,
    this.addressId,
  });
}