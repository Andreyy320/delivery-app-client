import 'package:flutter/material.dart';
import 'package:untitled1/screens/electroniki/Electronika_screen.dart';
import '../../models/dish_model.dart';


final tirElKomMenu = [
// Роллы
  Dish(
    name: 'Датчик магнитного поля A0201F',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/dat2.jpg',
    category: 'Датчики',
  ),
  Dish(
    name: 'Датчик магнитного поля A1324LLHLX-T',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/dat1.jpg',
    category: 'Датчики',
  ),
  Dish(
    name: 'Переключатель на эффекте Холла, с защелкой',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/dat3.jpg',
    category: 'Датчики',
  ),


  Dish(
    name: 'FLEXIBLE NECK VFCNIFIER',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/der1.jpg',
    category: 'Оптика',
  ),
  Dish(
    name: 'Держатель для плат C01-02',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/der2.jpg',
    category: 'Оптика',
  ),
  Dish(
    name: 'Держатель для плат под паяльник с подсветкой',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/der3.jpg',
    category: 'Оптика',
  ),


  Dish(
    name: 'Аппарат для точечной сварки Docreate-756',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/ap1.jpg',
    category: 'Паяльное оборудование',
  ),
  Dish(
    name: 'Аппарат для точечной сварки Glitter 801H',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/ap2.jpg',
    category: 'Паяльное оборудование',
  ),
  Dish(
    name: 'Аппарат для точечной сварки AC9V-AC12V 100A',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/app3.jpg',
    category: 'Паяльное оборудование',
  ),


  Dish(
    name: 'ADSL фильтр prige (SP-168)',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/tel1.jpg',
    category: 'Телефония',
  ),
  Dish(
    name: 'ADSL фильтр prige',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/tel2.jpg',
    category: 'Телефония',
  ),
  Dish(
    name: 'Вилка телефоная универсальная',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/tel3.jpg',
    category: 'Телефония',
  ),


  Dish(
    name: 'Вентилятор AC 220V 4715MS-23W',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/vent1.jpg',
    category: 'Вентиляторы',
  ),
  Dish(
    name: 'Вентилятор AC 220V DP200A',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/vent2.jpg',
    category: 'Вентиляторы',
  ),
  Dish(
    name: 'Вентилятор AC 220V DP200A',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/tirElKom/vent3.jpg',
    category: 'Вентиляторы',
  ),
];

void openTirElKomMenu(
    BuildContext context,
    void Function(Dish, String) addToCart
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ElectronikaMenuScreen(
        restaurantName: 'ТирЭлКом',
        menu: tirElKomMenu,
        shopId: 'tirElKom', // уникальный id магазина
        addToCart: addToCart, // передаем функцию добавления в корзину
      ),
    ),
  );
}
