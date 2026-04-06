import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import 'apteka_menu.dart';


final vivafarm = [
// Роллы
  Dish(
    name: 'Димедрол-Дарница 50мг №10 таблетки',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/dimedrol.png',
    category: 'Аллергия',
  ),
  Dish(
    name: 'Диазолин 0,05г №10 драже (Мебгидролин)',
    description: 'В наличии',
    price: 35.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/diazolin.jpeg',
    category: 'Аллергия',
  ),
  Dish(
    name: 'Цетиризин 10мг №20 таблетки п/п/о',
    description: 'В наличии',
    price: 72.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/seterizin.png',
    category: 'Аллергия',
  ),
  Dish(
    name: 'Супрастин 25мг №20 таблетки',
    description: 'В наличии',
    price: 35.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/syprastin.jpg',
    category: 'Аллергия',
  ),


  Dish(
    name: 'Прополиса настойка 25мл',
    description: 'В наличии',
    price: 87.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/propolisa.jpg',
    category: 'Гомеопатия',
  ),
  Dish(
    name: 'Авиа-Море таблетки №20',
    description: 'В наличии',
    price: 54.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/avia.png',
    category: 'Гомеопатия',
  ),
  Dish(
    name: 'Траумель С мазь 50г',
    description: 'В наличии',
    price: 77.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/traumel.jpg',
    category: 'Гомеопатия',
  ),


  Dish(
    name: 'Каптоприл таблетки 25мг №40',
    description: 'В наличии',
    price: 115.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/kaptopril.jpg',
    category: 'Кардиология',
  ),
  Dish(
    name: 'Дигоксин таблетки 0,25мг №40',
    description: 'В наличии',
    price: 124.3,
    imagePath: 'assets/images/Aptekas/Viva_Farm/digoksin.png',
    category: 'Кардиология',
  ),
  Dish(
    name: 'Эналаприл таблетки 10мг №30',
    description: 'В наличии',
    price: 55.7,
    imagePath: 'assets/images/Aptekas/Viva_Farm/enalapril.jpg',
    category: 'Кардиология',
  ),


  Dish(
    name: 'Женьшеня настойка 25мл',
    description: 'В наличии',
    price: 65.5,
    imagePath: 'assets/images/Aptekas/Viva_Farm/jenjen.jpg',
    category: 'Иммунология',
  ),
  Dish(
    name: 'Оциллококцинум гранулы №6',
    description: 'В наличии',
    price: 106.10,
    imagePath: 'assets/images/Aptekas/Viva_Farm/osillok.jpeg',
    category: 'Иммунология',
  ),
  Dish(
    name: 'Имупрет капли 100мл',
    description: 'В наличии',
    price: 126.55,
    imagePath: 'assets/images/Aptekas/Viva_Farm/imupret.png',
    category: 'Иммунология',
  ),


  Dish(
    name: 'Тауфон капли глазные 4% 10мл',
    description: 'В наличии',
    price: 126.55,
    imagePath: 'assets/images/Aptekas/Viva_Farm/tayfon.png',
    category: 'Офтальмология',
  ),
  Dish(
    name: 'Тобром капли глазные 0.3% 5мл',
    description: 'В наличии',
    price: 126.55,
    imagePath: 'assets/images/Aptekas/Viva_Farm/tobrom.jpg',
    category: 'Офтальмология',
  ),
  Dish(
    name: 'Визоптин капли глазные 0,05% 15мл',
    description: 'В наличии',
    price: 126.55,
    imagePath: 'assets/images/Aptekas/Viva_Farm/vizoprik.png',
    category: 'Офтальмология',
  ),
];

void openVivaFarmMenu(
    BuildContext context,
    void Function(Dish, String) addToCart
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AptekaMenuScreen(
        restaurantName: 'Вива Фарм',
        menu: vivafarm,
        shopId: 'viva_farm',   // уникальный идентификатор аптеки
        addToCart: addToCart,  // передаем функцию добавления в корзину
      ),
    ),
  );
}
