import 'package:flutter/material.dart';
import 'package:untitled1/screens/Dostavka/Gorod.dart';
import 'package:untitled1/screens/Dostavka/MejGorod.dart';
import 'package:untitled1/screens/Dostavka/courier_express_screen.dart';

class DeliveryServicesScreen extends StatelessWidget {
  const DeliveryServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Доставка',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.8,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Декоративный мягкий фон (градиентное пятно для объема)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepOrange.withOpacity(0.03),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(title: 'Курьерская служба'),
                const SizedBox(height: 16),

                _ServiceCard(
                  title: 'Срочная доставка',
                  subtitle: 'Приедем так быстро, как это возможно',
                  icon: Icons.bolt_rounded,
                  screen: const ExpressDeliveryScreen(),
                  isFullWidth: true,
                ),

                const SizedBox(height: 36),

                const _SectionTitle(title: 'Грузовые перевозки'),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ServiceCard(
                        title: 'По городу',
                        subtitle: 'Переезды и вещи',
                        icon: Icons.local_shipping_rounded,
                        screen: const CityCargoDetailsScreen(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ServiceCard(
                        title: 'Межгород',
                        subtitle: 'Дальние рейсы',
                        icon: Icons.explore_rounded,
                        screen: const MejCityCargoDetailsScreen(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
  final bool isFullWidth;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
    this.isFullWidth = false,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _scale = 0.96),
      onPointerUp: (_) => setState(() => _scale = 1.0),
      onPointerCancel: (_) => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.screen)),
          child: Container(
            constraints: BoxConstraints(minHeight: widget.isFullWidth ? 120 : 160),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Иконка в двойном круге для эффекта глубины
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 28, color: Colors.deepOrange),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black38,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
