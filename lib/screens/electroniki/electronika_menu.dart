import 'package:flutter/material.dart';
import 'package:untitled1/screens/electroniki/Electronika_menu.dart';
import 'package:untitled1/screens/electroniki/tirElKom.dart';
import '../../models/dish_model.dart';
import '../../shops/shop.dart';
import 'Electronika_screen.dart';
import 'Hi_tek.dart';
import 'Tiraet.dart';

class Electronika {
  final String name;
  final String description;
  final double rating;
  final String time;
  final String imagePath;
  final String shopId;

  Electronika({
    required this.name,
    required this.description,
    required this.rating,
    required this.time,
    required this.imagePath,
    required this.shopId,

  });
}

final electronika = [
  Electronika(
    name: Shops.hitekName,
    description: 'Смартфоны, аксессуары и бытовая электроника',
    rating: 4.8,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/hitek.png',
    shopId: Shops.hitekId,  // 🔹 добавлен ID
  ),
  Electronika(
    name: Shops.tiraetName,
    description: 'Телефоны, компьютеры и цифровая техника',
    rating: 4.7,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/tiraet.jfif',
    shopId: Shops.tiraetId,
  ),
  Electronika(
    name: Shops.tirElKomName,
    description: 'Электроника, кабели и комплектующие',
    rating: 4.9,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/tirel.png',
    shopId: Shops.tirElKomId,
  ),
];


class ElectronikaScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart; // теперь с shopId

  const ElectronikaScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Магазины электроники'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: electronika.length,
        itemBuilder: (context, index) {
          final electronik = electronika[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              // открытие меню магазина
              switch (electronik.name) {
                case 'Хай-Тек':
                  openElectronikaMenu(context, addToCart, 'Хай-Тек', hi_tek, 'hitek');
                  break;
                case 'Тираэт':
                  openElectronikaMenu(context, addToCart, 'Тираэт', tiraetMenu, 'tiraet');
                  break;
                case 'ТирЭлКом':
                  openElectronikaMenu(context, addToCart, 'ТирЭлКом', tirElKomMenu, 'tirelkom');
                  break;
              }
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
                      electronik.imagePath,
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
                          electronik.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(electronik.description),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(electronik.rating.toString()),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(electronik.time),
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

  void openElectronikaMenu(
      BuildContext context,
      void Function(Dish, String) addToCart,
      String electronikaname,
      List<Dish> menu,
      String shopId, // 🔹 shopId для каждой точки
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElectronikaMenuScreen(
          restaurantName: electronikaname,
          menu: menu,
          shopId: shopId,
          addToCart: addToCart,
        ),
      ),
    );
  }
}
