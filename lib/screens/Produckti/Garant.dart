import 'package:flutter/material.dart';
import 'package:untitled1/screens/Produckti/product_screen.dart';
import '../../models/dish_model.dart';


final garant_menu = [
// Роллы
  Dish(
    name: 'ТРАДИЦИОННАЯ 1С',
    description: 'Состав: свинина, мясо птицы, специи, соль, нитрит натрия',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbasa1.jpg',
    category: 'Колбасы варенные',
  ),
  Dish(
    name: 'МАРТАДЕЛЛА 1С',
    description: 'Состав: говядина, мясо птицы, специи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbasa2.png',
    category: 'Колбасы варенные',
  ),
  Dish(
    name: 'СТОЛОВАЯ 2С',
    description: 'Состав: мясо птицы, говядина, специи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbasa3.png',
    category: 'Колбасы варенные',
  ),
  Dish(
    name: 'ДЕРЕВЕНСКАЯ 1С',
    description: 'Состав: свинина, филе птицы, соль, специи.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbasa4.png',
    category: 'Колбасы варенные',
  ),

  Dish(
    name: 'БАРБЕКЮ',
    description: 'Состав: свинина, феле птицы, сыр, сухое молоко.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/sosiska1.png',
    category: 'Сосиски',
  ),
  Dish(
    name: 'ФУНТИК 1С',
    description: 'Состав: свинина, филе птицы, сыр твёрдый.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/sosiska2.jpg',
    category: 'Сосиски',
  ),
  Dish(
    name: 'СТОЛОВЫЕ',
    description: 'Состав: мясо птицы, шкурка свиная, крахмал.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/sosiska3.png',
    category: 'Сосиски',
  ),


  Dish(
    name: 'ТРИ БОГАТЫРЯ',
    description: 'Мясо птицы, свинина, крахмал, специи, соль, нитрит натрия.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/sardelka1.jpg',
    category: 'Сардельки',
  ),
  Dish(
    name: 'ТУЛЬСКИЕ',
    description: 'Состав: мясо птицы, крахмал, специи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/sardelka2.png',
    category: 'Сардельки',
  ),
  Dish(
    name: 'ДОМАШНИЕ 2С',
    description: 'Состав: свинина, мясо птицы кусковое, специи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/sardelka3.png',
    category: 'Сардельки',
  ),


  Dish(
    name: 'ФРАНЦУЗСКАЯ 1С',
    description: 'Состав: свинина, соль, специи, нитрит натрия.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolb1.jpg',
    category: 'Колбасы сырокопчёные',
  ),
  Dish(
    name: 'ФУЕТ 1С',
    description: 'Состав: свинина, шпик, специи, соль, нитрит натрия.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolb2.jpg',
    category: 'Колбасы сырокопчёные',
  ),
  Dish(
    name: 'РОЖДЕСТВЕНСКАЯ В/С',
    description: 'Состав: свинина, шпик, соль, специи, нитрит натрия.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolb3.jpg',
    category: 'Колбасы сырокопчёные',
  ),


  Dish(
    name: 'ВЕНГЕРСКАЯ',
    description: 'Состав: свинина,  нитрит натрия, соль, специи.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbas1.jpg',
    category: 'Колбасы полукопчёные',
  ),
  Dish(
    name: 'САЛЯМИ ФРАНЦУЗСКАЯ',
    description: 'Состав: свинина, нитрит натрия, соль, специи.',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbas2.jpg',
    category: 'Колбасы полукопчёные',
  ),
  Dish(
    name: 'СЛАВЯНСКАЯ 1С',
    description: 'Состав: свинина, мясо птицы, шпиг, соль, специи',
    price: 2200,
    imagePath: 'assets/images/Producti/Garant/kolbas3.jpg',
    category: 'Колбасы полукопчёные',
  )
];

void openGarantMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductMenuScreen(
        restaurantName: 'Гарант',
        menu: garant_menu, // твой список Dish для Garant
        shopId: 'garant',  // уникальный идентификатор магазина
      ),
    ),
  );
}
