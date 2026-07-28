import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'order_confirmation_screen.dart';

class ExpressDeliveryScreen extends StatefulWidget {
  const ExpressDeliveryScreen({super.key});

  @override
  State<ExpressDeliveryScreen> createState() => _ExpressDeliveryScreenState();
}

class _ExpressDeliveryScreenState extends State<ExpressDeliveryScreen> {
  // Выбранный режим задачи (забрать, купить, поручение)
  String _selectedTaskType = 'buy'; // 'pickup', 'buy', 'task'

  // Выбранный тип транспорта (электровелосипед или машина)
  String _selectedTransport = 'car'; // 'scooter', 'car'

  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  String? _pickupAddress;
  String? _dropoffAddress;

  Set<String> selectedOptions = {};

  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  double _rawDistanceKm = 0.0;
  int _rawDurationMin = 0;
  bool _isCalculatingRoute = false;

  // Доступные параметры груза (включая "Оплатит получатель")
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
    'receiver_pay': Icons.account_balance_wallet_rounded,
    'fragile': Icons.security_rounded,
    'large': Icons.local_shipping_rounded,
  };
  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 50,
    'large': 100,
  };

  // Настройки транспорта
  final Map<String, String> transportTitles = {
    'scooter': 'Электровелосипед',
    'car': 'Автомобиль',
  };
  final Map<String, String> transportSubtitles = {
    'scooter': 'До 20 кг',
    'car': 'До 150 кг',
  };
  final Map<String, IconData> transportIcons = {
    'scooter': Icons.electric_bike_rounded,
    'car': Icons.directions_car_rounded,
  };
  final Map<String, double> transportMultipliers = {
    'scooter': 1.0,
    'car': 1.4,
  };

  @override
  void dispose() {
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  double _calculateRoadPrice() {
    double base = 150.0;
    double kmRate = 25.0;
    double mult = transportMultipliers[_selectedTransport] ?? 1.0;
    return (base + (_rawDistanceKm * kmRate)) * mult;
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
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          titleText: isPickup ? 'Укажите адрес отправления' : 'Укажите адрес назначения',
          initialLocation: isPickup ? _pickupLocation : _dropoffLocation,
        ),
      ),
    );

    if (result != null && result['latLng'] != null) {
      setState(() {
        if (isPickup) {
          _pickupLocation = result['latLng'];
          _pickupAddress = result['address'];
        } else {
          _dropoffLocation = result['latLng'];
          _dropoffAddress = result['address'];
        }
      });
      _getRouteMetrics();
    }
  }

  Future<void> _goToConfirmation() async {
    if (_pickupLocation == null || _dropoffLocation == null || _rawDistanceKm == 0) {
      _showError('Сначала укажите адреса на карте');
      return;
    }

    if (selectedOptions.contains('receiver_pay')) {
      if (_receiverNameController.text.trim().isEmpty || _receiverPhoneController.text.trim().isEmpty) {
        _showError('Заполните имя и телефон получателя');
        return;
      }
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
          initialComment: _descriptionController.text.trim(),
          initialReceiverName: _receiverNameController.text.trim(),
          initialReceiverPhone: _receiverPhoneController.text.trim(),
          subType: _selectedTaskType, // Исправлено: передаем верное состояние
          transport: _selectedTransport, // Исправлено: передаем верное состояние
        ),
      ),
    );

    if (confirmed == true) {
      _finalSaveToFirebase();
    }
  }

  Future<void> _finalSaveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Ошибка: Пользователь не авторизован');
      return;
    }

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

      final roadPrice = _calculateRoadPrice();
      final totalCost = _calculateTotalPrice();

      final orderData = {
        'type': 'delivery',
        'subType': _selectedTaskType,
        'transport': _selectedTransport,
        'pickup': {
          'address': _pickupAddress ?? 'Адрес не указан',
          'lat': _pickupLocation!.latitude,
          'lon': _pickupLocation!.longitude,
        },
        'dropoff': {
          'address': _dropoffAddress ?? 'Адрес не указан',
          'lat': _dropoffLocation!.latitude,
          'lon': _dropoffLocation!.longitude,
        },
        'pickupAddress': _pickupAddress ?? 'Адрес не указан',
        'dropoffAddress': _dropoffAddress ?? 'Адрес не указан',
        'description': _descriptionController.text.trim().isEmpty
            ? 'Без описания'
            : _descriptionController.text.trim(),
        'distance_km': double.parse(_rawDistanceKm.toStringAsFixed(2)),
        'duration_min': _rawDurationMin,
        'options': selectedOptions.toList(),
        'roadPrice': roadPrice.toInt(),
        'totalCost': totalCost.toInt(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'clientId': user.uid,
        'clientName': clientName,
        'name': clientName,
        'clientPhone': clientPhone,
        'phone': clientPhone,
        if (selectedOptions.contains('receiver_pay')) ...{
          'receiverName': _receiverNameController.text.trim(),
          'receiverPhone': _receiverPhoneController.text.trim(),
        },
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
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Индивидуальная доставка',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 3 РЕЖИМА ДОСТАВКИ ---
                    _buildTaskTypeSelector(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('МАРШРУТ'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildAddressCard(
                            title: _selectedTaskType == 'buy' ? 'КУПИТЬ В МАГАЗИНЕ' : 'АДРЕС ОТПРАВЛЕНИЯ',
                            hint: _selectedTaskType == 'buy' ? 'Укажите магазин' : 'Укажите, откуда забрать отправление',
                            addressText: _pickupAddress,
                            location: _pickupLocation,
                            icon: Icons.my_location_rounded,
                            iconColor: const Color(0xFF0284C7),
                            onTap: () => _pickLocation(true),
                            isTop: true,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildAddressCard(
                            title: 'АДРЕС НАЗНАЧЕНИЯ',
                            hint: 'Укажите, куда доставить',
                            addressText: _dropoffAddress,
                            location: _dropoffLocation,
                            icon: Icons.location_on_rounded,
                            iconColor: const Color(0xFFD97706),
                            onTap: () => _pickLocation(false),
                            isTop: false,
                          ),
                        ],
                      ),
                    ),
                    if (_isCalculatingRoute)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withOpacity(0.06),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const CupertinoActivityIndicator(radius: 13, color: Color(0xFFD97706)),
                          ),
                        ),
                      )
                    else if (_rawDistanceKm > 0)
                      _routeInfoTile(),

                    const SizedBox(height: 32),

                    // --- ТИП ТРАНСПОРТА ---
                    _buildSectionHeader('ТРАНСПОРТ'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTransportCard('scooter')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTransportCard('car')),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Поле ввода: Что везем / Список покупок
                    _buildSectionHeader(_selectedTaskType == 'buy' ? 'СПИСОК ПОКУПОК' : 'ЧТО ВЕЗЕМ?'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: _selectedTaskType == 'buy' ? 'Например: молоко 2.5%, хлеб, вода' : 'Например: документы, личные вещи',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.inventory_2_outlined, color: Color(0xFFD97706), size: 22),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('ПАРАМЕТРЫ ЗАКАЗА'),
                    const SizedBox(height: 12),
                    ...allOptions.map(_buildOptionTile).toList(),

                    // Блок полей ввода для опции "Оплатит получатель"
                    if (selectedOptions.contains('receiver_pay')) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFD97706), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ДАННЫЕ ПОЛУЧАТЕЛЯ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _receiverNameController,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Имя получателя',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFD97706), size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _receiverPhoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Номер телефона',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFD97706), size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  // Нижняя панель с ценой и кнопкой заказа
  Widget _bottomPricePanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
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
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rawDistanceKm > 0 ? '${_calculateTotalPrice().toInt()} Руб' : 'Укажите маршрут',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isCalculatingRoute ? null : _goToConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
              ),
              child: const Text(
                'Заказать',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Селектор 3 режимов сверху
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
              margin: EdgeInsets.only(right: t['id'] != 'task' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(isSelected ? 0.08 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    t['icon'] as IconData,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['title'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

  Widget _buildAddressCard({
    required String title,
    required String hint,
    required String? addressText,
    required LatLng? location,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isTop,
  }) {
    bool isSelected = location != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(24) : Radius.zero,
        bottom: !isTop ? const Radius.circular(24) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addressText ?? hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
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
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.alt_route_rounded, color: Color(0xFFF59E0B), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Расчет маршрута выполнен',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_rawDistanceKm.toStringAsFixed(1)} км',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '~$_rawDurationMin мин',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
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

  Widget _buildTransportCard(String transportId) {
    bool isSelected = _selectedTransport == transportId;
    return GestureDetector(
      onTap: () => setState(() => _selectedTransport = transportId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(isSelected ? 0.08 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFD97706) : const Color(0xFFD97706).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    transportIcons[transportId],
                    color: isSelected ? Colors.white : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              transportTitles[transportId] ?? '',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              transportSubtitles[transportId] ?? '',
              style: TextStyle(
                color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(String optId) {
    bool isSelected = selectedOptions.contains(optId);
    int price = optionPrices[optId] ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedOptions.remove(optId);
          } else {
            selectedOptions.add(optId);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFF1F5F9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(isSelected ? 0.06 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                optionIcons[optId],
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
                    optionTitles[optId] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    optionSubtitles[optId] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (price > 0) ...[
              Text(
                '+$price Р',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}



// --- ЭКРАН ВЫБОРА ТОЧКИ НА КАРТЕ С КНОПКОЙ ПОДТВЕРЖДЕНИЯ ---
class SelectLocationScreen extends StatefulWidget {
  final String titleText;
  final LatLng? initialLocation;

  const SelectLocationScreen({
    super.key,
    required this.titleText,
    this.initialLocation,
  });

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  late MapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = 'Определяем адрес...';
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialLocation ?? const LatLng(46.8403, 29.6433); // Тирасполь по умолчанию
    _getAddressFromLatLng(_currentCenter);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getAddressFromLatLng(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'ExpressDeliveryApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          final addressParts = (data['display_name'] as String).split(',');
          // Берем первые 3 понятных части адреса
          if (addressParts.length >= 3) {
            setState(() {
              _currentAddress = '${addressParts[0].trim()}, ${addressParts[1].trim()}';
            });
          } else {
            setState(() {
              _currentAddress = data['display_name'];
            });
          }
        } else {
          setState(() => _currentAddress = 'Адрес не найден');
        }
      }
    } catch (e) {
      setState(() => _currentAddress = 'Ошибка получения адреса');
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _currentCenter = camera.center;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _getAddressFromLatLng(_currentCenter);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          widget.titleText,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Карта на весь экран
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: 16.0,
                  onPositionChanged: _onPositionChanged,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.express_delivery',
                  ),
                ],
              ),
            ),
            // Пин по центру карты
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
            // Верхняя панель с выбранным адресом
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isLoadingAddress
                          ? const Text(
                        'Загрузка адреса...',
                        style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13),
                      )
                          : Text(
                        _currentAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Нижняя кнопка подтверждения адреса (гарантированно поверх карты)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoadingAddress
                      ? null
                      : () {
                    Navigator.pop(context, {
                      'latLng': _currentCenter,
                      'address': _currentAddress,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                  ),
                  child: const Text(
                    'Подтвердить адрес',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
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

