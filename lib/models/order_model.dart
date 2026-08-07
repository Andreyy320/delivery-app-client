import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    'startedAt': startedAt?.toIso8601String(),
    'readyAt': readyAt?.toIso8601String(),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'inProgressAt': inProgressAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  factory Order.fromJson(String id, Map<String, dynamic> json) {
    return Order(
      id: id,
      items: (json['items'] as List? ?? []).map((e) => CartItem(
        dish: Dish(
          name: e['name'] ?? '',
          price: (e['price'] as num?)?.toDouble() ?? 0.0,
          description: e['description'] ?? '',
          category: e['category'] ?? '',
          imagePath: e['imagePath'] ?? '',
          weight: e['weight']?.toString() ?? '0',
          sizes: (e['sizes'] as List<dynamic>?)
              ?.map((s) => DishSize.fromJson(s as Map<String, dynamic>))
              .toList() ?? [],
          modifiers: (e['modifiers'] as List<dynamic>?)
              ?.map((m) => DishModifier.fromJson(m as Map<String, dynamic>))
              .toList() ?? [],
        ),
        quantity: e['quantity'] ?? 1,
        shopId: e['shopId'] ?? 'default',
      )).toList(),
      deliveryLocation: LatLng(
        (json['deliveryLocation']?['lat'] as num? ?? 0.0).toDouble(),
        (json['deliveryLocation']?['lng'] as num? ?? 0.0).toDouble(),
      ),
      comment: json['comment'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'online',
      total: ((json['total'] ?? json['totalPrice'] ?? 0.0) as num).toDouble(),
      itemsPrice: ((json['itemsPrice'] ?? 0.0) as num).toDouble(),
      deliveryPrice: ((json['deliveryPrice'] ?? 0.0) as num).toDouble(),
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : DateTime.now(),
      status: json['status'] ?? 'preparing',
      type: json['category'] ?? 'restaurant',
      replacements: json['replacements'] != null
          ? List<Map<String, dynamic>>.from(json['replacements'])
          : null,
      courierId: json['courierId'],
      shopId: json['shopId'],
      restaurantName: json['restaurantName'],
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      readyAt: json['readyAt'] != null ? DateTime.parse(json['readyAt']) : null,
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt']) : null,
      inProgressAt: json['inProgressAt'] != null ? DateTime.parse(json['inProgressAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
    );
  }

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['dateTime'] is String ? DateTime.parse(data['dateTime']) : DateTime.now());

    DateTime? _parseTimestamp(String key) {
      var val = data[key];
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val.toString());
      return null;
    }

    return Order(
      id: id,
      items: (data['items'] as List<dynamic>? ?? []).map((e) => CartItem(
        dish: Dish(
          name: e['name'] ?? e['dish'] ?? 'Без имени',
          price: (e['price'] as num?)?.toDouble() ?? 0.0,
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
        quantity: e['quantity'] ?? 1,
        shopId: e['shopId'] ?? 'default',
      )).toList(),
      deliveryLocation: LatLng(
        (data['deliveryLocation']?['lat'] ?? 0).toDouble(),
        (data['deliveryLocation']?['lng'] ?? 0).toDouble(),
      ),
      comment: data['comment'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'online',
      total: ((data['total'] ?? data['totalPrice'] ?? 0.0) as num).toDouble(),
      itemsPrice: ((data['itemsPrice'] ?? 0.0) as num).toDouble(),
      deliveryPrice: ((data['deliveryPrice'] ?? 0.0) as num).toDouble(),
      dateTime: date,
      status: data['status'] ?? 'preparing',
      type: data['category'] ?? 'restaurant',
      replacements: data['replacements'] != null
          ? List<Map<String, dynamic>>.from(data['replacements'])
          : null,
      courierId: data['courierId'],
      shopId: data['shopId'],
      restaurantName: data['restaurantName'],
      readyAt: _parseTimestamp('readyAt'),
      startedAt: _parseTimestamp('startedAt'),
      acceptedAt: _parseTimestamp('acceptedAt'),
      inProgressAt: _parseTimestamp('inProgressAt'),
      deliveredAt: _parseTimestamp('deliveredAt'),
    );
  }
}