import 'package:flutter/material.dart';
import 'package:untitled1/screens/restouranti/food_restaurants_screen.dart';
import 'package:untitled1/screens/Produckti/product_menu.dart';
import '../screens/Apteki/apteka_screen.dart';
import '../screens/Floarele/floare_menu.dart';
import '../screens/electroniki/electronika_menu.dart';
import 'Dostavka/delivery_services_screen.dart';

class Category {
  final String title;
  final IconData icon;
  final Color color;

  Category({required this.title, required this.icon, required this.color});
}

final categories = [
  Category(title: 'Еда', icon: Icons.fastfood_rounded, color: Colors.orange),
  Category(title: 'Продукты', icon: Icons.shopping_bag_rounded, color: Colors.green),
  Category(title: 'Аптека', icon: Icons.local_pharmacy_rounded, color: Colors.red),
  Category(title: 'Цветы', icon: Icons.local_florist_rounded, color: Colors.pink),
  Category(title: 'Электроника', icon: Icons.phone_iphone_rounded, color: Colors.blue),
  Category(title: 'Доставка', icon: Icons.local_shipping_rounded, color: Colors.deepPurple),
];

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  void openCategory(BuildContext context, String title) {
    Widget screen;
    switch (title) {
      case 'Еда': screen = const FoodRestaurantsScreen(); break;
      case 'Продукты': screen = const ProductScreen(); break;
      case 'Аптека': screen = const AptekaScreen(); break;
      case 'Электроника': screen = const ElectronikaScreen(); break;
      case 'Цветы': screen = const FloareScreen(); break;
      case 'Доставка': screen = const DeliveryServicesScreen(); break;
      default: return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ХЕДЕР
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Привет, Андрей! 👋',
                          style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Доставка рядом',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ЗАГОЛОВОК СЕКЦИИ
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: const Text(
                  'Категории',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // СЕТКА КАТЕГОРИЙ (Контент по центру)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final category = categories[index];
                    return GestureDetector(
                      onTap: () => openCategory(context, category.title),
                      child: Container(
                        // Центрируем всё содержимое внутри контейнера
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: category.color.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center, // Центр по вертикали
                          crossAxisAlignment: CrossAxisAlignment.center, // Центр по горизонтали
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: category.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(category.icon, size: 36, color: category.color),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              category.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
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
      ),
    );
  }
}
