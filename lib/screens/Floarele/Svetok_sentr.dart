import 'package:flutter/material.dart';
import 'package:untitled1/screens/Floarele/floare_screen.dart';
import '../../models/dish_model.dart';


final svetok_sentr = [
// Роллы
  Dish(
    name: 'Букет из 101 розы',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket1.webp',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет любви',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket2.webp',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет "Цветочный деликатес"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket3.webp',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет "Свидание на лугу"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket4.webp',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет "Абрикосовый десерт"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket5.webp',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет "Розовое и белое"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket6.webp',
    category: 'Букеты',
  ),
  Dish(
    name: 'Кремовый букет',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/Svetok_sentr/buket7.webp',
    category: 'Букеты',
  )
];

// 🔹 Обновлённая функция с addToCart
void openSvetokSentrMenu(
    BuildContext context,
    void Function(Dish, String) addToCart, // 🔹 прокидываем функцию
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FloareMenuScreen(
        restaurantName: 'Цветочный центр',
        menu: svetok_sentr,
        shopId: 'svetok_sentr',
        addToCart: addToCart, // 🔹 передаем сюда
      ),
    ),
  );
}