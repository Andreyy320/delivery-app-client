import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'О приложении',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // 🟠 Логотип с мягкой тенью
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📝 Название
            const Text(
              'Food Delivery',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            // 🔢 Версия в красивой плашке
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Версия 1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 📄 Описание
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ваш надежный партнер в мире быстрой доставки. Мы соединяем лучшие рестораны города с вашим домом за считанные минуты.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 📋 Информация (Сгруппированная в карточку)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  children: [
                    _infoTile(Icons.alternate_email_rounded, 'Поддержка', 'support@fooddelivery.app'),
                    _divider(),
                    _infoTile(Icons.phone_iphone_rounded, 'Телефон', '+373 00 000 000'),
                    _divider(),
                    _infoTile(Icons.language_rounded, 'Сайт', 'www.fooddelivery.app'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 📜 Кнопки действий
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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

            // Маленькая подпись внизу
            Text(
              '© 2026 Food Delivery Team',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _divider() => Divider(height: 1, color: Colors.grey[200], indent: 60);

  static Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.deepOrange, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
    );
  }

  static Widget _actionButton(BuildContext context, String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  static void _showStub(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Раздел в разработке', style: TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}