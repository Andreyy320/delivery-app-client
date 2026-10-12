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

  /// Фабрика для создания объекта из данных PostgreSQL (Map<String, dynamic>)
  factory DeliveryOrder.fromJson(Map<String, dynamic> map) {
    // Координаты могут приходить как отдельными полями, так и вложенными объектами
    final pickupMap = map['pickup'] as Map<String, dynamic>? ?? {};
    final dropoffMap = map['dropoff'] as Map<String, dynamic>? ?? {};

    return DeliveryOrder(
      id: map['id']?.toString() ?? '',
      pickup: LatLng(
        (pickupMap['lat'] ?? map['pickup_lat'] ?? map['shopLat'] ?? 0).toDouble(),
        (pickupMap['lon'] ?? pickupMap['lng'] ?? map['pickup_lon'] ?? map['shopLng'] ?? 0).toDouble(),
      ),
      dropoff: LatLng(
        (dropoffMap['lat'] ?? dropoffMap['latitude'] ?? map['dropoff_lat'] ?? map['clientLat'] ?? 0).toDouble(),
        (dropoffMap['lon'] ?? dropoffMap['lng'] ?? map['dropoff_lon'] ?? map['clientLng'] ?? 0).toDouble(),
      ),

      // Маппинг полей под PostgreSQL колонки со скриншота
      pickupAddress: map['pickup_address'] ?? map['pickupAddress'] ?? pickupMap['address'],
      dropoffAddress: map['dropoff_address'] ?? map['dropoffAddress'] ?? dropoffMap['address'],

      subType: map['sub_type'] ?? map['subType'],
      description: map['description'] ?? map['comment'],
      clientName: map['client_name'] ?? map['clientName'] ?? map['name'],
      clientPhone: map['client_phone'] ?? map['clientPhone'] ?? map['phone'],
      clientId: map['client_id']?.toString() ?? map['clientId']?.toString() ?? map['user_id']?.toString(),

      recipientName: map['recipient_name'] ?? map['recipientName'] ?? map['receiverName'],
      recipientPhone: map['recipient_phone'] ?? map['recipientPhone'] ?? map['receiverPhone'],
      comment: map['comment'],

      options: List<String>.from(map['options'] ?? []),

      totalCost: double.tryParse(map['total_cost']?.toString() ?? map['totalCost']?.toString() ?? '0') ?? 0.0,
      itemsPrice: double.tryParse(map['items_price']?.toString() ?? map['itemsPrice']?.toString() ?? ''),
      deliveryPrice: double.tryParse(map['delivery_price']?.toString() ?? map['deliveryPrice']?.toString() ?? ''),

      distanceKm: double.tryParse(map['distance_km']?.toString() ?? map['distanceKm']?.toString() ?? ''),
      durationMin: int.tryParse(map['duration_min']?.toString() ?? map['durationMin']?.toString() ?? ''),

      status: map['status'] ?? 'new',

      // Парсинг дат из PostgreSQL (обычно приходят как ISO-строки через JSON)
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : (map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now()),

      type: map['type'] ?? 'delivery',

      acceptedAt: map['accepted_at'] != null ? DateTime.parse(map['accepted_at'].toString()) : null,
      inProgressAt: map['in_progress_at'] != null ? DateTime.parse(map['in_progress_at'].toString()) : null,
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at'].toString()) : null,

      bodyType: map['body_type'] ?? map['bodyType'],
      loaders: map['loaders'],
      escort: map['escort'],

      scheduledTime: map['scheduled_time'] != null ? DateTime.parse(map['scheduled_time'].toString()) : null,
      restaurantName: map['restaurant_name'] ?? map['restaurantName'] ?? map['shopName'],
      shopId: map['shop_id']?.toString() ?? map['shopId']?.toString(),
      courierId: map['courier_id']?.toString() ?? map['courierId']?.toString(),
    );
  }
}