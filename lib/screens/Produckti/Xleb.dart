import 'package:flutter/material.dart';
import 'package:untitled1/screens/Produckti/product_screen.dart';
import '../../models/dish_model.dart';


final xleb_menu = [
// Роллы
  Dish(
    name: 'Батон "Фирменный"',
    description: 'Состав: мука пшеничная, вода питьевая, дрожжи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/baton1.jpg',
    category: 'Батоны',
  ),
  Dish(
    name: 'Батон "Отрубной"',
    description: 'Состав: мука пшеничная, вода питьевая, дрожжи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/baton2.jpg',
    category: 'Батоны',
  ),
  Dish(
    name: 'Батон "Витебский"',
    description: 'Состав: мука ржаная, мука пшеничная, вода, сахар, дрожжи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/baton3.jpg',
    category: 'Батоны',
  ),


  Dish(
    name: 'Хлеб "Особый"',
    description: 'Состав: мука пшеничная, мука ржаная, вода, сахар, кунжут, соль, хлопья овсяные.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/xleb1.jpg',
    category: 'Хлеба',
  ),
  Dish(
    name: 'Хлеб "Аппетитный"',
    description: 'Состав: мука пшеничная, мука ржаная, вода, сахар, кунжут, соль',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/xleb2.jpg',
    category: 'Хлеба',
  ),
  Dish(
    name: 'Хлеб "С отрубями"',
    description: 'Состав: мука пшеничная, мука ржаная, вода, отруби, дрожжи, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/xleb3.jpg',
    category: 'Хлеба',
  ),


  Dish(
    name: 'Булочка "Детская"',
    description: 'Состав: мука пшенична, вода, сахар, стружка кокосовая, дрожжи, маргарин легкий.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/bul1.jpg',
    category: 'Булочки',
  ),
  Dish(
    name: 'Крендель',
    description: 'Состав: мука пшеничная, вода питьевая, сахар, дрожжи, яйца.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/bul2.jpg',
    category: 'Булочки',
  ),
  Dish(
    name: 'Булочка "Хот-дог"',
    description: 'Состав: мука пшеничная, вода, дрожжи, сахар, яйца, молоко сухое, соль.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/bul3.jpg',
    category: 'Булочки',
  ),


  Dish(
    name: 'Рогалики "С маком"',
    description: 'Состав: мука пшеничная, вода, сахар, яйца, молоко сухое обезжиренное, соль, маргарин.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/pes1.jpg',
    category: 'Печенье',
  ),
  Dish(
    name: 'Печенье "Кукурузное"',
    description: 'Состав: мука кукурузная, мука пшеничная, сахар, маргарин молочный.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/pes2.jpg',
    category: 'Печенье',
  ),
  Dish(
    name: 'Печенье "Американо ванильное"',
    description: 'Состав: мука пшеничная, сахар, яйца куриные, маргарин молочный.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/pes3.jpg',
    category: 'Печенье',
  ),


  Dish(
    name: 'Пирожное "Наполеон"',
    description: 'Состав: мука пшеничная, соль, сахар, яйца куриные, молоко.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/pir1.jpg',
    category: 'Пирожные',
  ),
  Dish(
    name: 'Пирожное "Смайлик"',
    description: 'Состав: сахар, мука пшеничная, яйца куриные, молоко сгущенное, маргарин.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/pir2.jpg',
    category: 'Пирожные',
  ),
  Dish(
    name: 'Пирожное "Заварное"',
    description: 'Состав: мука пшеничная, молоко цельное, яйца куриные, сахар, маргарин.',
    price: 2200,
    imagePath: 'assets/images/Producti/Xleb/pir3.jpg',
    category: 'Пирожные',
  )
];

void openXlebMenu(
    BuildContext context,
    void Function(Dish, String) addToCart, // 🔹 функция добавления
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductMenuScreen(
        restaurantName: 'Хлебокомбинат',
        menu: xleb_menu,
        shopId: 'xleb',
      ),
    ),
  );
}
