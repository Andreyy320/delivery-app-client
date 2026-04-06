import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О приложении'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 🟠 Логотип / иконка
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.delivery_dining,
                color: Colors.white,
                size: 60,
              ),
            ),

            const SizedBox(height: 16),

            // 📝 Название
            const Text(
              'Food Delivery',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            // 🔢 Версия
            const Text(
              'Версия 1.0.0',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            // 📄 Описание
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Food Delivery — это приложение для удобного заказа еды '
                    'из ресторанов и магазинов с быстрой доставкой.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              ),
            ),

            const SizedBox(height: 30),

            // 📋 Информация
            _infoTile(Icons.email, 'Поддержка', 'support@fooddelivery.app'),
            _infoTile(Icons.phone, 'Телефон', '+373 00 000 000'),
            _infoTile(Icons.language, 'Сайт', 'www.fooddelivery.app'),

            const SizedBox(height: 30),

            // 📜 Кнопки
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _actionButton(
                    context,
                    'Пользовательское соглашение',
                        () => _showStub(context),
                  ),
                  const SizedBox(height: 12),
                  _actionButton(
                    context,
                    'Политика конфиденциальности',
                        () => _showStub(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepOrange),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  static Widget _actionButton(
      BuildContext context, String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepOrange,
          side: const BorderSide(color: Colors.deepOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  static void _showStub(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Раздел в разработке')),
    );
  }
}
