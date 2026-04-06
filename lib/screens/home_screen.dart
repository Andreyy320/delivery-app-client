import 'package:flutter/material.dart';
import 'categories_page.dart';
import 'package:untitled1/models/dish_model.dart';

class HomeScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart; // 🔹 учитываем shopId
  const HomeScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return CategoriesPage(addToCart: addToCart); // 🔹 передаем дальше
  }
}
