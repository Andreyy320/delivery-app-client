import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class DeliveryOrder {
  final String id;
  final LatLng pickup;
  final LatLng dropoff;
  final List<String> options;
  final double totalCost;
  final String status;
  final DateTime createdAt;
  final String type;

  // Поля для прогресс-бара (которые пишет курьер)
  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? deliveredAt;

  // Остальное
  final String? bodyType;
  final int? loaders;
  final int? escort;
  final DateTime? scheduledTime;

  DeliveryOrder({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.options,
    required this.totalCost,
    required this.status,
    required this.createdAt,
    this.type = 'delivery',
    this.acceptedAt,    // ⬅️ Добавлено
    this.inProgressAt,  // ⬅️ Добавлено
    this.deliveredAt,   // ⬅️ Добавлено
    this.bodyType,
    this.loaders,
    this.escort,
    this.scheduledTime,
  });

  factory DeliveryOrder.fromFirestore(String id, Map<String, dynamic> map) {
    final pickupMap = map['pickup'] ?? {};
    final dropoffMap = map['dropoff'] ?? {};

    return DeliveryOrder(
      id: id,
      pickup: LatLng(
        (pickupMap['lat'] ?? 0).toDouble(),
        (pickupMap['lng'] ?? 0).toDouble(),
      ),
      dropoff: LatLng(
        (dropoffMap['lat'] ?? 0).toDouble(),
        (dropoffMap['lng'] ?? 0).toDouble(),
      ),
      options: List<String>.from(map['options'] ?? []),
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      status: map['status'] ?? 'new',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] ?? 'delivery',

      // 🔽 Считываем метки времени из Firestore
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      inProgressAt: (map['inProgressAt'] as Timestamp?)?.toDate(),
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),

      bodyType: map['bodyType'],
      loaders: map['loaders'],
      escort: map['escort'],
      scheduledTime: (map['scheduledTime'] as Timestamp?)?.toDate(),
    );
  }
}