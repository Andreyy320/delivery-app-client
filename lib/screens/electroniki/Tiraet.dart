import 'package:flutter/material.dart';
import 'package:untitled1/screens/electroniki/Electronika_screen.dart';
import '../../models/dish_model.dart';


final tiraetMenu = [
// Роллы
  Dish(
    name: 'Ноутбук ACER Aspire LITE 15 (NX.J9SEX.001) Cel',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/nout1.webp',
    category: 'Ноутбук ',
  ),
  Dish(
    name: 'Ноутбук ASUS VivoBook GO 15 E1504FA',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/nout2.webp',
    category: 'Ноутбук ',
  ),
  Dish(
    name: 'Ноутбук HP 15-FD0066NW Intel i3',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/not3.jpg',
    category: 'Ноутбук ',
  ),


  Dish(
    name: 'Монитор 24 "Hikvision DS-D5024FN01"',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/mon1.jpg',
    category: 'Мониторы',
  ),
  Dish(
    name: 'Монитор 24 "Philips 24E1N1100A/00"',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/mon2.webp',
    category: 'Мониторы',
  ),
  Dish(
    name: 'Монитор 24 "LG 24MR400-B.AEUQ" ',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/mon3.webp',
    category: 'Мониторы',
  ),


  Dish(
    name: 'Смартфон BLACKVIEW BV4800 3/64GB ORANGE 6.56',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/smart1.webp',
    category: 'Смартфон',
  ),
  Dish(
    name: 'Смартфон OPPO A18 4/128GB Glowing Black',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/smart2.webp',
    category: 'Смартфон',
  ),
  Dish(
    name: 'Смартфон Samsung GALAXY A05S',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/smart2.webp',
    category: 'Смартфон',
  ),


  Dish(
    name: 'Смарт-часы Hoco Smart Watch Y25',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/cas1.webp',
    category: 'Часы',
  ),
  Dish(
    name: 'Смарт-часы X8 pro+',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/cas2.webp',
    category: 'Часы',
  ),
  Dish(
    name: 'Фитнес-браслет OnePlus W101IN BLACK',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/cas3.webp',
    category: 'Часы',
  ),


  Dish(
    name: 'Зарядное устройство HyperX',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/zar.webp',
    category: 'Игровая приставка',
  ),
  Dish(
    name: 'Джойстик (GamePad) Microsoft Xbox BLACK',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/djost.webp',
    category: 'Игровая приставка',
  ),
  Dish(
    name: 'Джойстик (GamePad) Microsoft Xbox One',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/djost2.webp',
    category: 'Игровая приставка',
  ),


  Dish(
    name: 'IP-камера Panasonic WV-SP102E',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/cam1.webp',
    category: 'Видеонаблюдение',
  ),
  Dish(
    name: 'Камера Turbo HD HiLook THC-B110-M 2.8mm',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/cam2.webp',
    category: 'Видеонаблюдение',
  ),
  Dish(
    name: 'Камера Turbo HD HiLook THC-B120-MC 2.8mm',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/electroniki/Tiraet/cam3.webp',
    category: 'Видеонаблюдение',
  )
];

void openTiraetMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ElectronikaMenuScreen(
        restaurantName: 'Тираэт',
        menu: tiraetMenu,
        shopId: 'tiraet', // уникальный id магазина
        addToCart: addToCart, // передаём функцию добавления в корзину
      ),
    ),
  );
}
