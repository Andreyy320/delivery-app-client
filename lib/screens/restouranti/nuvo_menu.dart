import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import 'restaurant_menu_screen.dart';


final NuvoMenu = [

  Dish(
    name: 'Черная икра',
    description: '200 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/ikra.jfif',
    category: 'Закуски',
  ),
  Dish(
    name: 'Сет намазок',
    description: '600 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/namazka.jfif',
    category: 'Закуски',
  ),
  Dish(
    name: 'Карпачо из говядины',
    description: '200 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/karpacho.jfif',
    category: 'Закуски',
  ),
  Dish(
    name: 'Плачущий помидор',
    description: '280 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/tomato.png',
    category: 'Закуски',
  ),


  Dish(
    name: 'Салат грузинский',
    description: '300 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/salat_gruz.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Салат зеленый',
    description: '300 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/salat_zel.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Салат с телятиной',
    description: '330 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/salat_tela.png',
    category: 'Салаты',
  ),

  Dish(
    name: 'Борщ с говядиной',
    description: '530 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/borz.png',
    category: 'Супы',
  ),
  Dish(
    name: 'Том-ям',
    description: '600 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/tom_am.jfif',
    category: 'Супы',
  ),

  Dish(
    name: 'Осминог на гриле',
    description: '350 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/osminog.png',
    category: 'Рыба/Морепродукты',
  ),
  Dish(
    name: 'Креветки темпура',
    description: '170 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/krevetka.jfif',
    category: 'Рыба/Морепродукты',
  ),

  Dish(
    name: 'Калифорния',
    description: '350 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/kalifornia.jfif',
    category: 'Роллы',
  ),
  Dish(
    name: 'Зеленый дракон',
    description: '350 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/dragon.png',
    category: 'Роллы',
  ),
  Dish(
    name: 'Канада',
    description: '250 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/kanada.png',
    category: 'Роллы',
  ),
  Dish(
    name: 'Филадельфия',
    description: '260 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/filadelfia.jfif',
    category: 'Роллы',
  ),


  Dish(
    name: 'Медовик с вишней',
    description: '150 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/medovik.jfif',
    category: 'Десерты',
  ),
  Dish(
    name: 'Маковый эклер',
    description: '200 г',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/mak.png',
    category: 'Десерты',
  ),


  Dish(
    name: 'Ананасовый сок',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/ananas.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Апельсиновый сок',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/apelsin.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Мультивитамин',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/multi.jpg',
    category: 'Напитки',
  ),
  Dish(
    name: 'Красные ягоды',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/krasn.png',
    category: 'Напитки',
  ),


  Dish(
    name: 'Апероль Спритц',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/aperol.png',
    category: 'Крепкие напитки',
  ),
  Dish(
    name: 'Джин Тоник лесные ягоды',
    description: '1000 мл',
    price: 495,
    imagePath: 'assets/images/restorani/nuvo/djin.png',
    category: 'Крепкие напитки',
  ),

];

void openNuvoMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantMenuScreen(
        restaurantName: 'NUVO',
        menu: NuvoMenu,
        shopId: 'nuvo',        // 🔹 используем корректный shopId
        addToCart: addToCart,  // 🔹 передаем функцию добавления
      ),
    ),
  );
}
