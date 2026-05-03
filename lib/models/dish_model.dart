import 'package:cloud_firestore/cloud_firestore.dart';

class Dish {
  final String name;
  final String description;
  final double price;
  final String imagePath;
  final String category;
  final String weight; // 🔹 Добавили поле веса

  Dish({
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.category,
    required this.weight, // 🔹 Теперь обязательно
  });

  factory Dish.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Пытаемся достать цену, даже если она пришла как строка
    double parsePrice(dynamic p) {
      if (p is num) return p.toDouble();
      if (p is String) return double.tryParse(p) ?? 0.0;
      return 0.0;
    }

    return Dish(
      // 🔹 Проверяем и 'title' (как мы загрузили) и 'name'
      name: data['title'] ?? data['name'] ?? 'Без названия',

      description: data['description'] ?? '',

      price: parsePrice(data['price']),

      // 🔹 Проверяем и 'imageUrl' (как мы загрузили) и 'imagePath'
      imagePath: data['imageUrl'] ?? data['imagePath'] ?? '',

      category: data['category'] ?? 'Общее',

      // 🔹 Достаем вес (если нет, ставим "0")
      weight: (data['weight'] ?? '0').toString(),
    );
  }
}