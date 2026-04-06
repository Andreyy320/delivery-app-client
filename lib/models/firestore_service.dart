import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';

Future<List<Dish>> fetchMenu(String shopId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('establishments')      // тип заведения
      .doc('restaurants')                // коллекция рестораны
      .collection(shopId)                // конкретный ресторан
      .doc(shopId)                       // id ресторана
      .collection('dishes')              // блюда
      .get();

  return snapshot.docs.map((doc) => Dish.fromJson(doc.data())).toList();
}
