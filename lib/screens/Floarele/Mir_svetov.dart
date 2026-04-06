import 'package:flutter/material.dart';
import 'package:untitled1/screens/Floarele/floare_screen.dart';
import '../../models/dish_model.dart';


final mir_svetov = [
// Роллы
  Dish(
    name: 'Букет из 51 красной и белой розы 50 см',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/mir_svetov/buket1.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет "Нежные признания"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/mir_svetov/buket2.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет 5 белых тюльпанов с мимозой',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/mir_svetov/buket3.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет из 11 пионовидных роз кантри',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/mir_svetov/buket4.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет роз "Сладкая акварель"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/mir_svetov/buket5.jpg',
    category: 'Букеты',
  ),
  Dish(
    name: 'Букет с ромашками и эустома "Легкий комплимент"',
    description: 'В наличии',
    price: 2200,
    imagePath: 'assets/images/floare/mir_svetov/buket6.jpg',
    category: 'Букеты',
  ),

];

void openMirSvetovMenu(
    BuildContext context,
    void Function(Dish, String) addToCart, // 🔹 прокидываем функцию
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FloareMenuScreen(
        restaurantName: 'Мир цветов',
        menu: mir_svetov,
        shopId: 'mir_svetov', // 🔹 единый стиль shopId
        addToCart: addToCart, // 🔹 передаем функцию добавления в корзину
      ),
    ),
  );
}
