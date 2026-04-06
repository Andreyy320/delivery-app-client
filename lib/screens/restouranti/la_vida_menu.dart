import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import 'restaurant_menu_screen.dart';


final laVidaMenu = [
// Роллы
  Dish(
    name: 'Вулкан с креветкой',
    description: '280 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_vida/vulcan.jfif',
    category: 'Роллы',
  ),
  Dish(
    name: 'Красный дракон',
    description: '260 г',
    price: 13.0,
    imagePath: 'assets/images/restorani/la_vida/red_dragon.png',
    category: 'Роллы',
  ),
  Dish(
    name: 'Красная креветка',
    description: '250 г',
    price: 12.0,
    imagePath: 'assets/images/restorani/la_vida/red_krevetka.jfif',
    category: 'Роллы',
  ),
  Dish(
    name: 'Канада',
    description: '270 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_vida/canada.jfif',
    category: 'Роллы',
  ),
  Dish(
    name: 'Кейро',
    description: '270 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_vida/keiro.png',
    category: 'Роллы',
  ),


  // Пицца
  Dish(
    name: 'Пицца Барбекю',
    description: '580 г',
    price: 16.0,
    imagePath: 'assets/images/restorani/la_vida/barbeky.png',
    category: 'Пицца',
  ),
  Dish(
    name: 'Пицца Пепперони',
    description: '500 г',
    price: 15.0,
    imagePath: 'assets/images/restorani/la_vida/pepperoni.jfif',
    category: 'Пицца',
  ),
  Dish(
    name: 'Пицца с беконом',
    description: '560 г',
    price: 16.5,
    imagePath: 'assets/images/restorani/la_vida/bacon.png',
    category: 'Пицца',
  ),
  Dish(
    name: 'Пицца Карбонара',
    description: '430 г',
    price: 14.5,
    imagePath: 'assets/images/restorani/la_vida/karbonara.png',
    category: 'Пицца',
  ),
  Dish(
    name: 'Пицца Диабло',
    description: '520 г',
    price: 17.0,
    imagePath: 'assets/images/restorani/la_vida/diablo.png',
    category: 'Пицца',
  ),

  // Бургеры
  Dish(
    name: 'Бургер Техас',
    description: '470 г',
    price: 14.0,
    imagePath: 'assets/images/restorani/la_vida/texas.png',
    category: 'Бургеры',
  ),
  Dish(
    name: 'Куриный бургер',
    description: '350 г',
    price: 12.0,
    imagePath: 'assets/images/restorani/la_vida/kyr_byrger.jfif',
    category: 'Бургеры',
  ),
  Dish(
    name: 'Бургер',
    description: '350 г',
    price: 11.0,
    imagePath: 'assets/images/restorani/la_vida/burger.png',
    category: 'Бургеры',
  ),
  Dish(
    name: 'Бургер в пите',
    description: '360 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_vida/pite.jfif',
    category: 'Бургеры',
  ),

  // Салаты
  Dish(
    name: 'Цезарь с креветками',
    description: '240 г',
    price: 10.0,
    imagePath: 'assets/images/restorani/la_vida/sezar_krev.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Цезарь с курицей',
    description: '320 г',
    price: 9.0,
    imagePath: 'assets/images/restorani/la_vida/sezar_kyr.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Тёплый мясной салат',
    description: '310 г',
    price: 11.0,
    imagePath: 'assets/images/restorani/la_vida/masnoy.png',
    category: 'Салаты',
  ),
  Dish(
    name: 'Салат с морепродуктами',
    description: '250 г',
    price: 12.0,
    imagePath: 'assets/images/restorani/la_vida/moreproduct.png',
    category: 'Салаты',
  ),

// Супы
  Dish(
    name: 'Крем-суп с крабами и курицей',
    description: '300 г',
    price: 9.5,
    imagePath: 'assets/images/restorani/la_vida/krem_syp.jfif',
    category: 'Супы',
  ),
  Dish(
    name: 'Солянка',
    description: '380 г',
    price: 8.5,
    imagePath: 'assets/images/restorani/la_vida/solyanka.png',
    category: 'Супы',
  ),
  Dish(
    name: 'Зама',
    description: '360 г',
    price: 8.0,
    imagePath: 'assets/images/restorani/la_vida/zama.jfif',
    category: 'Супы',
  ),
  Dish(
    name: 'Суп из нута с томленной лопаткой',
    description: '340 г',
    price: 9.0,
    imagePath: 'assets/images/restorani/la_vida/noot.png',
    category: 'Супы',
  ),

// Горячие блюда
  Dish(
    name: 'Стейк свиной',
    description: '320 г',
    price: 15.0,
    imagePath: 'assets/images/restorani/la_vida/steak.jfif',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Шашлык свиной',
    description: '370 г',
    price: 14.0,
    imagePath: 'assets/images/restorani/la_vida/shashlik.jfif',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Колбаски куриные на гриле',
    description: '340 г',
    price: 12.0,
    imagePath: 'assets/images/restorani/la_vida/kolbaski.png',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Шашлык куриный',
    description: '360 г',
    price: 13.0,
    imagePath: 'assets/images/restorani/la_vida/kyr_shahlik.jfif',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Пита греческая со свининой',
    description: '450 г',
    price: 16.0,
    imagePath: 'assets/images/restorani/la_vida/pita.png',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Лазанья куриная',
    description: '420 г',
    price: 14.5,
    imagePath: 'assets/images/restorani/la_vida/lazania.png',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Котлета по-киевски',
    description: '330 г',
    price: 13.5,
    imagePath: 'assets/images/restorani/la_vida/kiev.jfif',
    category: 'Горячие блюда',
  ),
  Dish(
    name: 'Паста с лососем',
    description: '300 г',
    price: 12.5,
    imagePath: 'assets/images/restorani/la_vida/pasta_losos.png',
    category: 'Горячие блюда',
  ),

// Закуски
  Dish(
    name: 'Крылышки Биг',
    description: '810 г',
    price: 15.0,
    imagePath: 'assets/images/restorani/la_vida/kril_big.png',
    category: 'Закуски',
  ),
  Dish(
    name: 'Ассорти гриль',
    description: '1310 г',
    price: 25.0,
    imagePath: 'assets/images/restorani/la_vida/asorti_grill.jfif',
    category: 'Закуски',
  ),
  Dish(
    name: 'Пивное плато',
    description: '730 г',
    price: 18.0,
    imagePath: 'assets/images/restorani/la_vida/pivnoe_plato.png',
    category: 'Закуски',
  ),
  Dish(
    name: 'Куриное филе в панировке Биг',
    description: '610 г',
    price: 16.0,
    imagePath: 'assets/images/restorani/la_vida/kyr_file.jfif',
    category: 'Закуски',
  ),

// Десерты
  Dish(
    name: 'Мороженое тропическое',
    description: '310 г',
    price: 7.0,
    imagePath: 'assets/images/restorani/la_vida/tropic.png',
    category: 'Десерты',
  ),
  Dish(
    name: 'Фруктовый салат',
    description: '250 г',
    price: 6.5,
    imagePath: 'assets/images/restorani/la_vida/fruct.png',
    category: 'Десерты',
  ),
  Dish(
    name: 'Чизкейк',
    description: '140 г',
    price: 5.5,
    imagePath: 'assets/images/restorani/la_vida/chizk.png',
    category: 'Десерты',
  ),
  Dish(
    name: 'Банан сплит',
    description: '280 г',
    price: 7.5,
    imagePath: 'assets/images/restorani/la_vida/banan_split.png',
    category: 'Десерты',
  ),

// Детское меню
  Dish(
    name: 'Бургер мини',
    description: '240 г',
    price: 6.0,
    imagePath: 'assets/images/restorani/la_vida/byr_mini.jfif',
    category: 'Детское меню',
  ),
  Dish(
    name: 'Суп с фрикадельками',
    description: '300 г',
    price: 5.5,
    imagePath: 'assets/images/restorani/la_vida/syp.jfif',
    category: 'Детское меню',
  ),
  Dish(
    name: 'Какао',
    description: '200 мл',
    price: 3.0,
    imagePath: 'assets/images/restorani/la_vida/cacao.jfif',
    category: 'Детское меню',
  ),
  Dish(
    name: 'Стимер',
    description: '250 г',
    price: 4.0,
    imagePath: 'assets/images/restorani/la_vida/stimer.png',
    category: 'Детское меню',
  ),

// Напитки
  Dish(
    name: 'Ананасовый сок',
    description: '1000 мл',
    price: 5.0,
    imagePath: 'assets/images/restorani/la_vida/ananas.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Яблочный сок',
    description: '1000 мл',
    price: 5.0,
    imagePath: 'assets/images/restorani/la_vida/apple.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Коктейль кофейный',
    description: '300 мл',
    price: 6.0,
    imagePath: 'assets/images/restorani/la_vida/coffe.jfif',
    category: 'Напитки',
  ),
  Dish(
    name: 'Коктейль шоколадное печенье',
    description: '300 мл',
    price: 6.5,
    imagePath: 'assets/images/restorani/la_vida/shokolad.jfif',
    category: 'Напитки',
  ),
  Dish(
    name: 'Лимонный фреш',
    description: '200 мл',
    price: 4.5,
    imagePath: 'assets/images/restorani/la_vida/lime.png',
    category: 'Напитки',
  ),
  Dish(
    name: 'Апельсиновый фреш',
    description: '200 мл',
    price: 4.5,
    imagePath: 'assets/images/restorani/la_vida/apelsin.png',
    category: 'Напитки',
  ),

// Крепкие напитки
  Dish(
    name: 'Апероль Сприц',
    description: '350 мл',
    price: 8.0,
    imagePath: 'assets/images/restorani/la_vida/sprits.png',
    category: 'Крепкие напитки',
  ),
  Dish(
    name: 'Персиковый Негрони',
    description: '285 мл',
    price: 9.0,
    imagePath: 'assets/images/restorani/la_vida/negroni.png',
    category: 'Крепкие напитки',
  ),
  Dish(
    name: 'Виски Гамми',
    description: '200 мл',
    price: 10.0,
    imagePath: 'assets/images/restorani/la_vida/viski.png',
    category: 'Крепкие напитки',
  ),
  Dish(
    name: 'Джин-тоник лесные ягоды',
    description: '500 мл',
    price: 9.5,
    imagePath: 'assets/images/restorani/la_vida/lesnie.jfif',
    category: 'Крепкие напитки',
  ),
];

void openLaVidaMenu(BuildContext context, void Function(Dish, String) addToCart) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantMenuScreen(
        restaurantName: 'LA VIDA',
        menu: laVidaMenu,
        shopId: 'la_vida',    // 🔹 корректный shopId
        addToCart: addToCart, // 🔹 передаем функцию добавления
      ),
    ),
  );
}
