import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';
import '../screens/Menu/Cart_data.dart';

class OrdersService {
  static final _firestore = FirebaseFirestore.instance;

  // 1. Добавляем параметры, которые передает CheckoutScreen (shopId, restaurantName и т.д.)
  static Future<void> addOrder(
      String userId,
      List<CartItem> cart, {
        required String restaurantName,
        required String shopId,
        String comment = '',
        String paymentMethod = 'cash',
      }) async {
    final orderData = {
      'userId': userId,
      'shopId': shopId, // 🔹 Добавлено
      'restaurantName': restaurantName, // 🔹 Добавлено
      'items': cart.map((item) => {
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
        'description': item.dish.description, // 🔹 Нужно для модели Order
        'category': item.dish.category,       // 🔹 Нужно для модели Order
        'imagePath': item.dish.imagePath,     // 🔹 Чтобы видеть картинки в истории
      }).toList(),
      'total': cart.fold<double>(0, (sum, item) => sum + item.dish.price * item.quantity),
      'status': 'new', // 🔹 В CheckoutScreen мы используем 'new' или 'preparing'
      'paymentMethod': paymentMethod, // 🔹 Добавлено
      'comment': comment,             // 🔹 Добавлено
      'createdAt': FieldValue.serverTimestamp(), // 🔹 В модели мы назвали это createdAt (без нижнего подчеркивания)
    };

    // Сохраняем в общую коллекцию (как ты и хотел изначально)
    await _firestore.collection('orders').add(orderData);
  }

  static Stream<QuerySnapshot> getOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true) // 🔹 Исправлено на createdAt
        .snapshots();
  }
}