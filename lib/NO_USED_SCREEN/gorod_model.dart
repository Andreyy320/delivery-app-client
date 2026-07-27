import 'package:cloud_firestore/cloud_firestore.dart';

class CityDeliveryOrder {
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

  // 🔹 Поля для прогресс-бара (которые записывает курьер)
  final DateTime? acceptedAt;    // ⬅️ Добавлено
  final DateTime? inProgressAt;  // ⬅️ Добавлено
  final DateTime? deliveredAt;   // ⬅️ Добавлено

  CityDeliveryOrder({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    required this.bodyType,
    required this.loaders,
    required this.escort,
    required this.timeSelected,
    this.scheduledTime,
    required this.totalPrice,
    this.status = 'new', // По умолчанию 'new' для корректной работы логики
    required this.createdAt,
    // 🔽 Инициализация новых полей
    this.acceptedAt,
    this.inProgressAt,
    this.deliveredAt,
  });

  /// Конструктор для создания из Firestore
  factory CityDeliveryOrder.fromFirestore(String id, Map<String, dynamic> data) {
    return CityDeliveryOrder(
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

      // 🔽 Считываем метки времени из Firestore (для шкалы прогресса)
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
      // Сохраняем и эти поля, если они заполнены
      'acceptedAt': acceptedAt,
      'inProgressAt': inProgressAt,
      'deliveredAt': deliveredAt,
    };
  }
}