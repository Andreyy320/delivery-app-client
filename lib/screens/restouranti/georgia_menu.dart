import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import 'restaurant_menu_screen.dart';


final GeorgiaMenu = [

  Dish(
    name: 'Рулетики из баклажанов',
    description: '220 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/ruletiki.jfif',
    category: 'Закуски',
  ),
  Dish(
    name: 'Семга малосольная',
    description: '220 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/somga.jfif',
    category: 'Закуски',
  ),

  Dish(
    name: 'Хинкали с креветкой',
    description: '220 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/hinkali.jfif',
    category: 'Хинкали',
  ),
  Dish(
    name: 'Хинкали с бараниной',
    description: '220 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/hinkali.jfif',
    category: 'Хинкали',
  ),
  Dish(
    name: 'Хинкали с говядиной',
    description: '220 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/hinkali.jfif',
    category: 'Хинкали',
  ),


  Dish(
    name: 'Зама',
    description: '340 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/zama.jfif',
    category: 'Супы',
  ),
  Dish(
    name: 'Солянка',
    description: '320 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/solanka.jfif',
    category: 'Супы',
  ),
  Dish(
    name: 'Харчо',
    description: '400 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/harsho.jfif',
    category: 'Супы',
  ),

  Dish(
    name: 'Долма',
    description: '160 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/dolma.jfif',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Купаты по грузински',
    description: '200 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/kypat.jfif',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Люля кебаб',
    description: '150 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/lyla.jfif',
    category: 'Горячие блюда',
  ),


  Dish(
    name: 'Лимонад',
    description: '300 мл',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/limonad.jfif',
    category: 'Напитки',
  ),
  Dish(
    name: 'Фреш апельсиновый',
    description: '200 мл',
    price: 12.5,
    imagePath: 'assets/images/restorani/georgia/frah.jfif',
    category: 'Напитки',
  ),
];

void openGeorgiaMenu(
    BuildContext context,
    void Function(Dish, String) addToCart
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantMenuScreen(
        restaurantName: 'GEORGIA',
        menu: GeorgiaMenu,
        shopId: 'georgia',    // 🔹 единый стиль shopId
        addToCart: addToCart, // 🔹 передаем функцию добавления
      ),
    ),
  );
}
