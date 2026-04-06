import 'package:flutter/material.dart';
import 'package:untitled1/screens/electroniki/Electronika_screen.dart';
import '../../models/dish_model.dart';


final hi_tek = [
// Роллы
  Dish(
    name: 'Телевизор JPE LED E32D71A',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/televizor1.webp',
    category: 'Телевизоры',
  ),
  Dish(
    name: 'Телевизор UD 24EHA4210',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/televizor2.jpg',
    category: 'Телевизоры',
  ),
  Dish(
    name: 'Телевизор JPE LED E32D71A+Smart',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/televizor3.webp',
    category: 'Телевизоры',
  ),
  Dish(
    name: 'Телевизор Dahua LCD 32-SD100',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/televizor4.jpg',
    category: 'Телевизоры',
  ),


  Dish(
    name: 'Наушники с микрофоном Canyon EPM-01 White ',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/nauh.webp',
    category: 'Наушники',
  ),
  Dish(
    name: 'Наушники с микрофоном Sven AP-010MV',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/nauh2.webp',
    category: 'Наушники',
  ),
  Dish(
    name: 'Наушники Panasonic RP-HV094GU-K',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/nauh3.webp',
    category: 'Наушники',
  ),


  Dish(
    name: 'Микрофон Sven MK-150',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/micr1.webp',
    category: 'Аудиосистемы',
  ),
  Dish(
    name: 'Микрофон Sven MK-200',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/micr2.webp',
    category: 'Аудиосистемы',
  ),
  Dish(
    name: 'Микрофон Gembird MIC-D-02',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/micr3.webp',
    category: 'Аудиосистемы',
  ),


  Dish(
    name: 'Смартфон Motorola Moto E15 2/64GB Denim Blue ',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/smart1.jpg',
    category: 'Смартфоны',
  ),
  Dish(
    name: 'Смартфон Motorola Moto E15 2/64GB Misty Blue ',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/smart2.jpg',
    category: 'Смартфоны',
  ),
  Dish(
    name: 'Смартфон Samsung Galaxy A06 4/64Gb Gold',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/smart3.jpg',
    category: 'Смартфоны',
  ),


  Dish(
    name: 'Монитор LG 22MR410-B',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/mon1.webp',
    category: 'Мониторы',
  ),
  Dish(
    name: 'Монитор Samsung Essential S3 FHD',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/mon2.png',
    category: 'Мониторы',
  ),
  Dish(
    name: 'Монитор Samsung Business T37F',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/mon3.webp',
    category: 'Мониторы',
  ),


  Dish(
    name: 'Флешка USB 2.0 Goodram 16GB UME2 White',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/flesh1.webp',
    category: 'Накопители',
  ),
  Dish(
    name: 'MicroSDHC Goodram 16GB UHS-I',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/flesh2.webp',
    category: 'Накопители',
  ),
  Dish(
    name: 'Флешка USB 2.0 Goodram 16GB UTS2 Black',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Hi_teh/flesh3.webp',
    category: 'Накопители',
  )
];

void openHiTekMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ElectronikaMenuScreen(
        restaurantName: 'Хай-Тек',
        menu: hi_tek,
        shopId: 'hitek', // уникальный идентификатор магазина
        addToCart: addToCart, // передаём функцию добавления в корзину
      ),
    ),
  );
}
