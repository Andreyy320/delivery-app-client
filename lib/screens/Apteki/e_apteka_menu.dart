import 'package:flutter/material.dart';
import 'package:untitled1/screens/Apteki/apteka_menu.dart';
import '../../models/dish_model.dart';
import 'apteka_screen.dart';


final e_apteka = [
// Роллы
  Dish(
    name: 'L-лизина эсцинат р-р д/ин 0,1% 5мл №10',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/lizina.jpg',
    category: 'Медикаменты',
  ),
  Dish(
    name: 'L-Тироксин 100 Берлин Хеми таб №100',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/tiroksin.jpg',
    category: 'Медикаменты',
  ),
  Dish(
    name: 'Авиа-Море таб №20',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/avia.jpg',
    category: 'Медикаменты',
  ),


  Dish(
    name: 'Бинт мед н/ст 7м*14см',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/bint.jpeg',
    category: 'Перевязочные средства',
  ),
  Dish(
    name: 'Салфетки марлевые cтерильные "Medrull" ',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/salf.png',
    category: 'Перевязочные средства',
  ),
  Dish(
    name: 'Бинт гипсовый "Medrull" 2,7м*20см',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/gips.jpg',
    category: 'Перевязочные средства',
  ),


  Dish(
    name: 'Масло эфирное Апельсина 10мл',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/efir.jpg',
    category: 'Оптика',
  ),
  Dish(
    name: 'Репейное масло с гинкго билоба 100мл',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/repei.jpg',
    category: 'Оптика',
  ),
  Dish(
    name: 'Масло семян льна 100мл',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/lin.jpg',
    category: 'Оптика',
  ),


  Dish(
    name: 'Лейкопластырь рулонный Medrull "CLASSIC',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/plast.png',
    category: 'Пластыри',
  ),
  Dish(
    name: 'Пластырь перцовый "Medrull"',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/pers.png',
    category: 'Пластыри',
  ),
  Dish(
    name: 'Салипод лейкопластырь',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/E_apteka/salipod.jpg',
    category: 'Пластыри',
  ),
];

void openEaptekaMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AptekaMenuScreen(
        restaurantName: 'E-apteka',
        menu: e_apteka,
        shopId: 'e_apteka',     // 🔹 обязательно передаем shopId
        addToCart: addToCart,    // 🔹 обязательно передаем функцию
      ),
    ),
  );
}
