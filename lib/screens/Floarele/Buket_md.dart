import 'package:flutter/material.dart';
import 'package:untitled1/screens/Floarele/floare_screen.dart';
import '../../models/dish_model.dart';


final buket_menu = [
// Роллы
  Dish(
    name: 'Подарочная корзина 55',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/buket1.jpg',
    category: 'Цветочные корзины',
  ),
  Dish(
    name: 'Подарочная корзина 85',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/buket2.jpg',
    category: 'Цветочные корзины',
  ),
  Dish(
    name: 'Букет микс из кустовых розочек',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/svet1.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет из коралловых кустовых розочек',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/svet2.png',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет из белых и зелёных хризантем',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/buket3.png',
    category: 'Букеты',
  ),
  Dish(
    name: 'Белые ирисы',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/buket4.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Мини букет 2',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/buket4.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет Гербер',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/buket_md/buket5.jpg',
    category: 'Букеты',
  )
];

void openBuketMdMenu(
    BuildContext context,
    void Function(Dish, String) addToCart, // 🔹 прокидываем функцию
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FloareMenuScreen(
        restaurantName: 'Buket.md',
        menu: buket_menu,
        shopId: 'buket_md',
        addToCart: addToCart, // 🔹 передаем сюда
      ),
    ),
  );
}
