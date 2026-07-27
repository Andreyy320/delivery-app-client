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
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  // Переменные для сохранения текстовых названий улиц/адресов
  String? _pickupAddress;
  String? _dropoffAddress;

  Set<String> selectedOptions = {};

  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController = TextEditingController();
  // Контроллер для описания того, что нужно перевезти
  final TextEditingController _descriptionController = TextEditingController();

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
    'receiver_pay': Icons.account_balance_wallet_rounded,
    'fragile': Icons.security_rounded,
    'large': Icons.local_shipping_rounded,
  };
  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 50,
    'large': 100,
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
          initialReceiverName: _receiverNameController.text.trim(),     // <--- Передаем имя
          initialReceiverPhone: _receiverPhoneController.text.trim(),   // <--- Передаем телефон
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
      debugPrint('❌ ОШИБКА: Пользователь не авторизован (user == null)');
      _showError('Ошибка: Пользователь не авторизован');
      return;
    }

    debugPrint('🔍 Ищем данные пользователя в Firestore для UID: ${user.uid}');

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
      debugPrint('📦 Сырые данные пользователя из Firestore: $userData');

      // Проверяем все возможные варианты названий полей
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

      debugPrint('👤 Распознанное имя клиента: "$clientName"');
      debugPrint('📞 Распознанный телефон клиента: "$clientPhone"');

      // Временная проверка прямо на экране (удалиш потом),
      // чтобы ты сразу увидел в уведомлении, что пришло из базы:
      // _showError('Имя: $clientName | Тел: $clientPhone');

      final roadPrice = _calculateRoadPrice();
      final totalCost = _calculateTotalPrice();

      final orderData = {
        'pickup': {'lat': _pickupLocation!.latitude, 'lng': _pickupLocation!.longitude},
        'dropoff': {'lat': _dropoffLocation!.latitude, 'lng': _dropoffLocation!.longitude},
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
        'type': 'delivery',
        if (selectedOptions.contains('receiver_pay')) ...{
          'receiverName': _receiverNameController.text.trim(),
          'receiverPhone': _receiverPhoneController.text.trim(),
        },
      };

      debugPrint('🚀 Отправляем заказ в Firestore: $orderData');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('delivery_orders')
          .add(orderData);

      debugPrint('✅ Заказ успешно сохранен!');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ ОШИБКА при сохранении заказа: $e');
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
                            title: 'АДРЕС ОТПРАВЛЕНИЯ',
                            hint: 'Укажите, откуда забрать отправление',
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

                    // Поле ввода: Что везем
                    _buildSectionHeader('ЧТО ВЕЗЕМ?'),
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
                          hintText: 'Например: документы, личные вещи',
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
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(
                      '~$_rawDurationMin мин. в пути',
                      style: const TextStyle(
                        color: Colors.white70,
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
    bool isReceiverPay = optId == 'receiver_pay';

    return Column(
      children: [
        GestureDetector(
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
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? const Color(0xFFD97706) : const Color(0xFFF1F5F9),
                width: isSelected ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFD97706).withOpacity(0.08)
                      : const Color(0xFF0F172A).withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFD97706).withOpacity(0.15) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    optionIcons[optId] ?? Icons.extension_outlined,
                    color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        optionTitles[optId]!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (optionSubtitles[optId] != null) ...[
                        const SizedBox(height: 3),
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
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      optionPrices[optId] == 0 ? 'Бесплатно' : '+${optionPrices[optId]} Руб',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? const Color(0xFFD97706) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isReceiverPay && isSelected)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _receiverNameController,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Имя получателя',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFD97706), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _receiverPhoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Номер телефона получателя',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFD97706), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bottomPricePanel() {
    final total = _calculateTotalPrice();
    final bool canOrder = _rawDistanceKm > 0 && !_isCalculatingRoute;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding > 0 ? bottomPadding + 12 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${total.toInt()} Руб',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canOrder ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
              foregroundColor: canOrder ? Colors.white : const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: canOrder ? 6 : 0,
              shadowColor: const Color(0xFFD97706).withOpacity(0.4),
            ),
            onPressed: canOrder ? _goToConfirmation : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ОФОРМИТЬ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5,
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
    required String? addressText,
    required LatLng? location,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isTop,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addressText ?? (location != null
                          ? "${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}"
                          : hint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: (addressText != null || location != null) ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                        color: (addressText != null || location != null) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
      ),
    );
  }
}

// Экран выбора точки на карте с автоматическим определением улицы (Reverse Geocoding)
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
  final MapController _mapController = MapController();

  LatLng? _currentCenterCoord;
  String? _resolvedAddress;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentCenterCoord = widget.initialLocation ?? const LatLng(46.8410, 29.6470);
    _onMapPositionChanged(_currentCenterCoord!, true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

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
        title: Text(
          widget.titleText,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 18),
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenterCoord ?? const LatLng(46.8410, 29.6470),
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
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 38),
              child: Icon(
                Icons.location_on_rounded,
                color: Color(0xFFEF4444),
                size: 52,
              ),
            ),
          ),
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
                    color: const Color(0xFF0F172A).withOpacity(0.08),
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
                      color: const Color(0xFFEF4444).withOpacity(0.1),
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
                        color: const Color(0xFF0F172A).withOpacity(0.3),
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