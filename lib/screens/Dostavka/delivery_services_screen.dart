import 'package:flutter/material.dart';
import 'package:untitled1/screens/Dostavka/Gorod.dart';
import 'package:untitled1/screens/Dostavka/MejGorod.dart';
import 'package:untitled1/screens/Dostavka/courier_express_screen.dart';


class DeliveryServicesScreen extends StatelessWidget {
  const DeliveryServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Доставка'),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ===== КУРЬЕР =====
            /// ===== КУРЬЕР =====
            const _SectionTitle(title: 'Курьер'),
            const SizedBox(height: 12),

// Вместо GridView используем это:
            const SizedBox(
              width: double.infinity, // Растягиваем на всю ширину
              child: _ServiceCard(
                title: 'Срочная доставка',
                subtitle: 'Как можно быстрее',
                icon: Icons.flash_on,
                screen: ExpressDeliveryScreen(),
              ),
            ),

            const SizedBox(height: 28),

            const SizedBox(height: 28),

            /// ===== ГРУЗОВЫЕ =====
            const _SectionTitle(title: 'Грузовые перевозки'),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1, // 👈 И тут тоже 0.85
              children: const [
                _ServiceCard(
                  title: 'По городу',
                  subtitle: 'Срочно или в удобное время',
                  icon: Icons.local_shipping,
                  screen: CityCargoDetailsScreen(),
                ),
                _ServiceCard(
                  title: 'Межгород',
                  subtitle: 'Дальние перевозки',
                  icon: Icons.fire_truck,
                  screen: MejCityCargoDetailsScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================
/// ЗАГОЛОВОК СЕКЦИИ
/// ===================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// ===================
/// КАРТОЧКА
/// ===================
class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Собираем всё в центре
          children: [
            // Иконка в нежном круге
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.deepOrange),
            ),
            const SizedBox(height: 14), // Фиксированный отступ

            // Заголовок
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4), // Маленький отступ до подзаголовка

            // Подзаголовок
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}