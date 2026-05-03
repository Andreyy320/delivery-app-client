import 'package:cloud_firestore/cloud_firestore.dart';
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

          if (status == 'accepted') {
            message = "Ваш заказ принят! Начинаем готовить 👨‍🍳";
          } else if (status == 'delivery') {
            message = "Заказ в пути! Курьер уже мчится к вам 🏎️";
          } else if (status == 'completed') {
            message = "Доставлено! Приятного аппетита 🍕";
          } else if (status == 'cancelled') {
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

  // Добавление заказа — ДОБАВИЛ category
  static Future<void> addOrder(
      String userId,
      List<CartItem> cart, {
        required String restaurantName,
        required String shopId,
        required String category, // 🔹 НОВОЕ: Передаем категорию магазина (restaurant, product и т.д.)
        String comment = '',
        String paymentMethod = 'cash',
        double? lat,
        double? lng,
      }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final clientName = userDoc.data()?['name'] ?? 'Без имени';
    final clientPhone = userDoc.data()?['phone'] ?? '';

    final orderData = {
      'userId': userId,
      'shopId': shopId,
      'restaurantName': restaurantName,
      'category': category, // 🔹 СОХРАНЯЕМ КАТЕГОРИЮ В БД
      'items': cart.map((item) => {
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
        'description': item.dish.description,
        'category': item.dish.category,
        'imagePath': item.dish.imagePath,
      }).toList(),
      'total': cart.fold<double>(0, (sum, item) => sum + item.dish.price * item.quantity),
      'paymentMethod': paymentMethod,
      'comment': comment,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientLat': lat,
      'clientLng': lng,
    };

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