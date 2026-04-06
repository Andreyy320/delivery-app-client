import 'package:flutter/material.dart';
import 'package:untitled1/screens/Apteki/apteka_menu.dart';
import '../../models/dish_model.dart';
import 'apteka_screen.dart';


final sto_letnik = [
// Роллы
  Dish(
    name: '5-HTP 100мкг №30 капс. БАД',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/htp.png',
    category: 'Витамины',
  ),
  Dish(
    name: 'GLS 5-HTP с экстрактом Шафрана №60 капс. БАД',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/gls.jpg',
    category: 'Витамины',
  ),
  Dish(
    name: 'GLS Артишока экстракт №60 капс. БАД',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/arti.jpg',
    category: 'Витамины',
  ),


  Dish(
    name: 'L-лизина эсцинат 1мг/мл 5мл №10 амп.',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/lizina.jpg',
    category: 'Медикаменты',
  ),
  Dish(
    name: 'L-тироксин 100 Берлин-Хеми № 100 таб',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/tiroks.jpg',
    category: 'Медикаменты',
  ),
  Dish(
    name: 'L-Цет 2,5мг/5мл 60мл сироп',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/set.jpg',
    category: 'Медикаменты',
  ),


  Dish(
    name: 'Очки Визини (d - 2,0)',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/optik.jpg',
    category: 'Оптика',
  ),
  Dish(
    name: 'Очки Визини (d - 1,5)',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/optik.jpg',
    category: 'Оптика',
  ),
  Dish(
    name: 'Очки Визини (d - 0,75)',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/optik.jpg',
    category: 'Оптика',
  ),


  Dish(
    name: 'Пластины от комаров Стоп укус 10шт',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/stopkomar.jpg',
    category: 'Репелленты',
  ),
  Dish(
    name: 'Раптор Спирали №10',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/raptor.jpg',
    category: 'Репелленты',
  ),
  Dish(
    name: 'Репеллент DE LETO Active',
    description: 'В наличии',
    price: 19.5,
    imagePath: 'assets/images/Aptekas/StoLetnik/active.jpg',
    category: 'Репелленты',
  ),

];

void openStoLetnikMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AptekaMenuScreen(
        restaurantName: '100 летник',
        menu: sto_letnik,
        shopId: 'sto_letnik',    // 🔹 shopId уникальный для аптеки
        addToCart: addToCart,     // 🔹 функция добавления в корзину
      ),
    ),
  );
}
