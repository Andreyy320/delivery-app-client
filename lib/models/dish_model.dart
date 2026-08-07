import 'package:cloud_firestore/cloud_firestore.dart';

class DishSize {
  final String name;
  final double price;
  final String weight;

  DishSize({
    required this.name,
    required this.price,
    required this.weight,
  });

  factory DishSize.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic p) {
      if (p is num) return p.toDouble();
      if (p is String) return double.tryParse(p) ?? 0.0;
      return 0.0;
    }

    return DishSize(
      name: json['name']?.toString() ?? '',
      price: parsePrice(json['price']),
      weight: (json['weight'] ?? '0').toString(),
    );
  }
}

class DishModifier {
  final String name;
  final double price;

  DishModifier({
    required this.name,
    required this.price,
  });

  factory DishModifier.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic p) {
      if (p is num) return p.toDouble();
      if (p is String) return double.tryParse(p) ?? 0.0;
      return 0.0;
    }

    return DishModifier(
      name: json['name']?.toString() ?? '',
      price: parsePrice(json['price']),
    );
  }
}

class Dish {
  final String name;
  final String description;
  final double price;
  final String imagePath;
  final String category;
  final String weight;
  final List<DishSize> sizes;
  final List<DishModifier> modifiers;

  Dish({
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.category,
    this.weight = '0',         // 🔹 Необязательным со значением по умолчанию
    this.sizes = const [],     // 🔹 Пустой список по умолчанию
    this.modifiers = const [], // 🔹 Пустой список по умолчанию
  });

  // 🔹 Удобные геттеры для совместимости со старым кодом, обращающимся к dish.size
  List<DishSize> get size => sizes;
  List<DishSize> get sizesList => sizes;

  factory Dish.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    double parsePrice(dynamic p) {
      if (p is num) return p.toDouble();
      if (p is String) return double.tryParse(p) ?? 0.0;
      return 0.0;
    }

    List<DishSize> parsedSizes = [];
    if (data['size'] != null && data['size'] is List) {
      parsedSizes = (data['size'] as List)
          .map((item) => DishSize.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<DishModifier> parsedModifiers = [];
    if (data['modifiers'] != null && data['modifiers'] is List) {
      parsedModifiers = (data['modifiers'] as List)
          .map((item) => DishModifier.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return Dish(
      name: data['title'] ?? data['name'] ?? 'Без названия',
      description: data['description'] ?? '',
      price: parsePrice(data['price']),
      imagePath: data['imageUrl'] ?? data['imagePath'] ?? '',
      category: data['category'] ?? 'Общее',
      weight: (data['weight'] ?? '0').toString(),
      sizes: parsedSizes,
      modifiers: parsedModifiers,
    );
  }
}