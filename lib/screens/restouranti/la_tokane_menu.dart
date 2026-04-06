import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import 'restaurant_menu_screen.dart';


final La_tokane_Menu = [

  Dish(
    name: 'Панчетта и брезаола',
    description: '120 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/pancheta.png',
    category: 'Закуски',
  ),
  Dish(
    name: 'Икра из баклажан',
    description: '220 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/ikra.png',
    category: 'Закуски',
  ),
  Dish(
    name: 'Чипсы из тунца',
    description: '70 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/chips.png',
    category: 'Закуски',
  ),
  Dish(
    name: 'Оливки Каламата',
    description: '50 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/olivka.png',
    category: 'Закуски',
  ),


  Dish(
    name: 'Салат молдавский',
    description: '280 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/mold.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Сельдь под шубкой',
    description: '280 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/seld.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Салат из курицы и овощей',
    description: '280 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/salat_kyr.png',
    category: 'Салаты',
  ),


  Dish(
    name: 'Борщ с тушенной говядиной',
    description: '580 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/borj.png',
    category: 'Супы',
  ),
  Dish(
    name: 'Солянка мясная',
    description: '450 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/solanka.png',
    category: 'Супы',
  ),
  Dish(
    name: 'Зама с курицей',
    description: '410 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/zama.png',
    category: 'Супы',
  ),


  Dish(
    name: 'Плацинда с сыром',
    description: '340 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/plasinda.png',
    category: 'Плацинды',
  ),
  Dish(
    name: 'Плацинда с вишней',
    description: '240 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/plasinda_vis.png',
    category: 'Плацинды',
  ),
  Dish(
    name: 'Плацинда с брынзой',
    description: '260 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/brinz.png',
    category: 'Плацинды',
  ),

  Dish(
    name: 'Мититеи из баранины',
    description: '280 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/mititei.png',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Митетеи куриные',
    description: '280 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/mit_kyr.png',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Шашлык свиной',
    description: '370 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_tokane/svin.png',
    category: 'Горячие блюда',
  ),



  Dish(
    name: 'Ананасовый сок',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/la_tokane/ananas.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Апельсиновый сок',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/la_tokane/apelsin.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Мультивитамин',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/la_tokane/multivitamin.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Красные ягоды',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/la_tokane/yagoda.png',
    category: 'Напитки',
  ),

  Dish(
    name: 'Апероль Спритц',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/la_tokane/spritz.png',
    category: 'Крепкие напитки',
  ),
  Dish(
    name: 'Джин Тоник лесные ягоды',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/la_tokane/djin.png',
    category: 'Крепкие напитки',
  ),
];
void openLaTokaneMenu(
    BuildContext context,
    void Function(Dish, String) addToCart
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantMenuScreen(
        restaurantName: 'Ла Токанэ',
        menu: La_tokane_Menu,
        shopId: 'la_tokane',    // 🔹 единый стиль shopId
        addToCart: addToCart,   // 🔹 передаем функцию добавления
      ),
    ),
  );
}

