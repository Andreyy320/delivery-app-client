import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class ExpressOrderConfirmationScreen extends StatelessWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final Set<String> options;
  final double totalCost;

  final Map<String, int> optionPrices = {
    'receiver_pay': 10,
    'fragile': 20,
    'large': 30,
  };

  ExpressOrderConfirmationScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.options,
    required this.totalCost,
  });

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
            const Text('Откуда:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Широта: ${pickup.latitude.toStringAsFixed(5)}, Долгота: ${pickup.longitude.toStringAsFixed(5)}'),
            const SizedBox(height: 12),
            const Text('Куда:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Широта: ${dropoff.latitude.toStringAsFixed(5)}, Долгота: ${dropoff.longitude.toStringAsFixed(5)}'),
            const SizedBox(height: 16),
            const Text('Выбранные опции:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (options.isEmpty)
              const Text('Нет')
            else
              ...options.map((optId) {
                final price = optionPrices[optId] ?? 0;
                String title = '';
                switch (optId) {
                  case 'receiver_pay': title = 'Оплатит получатель'; break;
                  case 'fragile': title = 'Нежные товары'; break;
                  case 'large': title = 'Крупный груз'; break;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('$title (+$price ₽)'),
                );
              }).toList(),
            const SizedBox(height: 16),
            Text('Итоговая стоимость: ${totalCost.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заказ подтвержден!')),
                  );
                  Navigator.pop(context, true); // ← возвращаем true
                },
                child: const Text('Готово', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
