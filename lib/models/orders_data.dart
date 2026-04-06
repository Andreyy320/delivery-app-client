import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/Menu/Cart_data.dart';
import '../models/dish_model.dart';
import '../screens/register_and_vhod/notification_service.dart';

class OrdersService {
  static final _firestore = FirebaseFirestore.instance;


  // Метод для отслеживания статусов и отправки уведомлений
  static void setupNotifications(String userId) {
    _firestore
        .collection('orders') // Проверь, чтобы в addOrder тоже был этот путь
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {

      for (var change in snapshot.docChanges) {
        // Нас интересует момент, когда статус ИЗМЕНИЛСЯ (modified)
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';

          // Твоя логика: выбираем текст в зависимости от статуса
          String title = "Обновление заказа";
          String message = "";

          if (status == 'accepted') {
            message = "Ваш заказ принят! Начинаем готовить 👨‍🍳";
          } else if (status == 'cancelled') {
            title = "Заказ отменен";
            message = "К сожалению, ресторан отменил заказ 😔";
          } else if (status == 'delivery') {
            message = "Заказ в пути! Курьер уже мчится к вам 🏎️";
          } else if (status == 'completed') {
            message = "Доставлено! Приятного аппетита 🍕";
          }

          // Если сообщение не пустое — кидаем пуш
          if (message.isNotEmpty) {
            NotificationService.showNotification(title, message);
          }
        }
      }
    });
  }


  // Добавление заказа
  static Future<void> addOrder(
      String userId,
      List<CartItem> cart, {
        required String restaurantName,
        required String shopId,
        String comment = '',
        String paymentMethod = 'cash',
      }) async {
    // Берем имя и телефон клиента для курьера
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final clientName = userDoc.data()?['name'] ?? 'Без имени';
    final clientPhone = userDoc.data()?['phone'] ?? '';

    final orderData = {
      'userId': userId,
      'shopId': shopId,
      'restaurantName': restaurantName,
      'items': cart
          .map((item) => {
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
        'description': item.dish.description,
        'category': item.dish.category,
        'imagePath': item.dish.imagePath,
      })
          .toList(),
      'total': cart.fold<double>(
          0, (sum, item) => sum + item.dish.price * item.quantity),
      'paymentMethod': paymentMethod,
      'comment': comment,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'clientName': clientName,     // 🔹 для курьера
      'clientPhone': clientPhone,   // 🔹 для курьера
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .add(orderData);
  }




// Получение потока заказов пользователя
  static Stream<QuerySnapshot> getOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
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
