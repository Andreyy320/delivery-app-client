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

          if (status == 'preparing') {
            message = "Ваш заказ принят! Начинаем готовить 👨‍🍳";
          } else if (status == 'accepted') {
            message = "Заказ в пути! Курьер уже мчится к вам 🏎️";
          } else if (status == 'completed') {
            message = "Доставлено! Приятного аппетита 🍕";
          } else if (status == 'delivered') { // Исправлено: обычно 'delivered' это доставлено, но оставляю твою логику отмены если так в базе
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

  // Добавление заказа
  static Future<void> addOrder(
      String userId,
      List<CartItem> cart, {
        required String restaurantName,
        required String shopId,
        required String category,
        String comment = '', // Это комментарий курьеру
        String restaurantComment = '', // Комментарий для заведения
        String paymentMethod = 'cash',
        double? lat,
        double? lng,
        // 🔹 НОВОЕ: Принимаем три цены для прозрачности
        double itemsPrice = 0.0,    // Сумма товаров (для заведения)
        double deliveryPrice = 0.0, // Сумма доставки (для курьера)
        double totalPrice = 0.0,    // Общая сумма (для клиента)
      }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final clientName = userDoc.data()?['name'] ?? 'Без имени';
    final clientPhone = userDoc.data()?['phone'] ?? '';

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

      // 🔹 ТРИ ЦЕНЫ: Теперь в базе будет полный порядок
      'itemsPrice': itemsPrice,       // Чистая выручка заведения
      'deliveryPrice': deliveryPrice, // Чистая выручка курьера
      'total': totalPrice,            // Сколько всего заплатил клиент

      'paymentMethod': paymentMethod,
      'comment': comment,
      'restaurantComment': restaurantComment,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientLat': lat,
      'clientLng': lng,
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