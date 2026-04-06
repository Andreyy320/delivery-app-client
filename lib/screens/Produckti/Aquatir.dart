import 'package:flutter/material.dart';
import 'package:untitled1/screens/Produckti/product_screen.dart';
import '../../models/dish_model.dart';


final aquatir_menu = [
// Роллы
  Dish(
    name: 'Икра белуги',
    description: 'Икра белуги – деликатес высшего класса.',
    price: 2200,
    imagePath: 'assets/images/Producti/Aquatir/ikra1.webp',
    category: 'Икра',
  ),
  Dish(
    name: 'Русская осетровая икра',
    description: 'Русская осетровая икра – нестареющая классика.',
    price: 2200,
      imagePath: 'assets/images/Producti/Aquatir/ikra2.webp',
    category: 'Икра',
  ),
  Dish(
    name: 'Икра Бестера',
    description: 'Икра Бестера – уникальный гибридный деликатес.',
    price: 2200,
    imagePath: 'assets/images/Producti/Aquatir/ikra3.webp',
    category: 'Икра',
  ),
  Dish(
    name: 'Икра стерляди',
    description: 'Икра стерляди – изысканный и утонченный выбор.',
    price: 2200,
    imagePath: 'assets/images/Producti/Aquatir/ikra4.webp',
    category: 'Икра',
  )


];

void openAquatirMenu(
    BuildContext context,
    void Function(Dish, String) addToCart, // 🔹 обязательно передаем
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductMenuScreen(
        restaurantName: 'Aquatir',
        menu: aquatir_menu,
        shopId: 'aquatir', // 🔹 уникальный идентификатор
      ),
    ),
  );
}
