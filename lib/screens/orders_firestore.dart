import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';
import '../screens/Menu/Cart_data.dart';

class OrdersService {
  static final _firestore = FirebaseFirestore.instance;

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
      'shopId': shopId,
      'restaurantName': restaurantName,
      'items': cart.map((item) => {
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
        'description': item.dish.description,
        'category': item.dish.category,
        'imagePath': item.dish.imagePath,
      }).toList(),
      'total': cart.fold<double>(0, (sum, item) => sum + item.dish.price * item.quantity),
      'status': 'new',
      'paymentMethod': paymentMethod,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };

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