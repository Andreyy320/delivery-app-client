import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';
import '../screens/Menu/Cart_data.dart';

class OrdersService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> addOrder(String userId, List<CartItem> cart) async {
    final orderData = {
      'userId': userId,
      'items': cart
          .map((item) => {
        'name': item.dish.name,
        'price': item.dish.price,
        'quantity': item.quantity,
      })
          .toList(),
      'total': cart.fold<double>(0, (sum, item) => sum + item.dish.price * item.quantity),
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('orders').add(orderData);
  }

  static Stream<QuerySnapshot> getOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }
}
