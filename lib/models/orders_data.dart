import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../screens/Menu/Cart_data.dart';
import '../models/dish_model.dart';
import '../screens/register_and_vhod/notification_service.dart';

class OrdersService {
  static final _firestore = FirebaseFirestore.instance;

  // Отслеживание статусов
  static void setupNotifications(String userId) {
    _firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';

          String title = "Обновление заказа";
          String message = "";

          if (status == 'preparing') {
            message = "Ваш заказ принят! Начинаем готовить 👨‍🍳";
          } else if (status == 'accepted') {
            message = "Заказ в пути! Курьер уже мчится к вам 🏎️";
          } else if (status == 'completed') {
            message = "Доставлено! Приятного аппетита 🍕";
          } else if (status == 'delivered') {
            title = "Заказ отменен";
            message = "К сожалению, ресторан отменил заказ 😔";
          }

          if (message.isNotEmpty) {
            NotificationService.showNotification(title, message);
          }
        }
      }
    });
  }



  static double calculateTaxiPrice({required double distanceKm, required int durationMin}) {
    const double baseFee = 15.0;
    const double ratePerKm = 5.85;
    const double idleRatePerHour = 60.0;

    double distanceCost = baseFee + (distanceKm * ratePerKm);
    double timeCost = (durationMin / 60.0) * idleRatePerHour;
    double rawPrice = distanceCost + timeCost;

    debugPrint('--- РАСЧЕТ ЦЕНЫ ---');
    debugPrint('Дистанция: $distanceKm км -> Стоимость км: $distanceCost');
    debugPrint('Время: $durationMin мин -> Стоимость времени: $timeCost');
    debugPrint('Итого «сырая» цена: $rawPrice');
    debugPrint('Итого с округлением: ${rawPrice.round()}');

    return rawPrice;
  }


  // Добавление заказа
  static Future<void> addOrder(
      String userId,
      List<CartItem> cart, {
        required String restaurantName,
        required String shopId,
        required String category,
        String comment = '', // Комментарий курьеру
        String restaurantComment = '', // Комментарий для заведения
        String paymentMethod = 'cash',
        double? lat,
        double? lng,
        String? address, // Название улицы/адреса доставки
        double itemsPrice = 0.0,    // Сумма товаров (для заведения)
        double deliveryPrice = 0.0, // Сумма доставки (для курьера)
        double totalPrice = 0.0,    // Общая сумма (для клиента)
        double distanceKm = 0.0,    // 🔹 НОВОЕ: Расстояние в км
        int durationMin = 0,        // 🔹 НОВОЕ: Время в пути в минутах
      }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final clientName = userDoc.data()?['name'] ?? 'Без имени';
    final clientPhone = userDoc.data()?['phone'] ?? '';

    // Если итоговая цена не передана при вызове, считаем её автоматически по формуле таксометра!
    final double finalDeliveryPrice = deliveryPrice > 0
        ? deliveryPrice
        : calculateTaxiPrice(distanceKm: distanceKm, durationMin: durationMin);

    final double finalTotal = totalPrice > 0
        ? totalPrice
        : (itemsPrice + finalDeliveryPrice);

    final orderData = {
      'userId': userId,
      'shopId': shopId,
      'restaurantName': restaurantName,
      'category': category,
      'items': cart.map((item) => {
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
        'description': item.dish.description,
        'category': item.dish.category,
        'imagePath': item.dish.imagePath,
      }).toList(),

      'itemsPrice': itemsPrice,
      'deliveryPrice': finalDeliveryPrice, // 🔹 Записываем рассчитанную по формуле цену
      'total': finalTotal,                 // 🔹 Общая сумма с учетом товаров и доставки
      'distance_km': distanceKm,           // 🔹 Сохраняем километраж для карточки курьера
      'duration_min': durationMin,         // 🔹 Сохраняем время в пути

      'paymentMethod': paymentMethod,
      'comment': comment,
      'restaurantComment': restaurantComment,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientLat': lat,
      'clientLng': lng,
      'clientAddress': address ?? 'Точка доставки',

      // Дублируем структуру location, чтобы модель Order.fromFirestore читала её без ошибок
      'deliveryLocation': {
        'lat': lat ?? 0.0,
        'lng': lng ?? 0.0,
      },
    };

    // Сохраняем в коллекцию заказов пользователя
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .add(orderData);
  }

  // Получение заказов
  static Stream<QuerySnapshot> getOrders(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Удаление заказа
  static Future<void> deleteOrder(String userId, String docId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .doc(docId)
        .delete();
  }
}