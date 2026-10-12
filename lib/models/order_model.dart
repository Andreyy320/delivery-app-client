import 'dart:convert';

import 'package:latlong2/latlong.dart';
import '../screens/Menu/Cart_data.dart';
import 'dish_model.dart';

class Order {
  final String id;
  final List<CartItem> items;
  final LatLng deliveryLocation;
  final String comment;
  final String paymentMethod;
  final double total;
  final double itemsPrice; // 🔹 Сумма только за товары
  final double deliveryPrice;
  final DateTime dateTime;
  final String status;
  final String? shopId;
  final String? restaurantName;
  final String? restaurantImage; // 🔹 Поле для картинки/логотипа ресторана
  final String type;
  final List<Map<String, dynamic>>? replacements; // 🔹 Поле для замен

  final String? courierId;

  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? deliveredAt;

  // 🔹 Геттер totalPrice для совместимости с внешним кодом (возвращает total)
  double get totalPrice => total;

  double get clientLat => deliveryLocation.latitude;
  double get clientLng => deliveryLocation.longitude;

  Order({
    required this.id,
    required this.items,
    required this.deliveryLocation,
    required this.comment,
    required this.paymentMethod,
    required this.total,
    this.itemsPrice = 0.0,
    required this.deliveryPrice,
    required this.dateTime,
    required this.status,
    required this.type,
    this.replacements,
    this.courierId,
    this.shopId,
    this.restaurantName,
    this.restaurantImage,
    this.startedAt,
    this.readyAt,
    this.acceptedAt,
    this.inProgressAt,
    this.deliveredAt,
  });

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => {
      'name': e.dish.name,
      'price': e.dish.price,
      'description': e.dish.description,
      'category': e.dish.category,
      'imagePath': e.dish.imagePath,
      'weight': e.dish.weight,
      // 🔹 Сохраняем размеры и модификаторы блюда в заказе
      'sizes': e.dish.sizes.map((s) => {'name': s.name, 'price': s.price, 'weight': s.weight}).toList(),
      'modifiers': e.dish.modifiers.map((m) => {'name': m.name, 'price': m.price}).toList(),
      'quantity': e.quantity,
      'shopId': e.shopId,
    }).toList(),
    'deliveryLocation': {
      'lat': deliveryLocation.latitude,
      'lng': deliveryLocation.longitude
    },
    'comment': comment,
    'paymentMethod': paymentMethod,
    'total': total,
    'totalPrice': total,
    'itemsPrice': itemsPrice,
    'deliveryPrice': deliveryPrice,
    'dateTime': dateTime.toIso8601String(),
    'status': status,
    'type': type,
    'replacements': replacements,
    'courierId': courierId,
    'shopId': shopId,
    'restaurantName': restaurantName,
    'restaurant_image': restaurantImage,
    'startedAt': startedAt?.toIso8601String(),
    'readyAt': readyAt?.toIso8601String(),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'inProgressAt': inProgressAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  factory Order.fromJson(String id, Map<String, dynamic> json) {
    // Вспомогательная функция для безопасного парсинга чисел
    double parseNum(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    // Безопасное извлечение и декодирование списка товаров (items)
    List<dynamic> itemsList = [];
    var rawItems = json['replacements'];
    print('DEBUG: Поле replacements имеет тип: ${rawItems.runtimeType}');
    print('DEBUG: Содержимое items: $rawItems');
    if (rawItems is String) {
      try {
        String cleanString = rawItems.replaceAll('""', '"');
        itemsList = jsonDecode(cleanString) as List? ?? [];
      } catch (_) {
        itemsList = [];
      }
    } else if (rawItems is List) {
      itemsList = rawItems;
    }

    return Order(
      id: id.isNotEmpty ? id : (json['id']?.toString() ?? ''),
      items: itemsList.map((e) => CartItem(
        dish: Dish(
          name: e['name'] ?? '',
          price: parseNum(e['price']),
          description: e['description'] ?? '',
          category: e['category'] ?? '',
          imagePath: e['imagePath'] ?? e['imageUrl'] ?? '',
          weight: e['weight']?.toString() ?? '0',
          sizes: (e['sizes'] as List<dynamic>?)
              ?.map((s) => DishSize.fromJson(s as Map<String, dynamic>))
              .toList() ?? [],
          modifiers: (e['modifiers'] as List<dynamic>?)
              ?.map((m) => DishModifier.fromJson(m as Map<String, dynamic>))
              .toList() ?? [],
        ),
        quantity: parseInt(e['quantity'] ?? 1),
        shopId: e['shopId']?.toString() ?? 'default',
      )).toList(),
      deliveryLocation: LatLng(
        parseNum(json['client_lat'] ?? json['deliveryLocation']?['lat']),
        parseNum(json['client_lng'] ?? json['deliveryLocation']?['lng']),
      ),
      comment: json['comment'] ?? '',
      paymentMethod: json['payment_method'] ?? json['paymentMethod'] ?? 'online',
      total: parseNum(json['total_price'] ?? json['total'] ?? json['totalPrice']),
      itemsPrice: parseNum(json['items_price'] ?? json['itemsPrice']),
      deliveryPrice: parseNum(json['delivery_price'] ?? json['deliveryPrice']),
      dateTime: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['dateTime'] != null ? DateTime.parse(json['dateTime']) : DateTime.now()),
      status: json['status'] ?? 'preparing',
      type: json['type'] ?? json['category'] ?? 'restaurant',
      replacements: json['replacements'] is List
          ? List<Map<String, dynamic>>.from(json['replacements'])
          : null,
      courierId: json['courier_id']?.toString() ?? json['courierId'],
      shopId: json['shop_id']?.toString() ?? json['shopId'],
      restaurantName: json['restaurant_name'] ?? json['restaurantName'],
      restaurantImage: json['restaurant_image'] ?? json['restaurantImage'],
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      readyAt: json['ready_at'] != null ? DateTime.parse(json['ready_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      inProgressAt: json['in_progress_at'] != null ? DateTime.parse(json['in_progress_at']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
    );
  }

}