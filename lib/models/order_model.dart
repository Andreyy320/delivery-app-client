import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../screens/Menu/Cart_data.dart';
import 'dish_model.dart';

class Order {
  final String id; // Это поле теперь будет работать правильно

  final List<CartItem> items;
  final LatLng deliveryLocation;
  final String comment;
  final String paymentMethod;
  final double total;
  final DateTime dateTime;
  final String status;
  final String? shopId;

  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? deliveredAt;

  Order({
    required this.id, // ID обязателен
    required this.items,
    required this.deliveryLocation,
    required this.comment,
    required this.paymentMethod,
    required this.total,
    required this.dateTime,
    required this.status,
    this.shopId,
    this.startedAt,
    this.readyAt,
    this.acceptedAt,
    this.inProgressAt,
    this.deliveredAt,
  });

  Map<String, dynamic> toJson() => {
    // ID обычно не пишем в само тело JSON, так как он является именем документа
    'items': items.map((e) => {
      'name': e.dish.name,
      'price': e.dish.price,
      'description': e.dish.description,
      'category': e.dish.category,
      'imagePath': e.dish.imagePath,
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
    'dateTime': dateTime.toIso8601String(),
    'status': status,
    'shopId': shopId,
    'startedAt': startedAt?.toIso8601String(),
    'readyAt': readyAt?.toIso8601String(),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'inProgressAt': inProgressAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  /// Создание из JSON (добавил String id как аргумент)
  factory Order.fromJson(String id, Map<String, dynamic> json) {
    return Order(
      id: id, // ПРИСВАИВАЕМ ID
      items: (json['items'] as List).map((e) => CartItem(
        dish: Dish(
          name: e['name'],
          price: (e['price'] as num).toDouble(),
          description: e['description'],
          category: e['category'],
          imagePath: e['imagePath'],
        ),
        quantity: e['quantity'],
        shopId: e['shopId'] ?? 'default',
      )).toList(),
      deliveryLocation: LatLng(json['deliveryLocation']['lat'], json['deliveryLocation']['lng']),
      comment: json['comment'],
      paymentMethod: json['paymentMethod'],
      total: (json['total'] as num).toDouble(),
      dateTime: DateTime.parse(json['dateTime']),
      status: json['status'] ?? 'preparing',
      shopId: json['shopId'],
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      readyAt: json['readyAt'] != null ? DateTime.parse(json['readyAt']) : null,
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt']) : null,
      inProgressAt: json['inProgressAt'] != null ? DateTime.parse(json['inProgressAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
    );
  }

  /// Создание из Firestore (исправил присвоение ID)
  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    // В Firestore обычно используется createdAt (Timestamp),
    // проверим разные варианты ключей для даты
    DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['dateTime'] is String ? DateTime.parse(data['dateTime']) : DateTime.now());

    DateTime? _parseTimestamp(String key) {
      var val = data[key];
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Order(
      id: id, // ПРИСВАИВАЕМ ID ИЗ ДОКУМЕНТА
      items: (data['items'] as List<dynamic>).map((e) => CartItem(
        dish: Dish(
          name: e['name'] ?? e['dish'] ?? 'Без имени',
          price: (e['price'] as num).toDouble(),
          description: e['description'] ?? '',
          category: e['category'] ?? '',
          imagePath: e['imagePath'] ?? 'assets/default.png',
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
      total: (data['total'] as num).toDouble(),
      dateTime: date,
      status: data['status'] ?? 'preparing',
      shopId: data['shopId'],
      readyAt: _parseTimestamp('readyAt'),
      startedAt: _parseTimestamp('startedAt'),
      acceptedAt: _parseTimestamp('acceptedAt'),
      inProgressAt: _parseTimestamp('inProgressAt'),
      deliveredAt: _parseTimestamp('deliveredAt'),
    );
  }
}