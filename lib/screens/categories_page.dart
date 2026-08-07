import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'food_menu.dart';
// Импортируйте ваш экран доставки (укажите правильный путь к файлу)
import 'package:untitled1/screens/Dostavka/delivery_services_screen.dart';

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key});

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFCEE36).withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              top: 150,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                ),
              ),
            ),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ХЕДЕР
                const SliverToBoxAdapter(
                  child: _PersistentHeaderContainer(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // СТРОКА ПОИСКА (универсальный хинт)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(
                                alpha: 0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию заведения...',
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF0F172A),
                            size: 24,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              color: Color(0xFFCBD5E1),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // БАННЕР ИНДИВИДУАЛЬНОЙ ДОСТАВКИ
                if (_searchQuery.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _DeliveryBannerCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeliveryServicesScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                if (_searchQuery.isEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ЗАГОЛОВОК СЕКЦИИ
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Все заведения'
                          : 'Результаты поиска',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // СПИСОК РЕЗУЛЬТАТОВ В РЕАЛЬНОМ ВРЕМЕНИ
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('categories')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: Color(
                              0xFF0F172A)),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Нет доступных заведений',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    final filteredRestaurants = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final isActive = data['isActive'] ?? true;
                      if (isActive != true) return false;

                      if (_searchQuery.isNotEmpty) {
                        final name = (data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery);
                      }

                      return true;
                    }).toList();

                    if (filteredRestaurants.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 56,
                                  color: Color(0xFFCBD5E1)),
                              SizedBox(height: 12),
                              Text(
                                'Ничего не найдено',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final doc = filteredRestaurants[index];
                            final docId = doc.id;
                            final data = doc.data() as Map<String, dynamic>;

                            final name = data['name'] ?? 'Заведение';
                            final time = data['time'] ?? '9:00 - 21:00';
                            final logoUrl = data['logoUrl'] ?? '';
                            final isOnline = data['isOnline'] ?? false;
                            final rating = (data['rating'] != null)
                                ? (data['rating'] as num).toDouble()
                                : 4.8;
                            final deliveryPrice = data['deliveryPrice'] ??
                                'Бесплатно';

                            // Считываем тип заведения из поля базы (например, "product", "restaurant" и т.д.)
                            // Если поля нет, берем дефолтное 'general'
                            final categoryType = data['product'] ??
                                data['category'] ?? 'general';
                            final cuisineType = _getSubtitleForCategory(
                                categoryType);

                            return _CleanRestaurantCard(
                              title: name,
                              time: time,
                              imageUrl: logoUrl,
                              isOnline: isOnline,
                              rating: rating,
                              deliveryPrice: deliveryPrice,
                              cuisineType: cuisineType,
                              onTap: () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    transitionDuration: const Duration(
                                        milliseconds: 300),
                                    pageBuilder: (_, animation, __) =>
                                        RestaurantMenuScreen(
                                          shopId: docId,
                                          restaurantName: name,
                                        ),
                                    transitionsBuilder: (_, animation, __,
                                        child) {
                                      final curved = CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic);
                                      return FadeTransition(
                                        opacity: curved,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                              begin: const Offset(0, 0.05),
                                              end: Offset.zero)
                                              .animate(curved),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          },
                          childCount: filteredRestaurants.length,
                        ),
                      ),
                    );
                  },
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Метод для перевода типа из Firebase в красивую подпись на карточке
  String _getSubtitleForCategory(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'product':
        return 'Продуктовый • Магазин';
      case 'restaurant':
        return 'Ресторан • Готовая еда';
      case 'svetok':
        return 'Цветочный • Магазин';
      case 'apteka':
        return 'Аптека • Здоровье';
      case 'stroimaterial':
        return 'Строительный • Магазин';
      case 'odezhda': // исправлено с odejda
      case 'odejda':
        return 'Магазин • Одежда и обувь';
      case 'electronika':
        return 'Магазин • Электроника';
      default:
        return 'Магазин • Доставка';
    }
  }
}

// СТИЛЬНЫЙ И СТРОГИЙ СВЕТЛЫЙ БАННЕР ДОСТАВКИ
class _DeliveryBannerCard extends StatefulWidget {
  final VoidCallback onTap;

  const _DeliveryBannerCard({required this.onTap});

  @override
  State<_DeliveryBannerCard> createState() => _DeliveryBannerCardState();
}

class _DeliveryBannerCardState extends State<_DeliveryBannerCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: Color(0xFF0F172A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Индивидуальная доставка',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Быстрая отправка посылок и документов',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF0F172A),
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

// Постоянный контейнер хедера
class _PersistentHeaderContainer extends StatefulWidget {
  const _PersistentHeaderContainer();

  @override
  State<_PersistentHeaderContainer> createState() => _PersistentHeaderContainerState();
}

class _PersistentHeaderContainerState extends State<_PersistentHeaderContainer>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SmartUserGreeting(),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF0F172A),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Магазины и сервисы',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Всё необходимое с быстрой доставкой',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Интеллектуальный виджет приветствия
class _SmartUserGreeting extends StatefulWidget {
  const _SmartUserGreeting();

  @override
  State<_SmartUserGreeting> createState() => _SmartUserGreetingState();
}

class _SmartUserGreetingState extends State<_SmartUserGreeting> {
  User? currentUser;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          currentUser = user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const _UserGreetingText('ДОБРО ПОЖАЛОВАТЬ');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const _UserGreetingText('ЗАГРУЗКА...');
        }

        String name = "Гость";
        if (userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>?;
          name = data?['name'] ?? "Пользователь";
        }
        return _UserGreetingText('ПРИВЕТ, ${name.toUpperCase()}');
      },
    );
  }
}

class _UserGreetingText extends StatelessWidget {
  final String text;
  const _UserGreetingText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

// ПРЕМИАЛЬНО ОФОРМЛЕННАЯ КАРТОЧКА ЗАВЕДЕНИЯ
class _CleanRestaurantCard extends StatefulWidget {
  final String title;
  final String time;
  final String imageUrl;
  final bool isOnline;
  final double rating;
  final String deliveryPrice;
  final String cuisineType;
  final VoidCallback onTap;

  const _CleanRestaurantCard({
    required this.title,
    required this.time,
    required this.imageUrl,
    required this.isOnline,
    required this.rating,
    required this.deliveryPrice,
    required this.cuisineType,
    required this.onTap,
  });

  @override
  State<_CleanRestaurantCard> createState() => _CleanRestaurantCardState();
}

class _CleanRestaurantCardState extends State<_CleanRestaurantCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        image: widget.imageUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(widget.imageUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: widget.imageUrl.isEmpty
                          ? const Center(
                        child: Icon(Icons.storefront_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      )
                          : null,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.1),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isOnline ? Colors.white : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isOnline ? 'Открыто' : 'Закрыто',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: widget.isOnline ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.cuisineType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.time,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
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