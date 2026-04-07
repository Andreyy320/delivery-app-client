import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MejGorodOrderConfirmationScreen extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final String bodySize;
  final int loaders;
  final int escort;
  final bool timeSelected;
  final DateTime? scheduledTime;
  final int totalPrice;

  const MejGorodOrderConfirmationScreen({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.bodySize,
    required this.loaders,
    required this.escort,
    required this.timeSelected,
    required this.scheduledTime,
    required this.totalPrice,
  });

  // ===== СОХРАНЕНИЕ ЗАКАЗА =====
  Future<void> _saveOrderToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Пользователь не авторизован");

    // 🔥 Получаем данные клиента из users/{uid}
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();

    final clientName = userData?['name'] ?? 'Без имени';
    final clientPhone = userData?['phone'] ?? '-';

    final orderData = {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'bodySize': bodySize,
      'loaders': loaders,
      'escort': escort,
      'timeSelected': timeSelected,
      'scheduledTime':
      scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'totalPrice': totalPrice,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'new',

      // 🔥 ВАЖНО — добавляем клиента
      'clientName': clientName,
      'clientPhone': clientPhone,
      'userId': user.uid,
      'type': 'mejCity',
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('mejCityOrders')
        .add(orderData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Светлый фон для контраста
      appBar: AppBar(
        title: const Text(
            'Проверка заказа',
            style: TextStyle(color: Colors.black)
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- КАРТОЧКА МАРШРУТА ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 15)
                ],
              ),
              child: Column(
                children: [
                  _buildRouteItem(
                      Icons.circle, Colors.green, 'Откуда:', fromAddress),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                        width: 1, height: 20, color: Colors.grey[300]),
                  ),
                  _buildRouteItem(
                      Icons.location_on, Colors.deepOrange, 'Куда:', toAddress),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- ДЕТАЛИ ЗАКАЗА ---
            const Text('Детали перевозки:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),

            _buildDetailRow(Icons.local_shipping_outlined, 'Кузов:', bodySize),
            _buildDetailRow(Icons.groups_outlined, 'Грузчики:',
                loaders == 0 ? "Нет" : '$loaders чел.'),
            _buildDetailRow(Icons.person_outline, 'Сопровождение:',
                escort == 0 ? "Нет" : '$escort чел.'),
            _buildDetailRow(
                Icons.access_time,
                'Время:',
                timeSelected
                    ? '${scheduledTime!.day}.${scheduledTime!
                    .month
                    .toString()
                    .padLeft(2, '0')} '
                    '${scheduledTime!.hour.toString().padLeft(
                    2, '0')}:${scheduledTime!.minute.toString().padLeft(
                    2, '0')}'
                    : 'Как можно быстрее'
            ),

            const Spacer(),

            // --- ИТОГО И КНОПКА ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итоговая стоимость:', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                      '$totalPrice ₽',
                      style: const TextStyle(fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  try {
                    await _saveOrderToFirestore();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Заказ успешно подтвержден!')),
                    );
                    Navigator.popUntil(context, (route) => route.isFirst);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка сохранения: $e')),
                    );
                  }
                },
                child: const Text(
                  'ПОДТВЕРДИТЬ И ЗАКАЗАТЬ',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

// Вспомогательный метод для маршрута
  Widget _buildRouteItem(IconData icon, Color color, String label,
      String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(text, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

// Вспомогательный метод для деталей
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
