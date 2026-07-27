import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class DeliveryOrder {
  final String id;
  final LatLng pickup;
  final LatLng dropoff;

  // Текстовые адреса из мап pickup и dropoff
  final String? pickupAddress;
  final String? dropoffAddress;

  // Данные клиента (кто создал заказ)
  final String? clientName;
  final String? clientPhone;
  final String? clientId;

  // Данные получателя (если заказ получает другой человек)
  final String? recipientName;
  final String? recipientPhone;

  // Комментарий к заказу
  final String? comment;

  final List<String> options;
  final double totalCost;
  final double? itemsPrice;
  final double? deliveryPrice;
  final double? distanceKm;
  final int? durationMin;
  final String status;
  final DateTime createdAt;
  final String type;

  // Поля для прогресс-бара
  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? deliveredAt;

  // Остальное
  final String? bodyType;
  final int? loaders;
  final int? escort;
  final DateTime? scheduledTime;
  final String? restaurantName;
  final String? shopId;
  final String? courierId;

  DeliveryOrder({
    required this.id,
    required this.pickup,
    required this.dropoff,
    this.pickupAddress,
    this.dropoffAddress,
    this.clientName,
    this.clientPhone,
    this.clientId,
    this.recipientName,
    this.recipientPhone,
    this.comment,
    required this.options,
    required this.totalCost,
    this.itemsPrice,
    this.deliveryPrice,
    this.distanceKm,
    this.durationMin,
    required this.status,
    required this.createdAt,
    this.type = 'delivery',
    this.acceptedAt,
    this.inProgressAt,
    this.deliveredAt,
    this.bodyType,
    this.loaders,
    this.escort,
    this.scheduledTime,
    this.restaurantName,
    this.shopId,
    this.courierId,
  });

  factory DeliveryOrder.fromFirestore(String id, Map<String, dynamic> map) {
    final pickupMap = map['pickup'] as Map<String, dynamic>? ?? {};
    final dropoffMap = map['dropoff'] as Map<String, dynamic>? ?? {};

    return DeliveryOrder(
      id: id,
      pickup: LatLng(
        (pickupMap['lat'] ?? map['shopLat'] ?? 0).toDouble(),
        (pickupMap['lon'] ?? pickupMap['lng'] ?? map['shopLng'] ?? 0).toDouble(),
      ),
      dropoff: LatLng(
        (dropoffMap['lat'] ?? dropoffMap['latitude'] ?? map['clientLat'] ?? 0).toDouble(),
        (dropoffMap['lon'] ?? dropoffMap['lng'] ?? dropoffMap['longitude'] ?? map['clientLng'] ?? 0).toDouble(),
      ),

      // Корректно достаем адреса из карт
      pickupAddress: pickupMap['address'] ?? map['restaurantAddress'],
      dropoffAddress: dropoffMap['address'] ?? map['clientAddress'] ?? map['address'],

      // Данные клиента, телефона и ID
      clientName: map['clientName'] ?? map['name'],
      clientPhone: map['clientPhone'] ?? map['phone'],
      clientId: map['clientId'] ?? map['userId'],

      // Данные получателя (с поддержкой возможных альтернативных ключей)
      recipientName: map['recipientName'] ?? map['recipient_name'],
      recipientPhone: map['recipientPhone'] ?? map['recipient_phone'],

      // Комментарий к заказу (поддержка 'comment' и старого 'de')
      comment: map['comment'] ?? map['de'],

      options: List<String>.from(map['options'] ?? []),
      totalCost: (map['total_cost'] ?? map['totalCost'] ?? map['total'] ?? map['totalPrice'] ?? 0).toDouble(),
      itemsPrice: (map['itemsPrice'] ?? map['items_price'])?.toDouble(),
      deliveryPrice: (map['deliveryPrice'] ?? map['delivery_price'])?.toDouble(),

      distanceKm: (map['distance_km'] ?? map['distanceKm'])?.toDouble(),
      durationMin: (map['duration_min'] ?? map['durationMin'])?.toInt(),
      status: map['status'] ?? 'new',

      // Обработка даты создания
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),

      type: map['type'] ?? 'delivery',

      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      inProgressAt: (map['inProgressAt'] as Timestamp?)?.toDate(),
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),

      bodyType: map['bodyType'],
      loaders: map['loaders'],
      escort: map['escort'],
      scheduledTime: (map['scheduledTime'] as Timestamp?)?.toDate(),
      restaurantName: map['restaurantName'] ?? map['shopName'],
      shopId: map['shopId'],
      courierId: map['courierId'],
    );
  }
}