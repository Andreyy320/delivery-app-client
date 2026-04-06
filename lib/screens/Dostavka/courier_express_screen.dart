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
    'receiver_pay': 10,
    'fragile': 20,
    'large': 30,
  };

  // Выбор координат
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

  // Расчет стоимости
  double calculateDeliveryCost() {
    double base = 50;
    double optionsCost = 0;
    for (var opt in selectedOptions) optionsCost += optionPrices[opt] ?? 0;
    return base + optionsCost;
  }

  // Подтверждение и сохранение заказа
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

    // Берем имя и телефон из Firestore
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final clientName = userData?['name'] ?? 'Без имени';
    final clientPhone = userData?['phone'] ?? '-';

    // Открываем экран подтверждения
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

    // Если подтвердили
    if (confirmed == true) {
      try {
        final orderData = {
          'pickup': {
            'lat': _pickupLocation!.latitude,
            'lng': _pickupLocation!.longitude,
          },
          'dropoff': {
            'lat': _dropoffLocation!.latitude,
            'lng': _dropoffLocation!.longitude,
          },
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

  // Виджет для опций
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.deepOrange : Colors.grey),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${optionTitles[optId]} ${optionPrices[optId]! > 0 ? "(+${optionPrices[optId]} ₽)" : ""}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.deepOrange : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Срочная доставка'), backgroundColor: Colors.deepOrange),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  GestureDetector(
                    onTap: () => _pickLocation(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _pickupLocation != null
                            ? '${_pickupLocation!.latitude.toStringAsFixed(5)}, ${_pickupLocation!.longitude.toStringAsFixed(5)}'
                            : 'Выберите место отправления',
                        style: TextStyle(color: _pickupLocation != null ? Colors.black : Colors.grey[600]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickLocation(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dropoffLocation != null
                            ? '${_dropoffLocation!.latitude.toStringAsFixed(5)}, ${_dropoffLocation!.longitude.toStringAsFixed(5)}'
                            : 'Выберите место доставки',
                        style: TextStyle(color: _dropoffLocation != null ? Colors.black : Colors.grey[600]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Дополнительные опции:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...allOptions.map(_buildOptionTile).toList(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('К оплате:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${calculateDeliveryCost()} ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmAndSaveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Подтвердить заказ', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
