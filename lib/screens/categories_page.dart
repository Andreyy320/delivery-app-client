import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled1/screens/restouranti/food_restaurants_screen.dart';
import 'package:untitled1/screens/Produckti/product_menu.dart';
import 'package:untitled1/screens/stroimaterial/stroimaterial_screen.dart';
import '../screens/Apteki/apteka_screen.dart';
import '../screens/Floarele/floare_menu.dart';
import '../screens/electroniki/electronika_menu.dart';
import 'Dostavka/delivery_services_screen.dart';
import 'odejda/odejda_screen.dart';


class Category {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

// Премиальная палитра акцентов
final categories = [
  Category(
    title: 'Еда',
    subtitle: 'Рестораны и кафе',
    icon: Icons.restaurant_rounded,
    accentColor: const Color(0xFFFF4757),
  ),
  Category(
    title: 'Продукты',
    subtitle: 'Супермаркеты',
    icon: Icons.shopping_bag_rounded,
    accentColor: const Color(0xFF10B981),
  ),
  Category(
    title: 'Аптека',
    subtitle: 'Лекарства 24/7',
    icon: Icons.medical_services_rounded,
    accentColor: const Color(0xFF0EA5E9),
  ),
  Category(
    title: 'Цветы',
    subtitle: 'Букеты и декор',
    icon: Icons.local_florist_rounded,
    accentColor: const Color(0xFFF43F5E),
  ),
  Category(
    title: 'Электроника',
    subtitle: 'Гаджеты и сеть',
    icon: Icons.devices_rounded,
    accentColor: const Color(0xFF6366F1),
  ),
  Category(
    title: 'Одежда',
    subtitle: 'Стиль и обувь', // Поправили описание
    icon: Icons.checkroom_rounded, // Подходящая иконка для одежды
    accentColor: const Color(0xFFA855F7), // Красивый фиолетовый акцент
  ),
  Category(
    title: 'Стройматериалы', // Поправили название (во множественном числе)
    subtitle: 'Ремонт и дом', // Поправили описание
    icon: Icons.home_repair_service_rounded, // Подходящая иконка для стройки
    accentColor: const Color(0xFFF59E0B), // Тёплый строительный оранжевый
  ),
  Category(
    title: 'Доставка',
    subtitle: 'Индивидуальная',
    icon: Icons.local_shipping_rounded,
    accentColor: const Color(0xFF8B5CF6),
  ),
];

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void openCategory(BuildContext context, String title) {
    Widget screen;
    switch (title) {
      case 'Еда':
        screen = const FoodRestaurantsScreen();
        break;
      case 'Продукты':
        screen = const ProductScreen();
        break;
      case 'Аптека':
        screen = const AptekaScreen();
        break;
      case 'Электроника':
        screen = const ElectronikaScreen();
        break;
      case 'Цветы':
        screen = const FloareScreen();
        break;
      case 'Одежда':
        screen = const ClothingStoresScreen();
        break;
      case 'Стройматериалы':
        screen = const StroiMaterialScreen();
        break;
      case 'Доставка':
        screen = const DeliveryServicesScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserGreeting() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _GreetingText('Загрузка...');
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const _GreetingText('ДОБРО ПОЖАЛОВАТЬ');
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            String name = "Гость";
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              name = data['name'] ?? "Пользователь";
            }
            return _GreetingText('ПРИВЕТ, ${name.toUpperCase()}');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Премиальный светлый фон
      body: SafeArea(
        child: Stack(
          children: [
            // Декоративное фоновое 3D-свечение сверху
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                ),
              ),
            ),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ХЕДЕР — Премиум Dark Glass плашка
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.3),
                            blurRadius: 28,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -20,
                            top: -30,
                            child: _GlowCircle(
                              size: 130,
                              color: const Color(0xFF38BDF8).withOpacity(0.12),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUserGreeting(),
                              const SizedBox(height: 8),
                              const Text(
                                'Экспресс Доставка',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Лучшие заведения города у вашей двери',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Категории',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black.withOpacity(0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Онлайн',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.88, // Увеличена высота карточки, чтобы длинные тексты и подзаголовки помещались идеально на всех экранах
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final category = categories[index];
                        final animation = CurvedAnimation(
                          parent: _controller,
                          curve: Interval(
                            (index / categories.length) * 0.6,
                            1.0,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.12),
                              end: Offset.zero,
                            ).animate(animation),
                            child: _CategoryCard(
                              category: category,
                              onTap: () => openCategory(context, category.title),
                            ),
                          ),
                        );
                      },
                      childCount: categories.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingText extends StatelessWidget {
  final String text;
  const _GreetingText(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// 3D Премиум-карточка с эффектом глубины и мягким бликом
class _CategoryCard extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final color = widget.category.accentColor;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _pressed ? color.withOpacity(0.4) : Colors.white,
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
                : [
              // Объёмная основная тень
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              // Легкое цветное свечение снизу
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Объёмный 3D-контейнер для иконки с градиентным бликом
                  Container(
                    width: 52,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color,
                          color.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(widget.category.icon, size: 25, color: Colors.white),
                  ),

                  // Стрелка действия
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.category.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}