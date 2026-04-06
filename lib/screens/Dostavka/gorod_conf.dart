import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GorodOrderConfirmationScreen extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final String bodySize;
  final int loaders;
  final int escort;
  final bool timeSelected;
  final DateTime? scheduledTime;
  final int totalPrice;

  const GorodOrderConfirmationScreen({
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

    // 🔹 Берем данные пользователя из Firestore
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

      // 🔥 НОВЫЕ ПОЛЯ
      'clientName': clientName,
      'clientPhone': clientPhone,
      'userId': user.uid,
      'type': 'city', // чтобы отличать тип заказа
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cityOrders')
        .add(orderData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение заказа'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Откуда:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(fromAddress),
            const SizedBox(height: 12),
            const Text('Куда:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(toAddress),
            const SizedBox(height: 16),
            const Text('Детали заказа:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Кузов: $bodySize'),
            Text('Грузчики: ${loaders == 0 ? "Нет" : loaders}'),
            Text('Сопровождающий: ${escort == 0 ? "Нет" : escort}'),
            Text(timeSelected
                ? 'Время: ${scheduledTime!.day}.${scheduledTime!.month} '
                '${scheduledTime!.hour.toString().padLeft(2, '0')}:'
                '${scheduledTime!.minute.toString().padLeft(2, '0')}'
                : 'Время: не выбрано'),
            const SizedBox(height: 16),
            Text(
              'Итоговая стоимость: $totalPrice ₽',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.deepOrange),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  try {
                    await _saveOrderToFirestore();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Заказ сохранен и подтвержден!')),
                    );

                    Navigator.popUntil(context, (route) => route.isFirst);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка сохранения: $e')),
                    );
                  }
                },
                child: const Text(
                  'Готово',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
