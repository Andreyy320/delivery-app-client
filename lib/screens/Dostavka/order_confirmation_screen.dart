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
      backgroundColor: Colors.grey[50], // Легкий фон для контраста с карточками
      appBar: AppBar(
        title: const Text('Проверка заказа'),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        centerTitle: true,
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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  _buildAddressRow(
                      icon: Icons.circle,
                      iconColor: Colors.green,
                      label: 'Откуда:',
                      coords: '${pickup.latitude.toStringAsFixed(5)}, ${pickup.longitude.toStringAsFixed(5)}'
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Container(width: 2, height: 20, color: Colors.grey[200]),
                  ),
                  _buildAddressRow(
                      icon: Icons.location_on,
                      iconColor: Colors.deepOrange,
                      label: 'Куда:',
                      coords: '${dropoff.latitude.toStringAsFixed(5)}, ${dropoff.longitude.toStringAsFixed(5)}'
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- СПИСОК ОПЦИЙ ---
            const Text('Выбранные опции:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            if (options.isEmpty)
              Text('Дополнительных услуг нет', style: TextStyle(color: Colors.grey[600]))
            else
              ...options.map((optId) {
                final price = optionPrices[optId] ?? 0;
                String title = '';
                IconData icon = Icons.check_circle_outline;
                switch (optId) {
                  case 'receiver_pay': title = 'Оплатит получатель'; icon = Icons.payment; break;
                  case 'fragile': title = 'Нежные товары'; icon = Icons.inventory_2_outlined; break;
                  case 'large': title = 'Крупный груз'; icon = Icons.local_shipping_outlined; break;
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: Colors.deepOrange),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
                      Text('+$price ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),

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
                  const Text('Итоговая стоимость:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text('${totalCost.toStringAsFixed(0)} ₽',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заказ подтвержден!')),
                  );
                  Navigator.pop(context, true);
                },
                child: const Text('ГОТОВО',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный виджет для строк адреса
  Widget _buildAddressRow({required IconData icon, required Color iconColor, required String label, required String coords}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(coords, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}