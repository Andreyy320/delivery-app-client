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
        centerTitle: true, // <-- добавили, чтобы заголовок был по центру

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ===== КУРЬЕР =====
            const _SectionTitle(title: 'Курьер'),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
              children: const [
                _ServiceCard(
                title: 'Срочная доставка',
                subtitle: 'Как можно быстрее',
                icon: Icons.flash_on,
                screen: ExpressDeliveryScreen(),
              ),
              ],
            ),

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
              childAspectRatio: 1,
              children: const [ _ServiceCard(
                title: 'По городу',
                subtitle: 'Срочно или в удобное время',
                icon: Icons.local_shipping,
                screen: CityCargoDetailsScreen(),
              ),
              const _ServiceCard(
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
  final Widget screen; // 👈 ВАЖНО

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
