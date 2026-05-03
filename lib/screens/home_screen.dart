import 'package:flutter/material.dart';
import 'categories_page.dart';

class HomeScreen extends StatelessWidget {
  // 🔹 Больше не принимаем addToCart, так как экраны сами работают с корзиной
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔹 Просто вызываем CategoriesPage без параметров
    return const CategoriesPage();
  }
}