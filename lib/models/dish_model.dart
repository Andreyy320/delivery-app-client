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

  // 🔹 Добавлено для корректной сериализации в JSON (при оформлении заказа)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'weight': weight,
    };
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

  // 🔹 Добавлено для корректной сериализации в JSON (при оформлении заказа)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
    };
  }
}

class Dish {
  final String id; // Поле id для полноценной работы с базой
  final String name;
  final String description;
  final double price;
  final String imagePath;
  final String category;
  final String weight;
  final List<DishSize> sizes;
  final List<DishModifier> modifiers;
  final bool isAvailable;

  Dish({
    this.id = '',
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.category,
    this.weight = '0',
    this.sizes = const [],
    this.modifiers = const [],
    this.isAvailable = true,
  });

  // Удобные геттеры для совместимости
  List<DishSize> get size => sizes;
  List<DishSize> get sizesList => sizes;

  // 🔹 Добавляем поддержку оператора '[]', чтобы обращение к полям через dish['...'] работало без ошибок
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
      case 'title':
        return name;
      case 'description':
        return description;
      case 'price':
        return price;
      case 'imagePath':
      case 'image_path':
      case 'imageUrl':
        return imagePath;
      case 'category':
        return category;
      case 'weight':
        return weight;
      case 'sizes':
      case 'size':
        return sizes;
      case 'modifiers':
        return modifiers;
      case 'isAvailable':
      case 'is_available':
        return isAvailable;
      default:
        return null;
    }
  }

  // Конструктор для работы с JSON от твоего Node.js сервера
  factory Dish.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic p) {
      if (p is num) return p.toDouble();
      if (p is String) return double.tryParse(p) ?? 0.0;
      return 0.0;
    }

    List<DishSize> parsedSizes = [];
    final sizeData = json['size'] ?? json['sizes'];
    if (sizeData != null && sizeData is List) {
      parsedSizes = sizeData
          .map((item) => DishSize.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<DishModifier> parsedModifiers = [];
    if (json['modifiers'] != null && json['modifiers'] is List) {
      parsedModifiers = (json['modifiers'] as List)
          .map((item) => DishModifier.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Достаем имя блюда для fallback, если id не передан
    final String parsedName = json['title'] ?? json['name'] ?? 'Без названия';

    // Безопасно вытаскиваем ID из разных возможных вариантов в JSON
    final String parsedId = (json['id'] ?? json['_id'] ?? json['dish_id'] ?? parsedName).toString();

    return Dish(
      id: parsedId,
      name: parsedName,
      description: json['description'] ?? '',
      price: parsePrice(json['price']),
      imagePath: json['image_path'] ?? json['imageUrl'] ?? json['imagePath'] ?? '',
      category: json['category'] ?? 'Общее',
      weight: (json['weight'] ?? '0').toString(),
      sizes: parsedSizes,
      modifiers: parsedModifiers,
      isAvailable: json['is_available'] ?? json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imagePath': imagePath,
      'category': category,
      'weight': weight,
      'sizes': sizes.map((s) => s.toJson()).toList(),
      'modifiers': modifiers.map((m) => m.toJson()).toList(),
      'isAvailable': isAvailable,
    };
  }
}