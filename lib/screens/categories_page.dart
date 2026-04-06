import 'package:flutter/material.dart';
import 'package:untitled1/models/dish_model.dart';
import 'package:untitled1/screens/restouranti/food_restaurants_screen.dart';
import '../screens/Apteki/apteka_screen.dart';
import '../screens/Floarele/floare_menu.dart';
import 'package:untitled1/screens/Produckti/product_menu.dart';
import '../screens/electroniki/electronika_menu.dart';
import 'Dostavka/delivery_services_screen.dart';


class Category {
  final String title;
  final IconData icon;
  final Color color;

  Category({required this.title, required this.icon, required this.color});
}

final categories = [
  Category(title: 'Еда', icon: Icons.fastfood, color: Colors.orange),
  Category(title: 'Продукты', icon: Icons.shopping_basket, color: Colors.green),
  Category(title: 'Аптека', icon: Icons.medical_services, color: Colors.red),
  Category(title: 'Цветы', icon: Icons.local_florist, color: Colors.pink),
  Category(title: 'Электроника', icon: Icons.devices, color: Colors.blue),
  Category(title: 'Доставка', icon: Icons.local_shipping, color: Colors.deepPurple),
];

class CategoriesPage extends StatelessWidget {
  final void Function(Dish, String) addToCart;
  const CategoriesPage({super.key, required this.addToCart});

  void openCategory(BuildContext context, String title) {

    Widget screen;
    switch (title) {
      case 'Еда':
        screen = FoodRestaurantsScreen(addToCart: addToCart);
        break;
      case 'Аптека':
        screen = AptekaScreen(addToCart: addToCart);
        break;
      case 'Электроника':
        screen = ElectronikaScreen(addToCart: addToCart);
        break;
      case 'Цветы':
        screen = FloareScreen(addToCart: addToCart);
        break;
      case 'Продукты':
        screen = ProductScreen(addToCart: addToCart);
        break;
      case 'Доставка':
      // 👇 ПРОСТО PUSH, БЕЗ МЕНЮ СНИЗУ
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeliveryServicesScreen(), // ← твой экран доставки
          ),
        );
        return; // ❗ ОБЯЗАТЕЛЬНО, чтобы дальше не выполнялось

      default:
        return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: const Text(
              'Доставка рядом',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Что вас интересует?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => openCategory(context, category.title),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Align(
                            alignment: const Alignment(-0.2, 0),
                            child: Icon(category.icon, size: 32, color: category.color),
                          ),
                          const SizedBox(height: 25),
                          Align(
                            alignment: const Alignment(-0.2, 0),
                            child: Text(category.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
