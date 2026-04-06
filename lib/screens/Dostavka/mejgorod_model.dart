import 'package:cloud_firestore/cloud_firestore.dart';

class MejCityDeliveryOrder {
  final String id;
  final String fromAddress;
  final String toAddress;
  final String bodyType;
  final int loaders;
  final int escort;
  final bool timeSelected;
  final DateTime? scheduledTime;
  final int totalPrice;
  final String status;
  final DateTime createdAt;

  // 🔹 Метки времени для шкалы прогресса (как в других моделях)
  final DateTime? acceptedAt;    // Принято водителем
  final DateTime? inProgressAt;  // В пути между городами
  final DateTime? deliveredAt;   // Груз доставлен

  MejCityDeliveryOrder({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    required this.bodyType,
    required this.loaders,
    required this.escort,
    required this.timeSelected,
    this.scheduledTime,
    required this.totalPrice,
    this.status = 'new', // Унифицировали статус под общую логику
    required this.createdAt,
    // Инициализация новых полей
    this.acceptedAt,
    this.inProgressAt,
    this.deliveredAt,
  });

  /// Конструктор для создания из Firestore
  factory MejCityDeliveryOrder.fromFirestore(String id, Map<String, dynamic> data) {
    return MejCityDeliveryOrder(
      id: id,
      fromAddress: data['fromAddress'] ?? '',
      toAddress: data['toAddress'] ?? '',
      bodyType: data['bodyType'] ?? 'L',
      loaders: data['loaders'] ?? 0,
      escort: data['escort'] ?? 0,
      timeSelected: data['timeSelected'] ?? false,
      scheduledTime: data['scheduledTime'] != null
          ? (data['scheduledTime'] as Timestamp).toDate()
          : null,
      totalPrice: data['totalPrice'] ?? 0,
      status: data['status'] ?? 'new',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),

      // 🔽 Считываем метки прогресса из Firebase
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      inProgressAt: (data['inProgressAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Метод для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'bodyType': bodyType,
      'loaders': loaders,
      'escort': escort,
      'timeSelected': timeSelected,
      'scheduledTime': scheduledTime,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt,
      // Сохраняем метки, если они есть
      'acceptedAt': acceptedAt,
      'inProgressAt': inProgressAt,
      'deliveredAt': deliveredAt,
    };
  }
}