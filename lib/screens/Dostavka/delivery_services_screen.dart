import 'package:flutter/material.dart';
import 'package:untitled1/screens/Dostavka/Gorod.dart';
import 'package:untitled1/screens/Dostavka/MejGorod.dart';
import 'package:untitled1/screens/Dostavka/courier_express_screen.dart';

class DeliveryServicesScreen extends StatelessWidget {
  const DeliveryServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'СЛУЖБА ДОСТАВКИ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.5,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Вводный приветственный заголовок
            const Text(
              'Выберите тариф',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Быстрая доставка и профессиональная логистика',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 24),

            // ГЛАВНЫЙ ЭКСПРЕСС-ТАРИФ (Строгий глубокий Onyx + Gold)
            _LuxuryExpressCard(
              title: 'Экспресс Доставка',
              subtitle: 'Персональный курьер выедет сразу после оформления заказа',
              timeText: 'от 15 мин',
              icon: Icons.flash_on_rounded,
              screen: const ExpressDeliveryScreen(),
            ),

            const SizedBox(height: 32),

            // РАЗДЕЛИТЕЛЬ
            const _SectionHeader(title: 'Грузовой транспорт'),

            const SizedBox(height: 16),

            // СЕТКА ГРУЗОВЫХ ТАРИФОВ
            Row(
              children: [
                Expanded(
                  child: _StrictCargoCard(
                    title: 'По городу',
                    subtitle: 'Переезды, крупные покупки и негабарит',
                    badge: 'ГОРОД',
                    icon: Icons.local_shipping_outlined,
                    screen: const CityCargoDetailsScreen(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StrictCargoCard(
                    title: 'Межгород',
                    subtitle: 'Маршруты между городами и регионами',
                    badge: 'РЕГИОНЫ',
                    icon: Icons.alt_route_rounded,
                    screen: const MejCityCargoDetailsScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// СТРОГИЙ ЗАГОЛОВОК СЕКЦИИ
// -----------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(
            color: Color(0xFFE2E8F0),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ЭКСПРЕСС-КАРТОЧКА В СТИЛЕ ONYX & GOLD (VIP / Премиум)
// -----------------------------------------------------------------------------
class _LuxuryExpressCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String timeText;
  final IconData icon;
  final Widget screen;

  const _LuxuryExpressCard({
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.icon,
    required this.screen,
  });

  @override
  State<_LuxuryExpressCard> createState() => _LuxuryExpressCardState();
}

class _LuxuryExpressCardState extends State<_LuxuryExpressCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => widget.screen),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutCubic,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A), // Onyx
                Color(0xFF1E293B), // Slate Dark
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFD97706).withOpacity(0.3), // Золотистая рамка
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Фоновая иконка молнии
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  widget.icon,
                  size: 160,
                  color: const Color(0xFFF59E0B).withOpacity(0.05),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Иконка в золотом ограждении
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.3),
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: const Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),

                        // Бейдж «от 15 мин»
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled_rounded,
                                size: 12,
                                color: Color(0xFF0F172A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.timeText,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Кнопка перехода внутри карточки
                    Row(
                      children: [
                        const Text(
                          'Вызвать курьера',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// СТРОГИЕ КАРТОЧКИ ГРУЗОПЕРЕВОЗОК (Clean Obsidian)
// -----------------------------------------------------------------------------
class _StrictCargoCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Widget screen;

  const _StrictCargoCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.screen,
  });

  @override
  State<_StrictCargoCard> createState() => _StrictCargoCardState();
}

class _StrictCargoCardState extends State<_StrictCargoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => widget.screen),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutCubic,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.icon,
                      color: const Color(0xFF0F172A),
                      size: 22,
                    ),
                  ),
                  const Icon(
                    Icons.north_east_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}