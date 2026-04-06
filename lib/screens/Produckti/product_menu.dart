// Модель магазина
import 'package:flutter/material.dart';

import '../../models/dish_model.dart';
import '../../shops/shop.dart';
import '../Menu/cart_screen.dart';
import 'Aquatir.dart';
import 'Garant.dart';
import 'Xleb.dart';

class Product {
  final String name;
  final String description;
  final double rating;
  final String time;
  final String imagePath;
  final String shopId;

  Product({
    required this.name,
    required this.description,
    required this.rating,
    required this.time,
    required this.imagePath,
    required this.shopId,
  });
}

// Список магазинов
final producti = [
    Product(
      name: Shops.garantName,
      description: 'Мясо, колбасы и мясные полуфабрикаты',
      rating: 4.8,
      time: '8:00 – 21:00',
      imagePath: 'assets/images/garant.jfif',
      shopId: Shops.garantId,
    ),
    Product(
      name: Shops.xlebName,
      description: 'Свежий хлеб, выпечка и хлебобулочные изделия',
      rating: 4.8,
      time: '8:00 – 21:00',
      imagePath: 'assets/images/xleb.jpg',
      shopId: Shops.xlebId,
    ),
    Product(
      name: Shops.aquatirName,
      description: 'Свежая рыба, морепродукты и рыбные деликатесы',
      rating: 4.8,
      time: '8:00 – 21:00',
      imagePath: 'assets/images/aquatir.png',
      shopId: Shops.aquatirId,
    ),
  ];

class ProductScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart; // передаем функцию добавления с shopId

  const ProductScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Продуктовые магазины'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CartScreen(
                    shopId: '', // Можно передавать конкретный shopId, если нужно
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: producti.length,
        itemBuilder: (context, index) {
          final product = producti[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
              onTap: () {
                switch (product.name) {
                  case 'Гарант':
                    openGarantMenu(context, addToCart);
                    break;
                  case 'Хлебокомбинат':
                    openXlebMenu(context, addToCart);
                    break;
                  case 'Aquatir':
                    openAquatirMenu(context, addToCart);
                    break;
                }
              },
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.asset(
                      product.imagePath,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.orange, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  product.rating.toString(),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              product.time,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
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
