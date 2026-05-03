import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'DeliveryOrder.dart';
import 'order_confirmation_screen.dart';
import '../Menu/checkout_screen.dart';

class ExpressDeliveryScreen extends StatefulWidget {
  const ExpressDeliveryScreen({super.key});

  @override
  State<ExpressDeliveryScreen> createState() => _ExpressDeliveryScreenState();
}

class _ExpressDeliveryScreenState extends State<ExpressDeliveryScreen> {
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  Set<String> selectedOptions = {};

  final List<String> allOptions = ['receiver_pay', 'fragile', 'large'];
  final Map<String, String> optionTitles = {
    'receiver_pay': 'Оплатит получатель',
    'fragile': 'Нежные товары',
    'large': 'Крупный груз',
  };
  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 20,
    'large': 30,
  };

  // --- ЛОГИКА (БЕЗ ИЗМЕНЕНИЙ) ---
  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null) {
      setState(() {
        if (isPickup)
          _pickupLocation = result;
        else
          _dropoffLocation = result;
      });
    }
  }

  double calculateDeliveryCost() {
    double base = 50;
    double optionsCost = 0;
    for (var opt in selectedOptions) optionsCost += optionPrices[opt] ?? 0;
    return base + optionsCost;
  }

  Future<void> _confirmAndSaveOrder() async {
    if (_pickupLocation == null || _dropoffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите адрес отправления и доставки')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт')),
      );
      return;
    }

    final totalCost = calculateDeliveryCost();
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final clientName = userData?['name'] ?? 'Без имени';
    final clientPhone = userData?['phone'] ?? '-';

    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpressOrderConfirmationScreen(
          pickup: _pickupLocation!,
          dropoff: _dropoffLocation!,
          options: selectedOptions,
          totalCost: totalCost,
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final orderData = {
          'pickup': {'lat': _pickupLocation!.latitude, 'lng': _pickupLocation!.longitude},
          'dropoff': {'lat': _dropoffLocation!.latitude, 'lng': _dropoffLocation!.longitude},
          'options': selectedOptions.toList(),
          'totalCost': totalCost,
          'status': 'new',
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'delivery',
          'clientName': clientName,
          'clientPhone': clientPhone,
          'userId': user.uid,
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('delivery_orders')
            .add(orderData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ сохранён')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении заказа: $e')),
        );
      }
    }
  }

  // --- ОБНОВЛЕННЫЙ ДИЗАЙН ОПЦИЙ ---
  Widget _buildOptionTile(String optId) {
    bool isSelected = selectedOptions.contains(optId);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected)
            selectedOptions.remove(optId);
          else
            selectedOptions.add(optId);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? Colors.deepOrange.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.deepOrange : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: isSelected ? Colors.deepOrange : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                optionTitles[optId]!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.black87,
                ),
              ),
            ),
            Text(
              '+${optionPrices[optId]} ₽',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.deepOrange : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Срочная доставка',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.8),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildAddressCard(
                  title: 'ОТКУДА ЗАБРАТЬ',
                  hint: 'Выберите место отправления',
                  location: _pickupLocation,
                  icon: Icons.circle,
                  iconColor: Colors.green,
                  onTap: () => _pickLocation(true),
                ),
                const SizedBox(height: 20),
                _buildAddressCard(
                  title: 'КУДА ДОСТАВИТЬ',
                  hint: 'Выберите место доставки',
                  location: _dropoffLocation,
                  icon: Icons.location_on_rounded,
                  iconColor: Colors.deepOrange,
                  onTap: () => _pickLocation(false),
                ),
                const SizedBox(height: 32),
                const Text(
                  'ДОПОЛНИТЕЛЬНО',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black38,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ...allOptions.map(_buildOptionTile).toList(),
              ],
            ),
          ),

          // --- НИЖНЯЯ ПАНЕЛЬ С ОПЛАТОЙ ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого к оплате',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
                    Text(
                      '${calculateDeliveryCost().toInt()} ₽',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _confirmAndSaveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'ПОДТВЕРДИТЬ ЗАКАЗ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Вспомогательный виджет для карточек адреса
  Widget _buildAddressCard({
    required String title,
    required String hint,
    required LatLng? location,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    location != null
                        ? 'Координаты: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                        : hint,
                    style: TextStyle(
                      color: location != null ? Colors.black : Colors.black38,
                      fontWeight: location != null ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black26),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
