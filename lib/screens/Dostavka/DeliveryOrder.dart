import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class DeliveryOrder {
  final String id;
  final LatLng pickup;
  final LatLng dropoff;

  final String? pickupAddress;
  final String? dropoffAddress;
  final String? subType;
  final String? description;
  final String? clientName;
  final String? clientPhone;
  final String? clientId;
  final String? recipientName;
  final String? recipientPhone;
  final String? comment;

  final List<String> options;
  final double totalCost;
  final double? itemsPrice;
  final double? deliveryPrice;

  final double? distanceKm;
  final int? durationMin;

  double? get distance_km => distanceKm;
  int? get duration_min => durationMin;

  final String status;
  final DateTime createdAt;
  final String type;

  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? deliveredAt;

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
    this.subType,
    this.description,
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
        (dropoffMap['lon'] ?? dropoffMap['lng'] ?? map['clientLng'] ?? 0).toDouble(),
      ),

      // 🛠 Исправлено: теперь сначала ищем прямо в корне (`map['pickupAddress']`), как у тебя в базе
      pickupAddress: map['pickupAddress'] ?? pickupMap['address'] ?? map['restaurantAddress'],
      dropoffAddress: map['dropoffAddress'] ?? dropoffMap['address'] ?? map['clientAddress'] ?? map['address'],

      subType: map['subType'],
      description: map['description'] ?? map['comment'] ?? map['de'],
      clientName: map['clientName'] ?? map['name'],
      clientPhone: map['clientPhone'] ?? map['phone'],
      clientId: map['clientId'] ?? map['userId'],
      recipientName: map['receiverName'] ?? map['recipientName'] ?? map['recipient_name'],
      recipientPhone: map['receiverPhone'] ?? map['recipientPhone'] ?? map['recipient_phone'],
      comment: map['comment'] ?? map['de'],
      options: List<String>.from(map['options'] ?? []),
      totalCost: (map['total_cost'] ?? map['totalCost'] ?? map['total'] ?? map['totalPrice'] ?? 0).toDouble(),
      itemsPrice: (map['itemsPrice'] ?? map['items_price'])?.toDouble(),
      deliveryPrice: (map['deliveryPrice'] ?? map['delivery_price'])?.toDouble(),
      distanceKm: (map['distance_km'] ?? map['distanceKm'])?.toDouble(),
      durationMin: (map['duration_min'] ?? map['durationMin'])?.toInt(),
      status: map['status'] ?? 'new',
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