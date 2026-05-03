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
  final DateTime dateTime;
  final String status;
  final String? shopId;
  final String? restaurantName; // 🔹 НОВОЕ: Название заведения
  final String type;

  final String? courierId;

  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? deliveredAt;

  double get clientLat => deliveryLocation.latitude;
  double get clientLng => deliveryLocation.longitude;

  Order({
    required this.id,
    required this.items,
    required this.deliveryLocation,
    required this.comment,
    required this.paymentMethod,
    required this.total,
    required this.dateTime,
    required this.status,
    required this.type,
    this.courierId,
    this.shopId,
    this.restaurantName, // 🔹 Добавляем в конструктор
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
    'type': type,
    'courierId': courierId,
    'shopId': shopId,
    'restaurantName': restaurantName, // 🔹 Сохраняем название
    'startedAt': startedAt?.toIso8601String(),
    'readyAt': readyAt?.toIso8601String(),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'inProgressAt': inProgressAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  factory Order.fromJson(String id, Map<String, dynamic> json) {
    return Order(
      id: id,
      items: (json['items'] as List).map((e) => CartItem(
        dish: Dish(
          name: e['name'],
          price: (e['price'] as num).toDouble(),
          description: e['description'],
          category: e['category'],
          imagePath: e['imagePath'],
          weight: e['weight'] ?? '0',
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
      type: json['category'] ?? 'restaurant',
      courierId: json['courierId'],
      shopId: json['shopId'],
      restaurantName: json['restaurantName'], // 🔹 Читаем название
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
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Order(
      id: id,
      items: (data['items'] as List<dynamic>).map((e) => CartItem(
        dish: Dish(
          name: e['name'] ?? e['dish'] ?? 'Без имени',
          price: (e['price'] as num).toDouble(),
          description: e['description'] ?? '',
          category: e['category'] ?? '',
          imagePath: e['imagePath'] ?? e['imageUrl'] ?? '',
          weight: e['weight']?.toString() ?? '0',
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
      type: data['category'] ?? 'restaurant',
      courierId: data['courierId'],
      shopId: data['shopId'],
      restaurantName: data['restaurantName'], // 🔹 Читаем название из Firestore
      readyAt: _parseTimestamp('readyAt'),
      startedAt: _parseTimestamp('startedAt'),
      acceptedAt: _parseTimestamp('acceptedAt'),
      inProgressAt: _parseTimestamp('inProgressAt'),
      deliveredAt: _parseTimestamp('deliveredAt'),
    );
  }
}