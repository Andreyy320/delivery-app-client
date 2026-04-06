import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import '../../shops/shop.dart';
import 'Buket_md.dart';
import 'Mir_svetov.dart';
import 'Svetok_sentr.dart';
import 'floare_screen.dart';

class Floare {
  final String name;
  final String description;
  final double rating;
  final String time;
  final String imagePath;
  final String shopId;

  Floare({
    required this.name,
    required this.description,
    required this.rating,
    required this.time,
    required this.imagePath,
    required this.shopId,
  });
}

final floarele = [
  Floare(
    name: Shops.mirName,
    description: 'Свежие цветы, букеты и композиции на любой повод',
    rating: 4.8,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/mir.png',
    shopId: Shops.mirId,
  ),
  Floare(
    name: Shops.centerName,
    description: 'Букеты, комнатные растения и праздничное оформление',
    rating: 4.7,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/flower.jpg',
    shopId: Shops.centerId,
  ),
  Floare(
    name: Shops.buketName,
    description: 'Авторские букеты',
    rating: 4.9,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/bucket.jpg',
    shopId: Shops.buketId,
  ),
];

class FloareScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart; // 🔹 исправлено

  const FloareScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Цветы'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: floarele.length,
        itemBuilder: (context, index) {
          final floare = floarele[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              List<Dish> menu;

              // 🔹 определяем меню по shopId
              switch (floare.shopId) {
                case Shops.mirId:
                  menu = mir_svetov;
                  break;
                case Shops.centerId:
                  menu = svetok_sentr;
                  break;
                case Shops.buketId:
                  menu = buket_menu;
                  break;
                default:
                  menu = [];
              }

              openFloareMenu(context, floare, menu);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.asset(
                      floare.imagePath,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          floare.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(floare.description),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(floare.rating.toString()),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(floare.time),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void openFloareMenu(BuildContext context, Floare floare, List<Dish> menu) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloareMenuScreen(
          restaurantName: floare.name, // 🔹 оставляем так же
          menu: menu,
          shopId: floare.shopId,
          addToCart: addToCart, // прокидываем функцию для корзины
        ),
      ),
    );
  }
}
