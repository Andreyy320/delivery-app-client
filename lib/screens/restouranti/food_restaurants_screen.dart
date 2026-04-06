// lib/screens/food_restaurants_screen.dart
import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import '../../shops/shop.dart';
import 'la_vida_menu.dart';
import 'nuvo_menu.dart';
import 'georgia_menu.dart';
import 'la_tokane_menu.dart';
import 'restaurant_menu_screen.dart';

class Restaurant {
  final String name;
  final String description;
  final double rating;
  final String time;
  final String imagePath;
  final String shopId;

  Restaurant({
    required this.name,
    required this.description,
    required this.rating,
    required this.time,
    required this.imagePath,
    required this.shopId,
  });
}

// 🔹 Все рестораны с уникальным shopId
final restaurants = [
  Restaurant(
    name: Shops.laVidaName,    // вместо 'LA VIDA'
    description: 'Яркая атмосфера и авторская кухня',
    rating: 4.8,
    time: '9:00 - 23:00',
    imagePath: 'assets/images/la_vida.jfif',
    shopId: Shops.laVidaId,    // вместо 'la_vida'
  ),
  Restaurant(
    name: Shops.nuvoName,
    description: 'Современная кухня и стейки',
    rating: 4.7,
    time: '9:00 - 23:00',
    imagePath: 'assets/images/nuvo.jpg',
    shopId: Shops.nuvoId,
  ),
  Restaurant(
    name: Shops.georgiaName,
    description: 'Грузинская кухня и хинкали',
    rating: 4.9,
    time: '9:00 - 23:00',
    imagePath: 'assets/images/georgia.jpeg',
    shopId: Shops.georgiaId,
  ),
  Restaurant(
    name: Shops.laTokaneName,
    description: 'Домашняя кухня и паста',
    rating: 4.6,
    time: '9:00 - 23:00',
    imagePath: 'assets/images/la_tokane.jpg',
    shopId: Shops.laTokaneId,
  ),
];


class FoodRestaurantsScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart; // 🔹 исправлено

  const FoodRestaurantsScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Рестораны'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              // Открытие меню ресторана
              switch (restaurant.name) {
                case 'LA VIDA':
                  openRestaurantMenu(context, restaurant, laVidaMenu);
                  break;
                case 'NUVO':
                  openRestaurantMenu(context, restaurant, NuvoMenu);
                  break;
                case 'GEORGIA':
                  openRestaurantMenu(context, restaurant, GeorgiaMenu);
                  break;
                case 'Ла Токанэ':
                  openRestaurantMenu(context, restaurant, La_tokane_Menu);
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
                      restaurant.imagePath,
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
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(restaurant.description),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(restaurant.rating.toString()),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(restaurant.time),
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

  void openRestaurantMenu(
      BuildContext context,
      Restaurant restaurant,
      List<Dish> menu) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantMenuScreen(
          restaurantName: restaurant.name,
          menu: menu,
          shopId: restaurant.shopId,
          addToCart: addToCart, // 🔹 прокидываем функцию
        ),
      ),
    );
  }
}
