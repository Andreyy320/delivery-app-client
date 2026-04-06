import 'package:flutter/material.dart';
import 'package:untitled1/screens/Apteki/apteka_menu.dart';
import 'package:untitled1/screens/Apteki/e_apteka_menu.dart';
import 'package:untitled1/screens/Apteki/sto_letnik.dart';
import 'package:untitled1/screens/Apteki/viva_farm.dart';
import '../../models/dish_model.dart';
import '../../shops/shop.dart';

class Apteka {
  final String name;
  final String description;
  final double rating;
  final String time;
  final String imagePath;
  final String shopId; // 🔹 уникальный идентификатор аптеки

  Apteka({
    required this.name,
    required this.description,
    required this.rating,
    required this.time,
    required this.imagePath,
    required this.shopId,
  });
}

final aptekas = [
  Apteka(
    name: Shops.vivaFarmName,
    description: 'Аптека с широким ассортиментом лекарств и товаров для здоровья',
    rating: 4.8,
    time: '8:00 – 22:00',
    imagePath: 'assets/images/viva.jfif',
    shopId: Shops.vivaFarmId,
  ),
  Apteka(
    name: Shops.eAptekaName,
    description: 'Современная аптека с онлайн-заказом и быстрым обслуживанием',
    rating: 4.7,
    time: '8:00 – 22:00',
    imagePath: 'assets/images/Eapteka.png',
    shopId: Shops.eAptekaId,
  ),
  Apteka(
    name: Shops.stoLetnikName,
    description: 'Аптека с доступными ценами и большим выбором медикаментов',
    rating: 4.9,
    time: '8:00 – 22:00',
    imagePath: 'assets/images/stolet.jfif',
    shopId: Shops.stoLetnikId,
  ),
];


class AptekaScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart; // 🔹 теперь с shopId

  const AptekaScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Аптеки'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: aptekas.length,
        itemBuilder: (context, index) {
          final apteka = aptekas[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              // 🔹 открываем меню с новым конструктором
              List<Dish> menu;
              switch (apteka.shopId) {
                case 'viva_farm':
                  menu = vivafarm;
                  break;
                case 'e_apteka':
                  menu = e_apteka;
                  break;
                case 'sto_letnik':
                  menu = sto_letnik;
                  break;
                default:
                  menu = [];
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AptekaMenuScreen(
                    restaurantName: apteka.name,
                    menu: menu,
                    shopId: apteka.shopId,       // 🔹 передаем shopId
                    addToCart: addToCart,        // 🔹 передаем функцию
                  ),
                ),
              );
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
                      apteka.imagePath,
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
                        Text(apteka.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(apteka.description),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(apteka.rating.toString()),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(apteka.time),
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
}
