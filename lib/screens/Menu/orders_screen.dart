import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/order_model.dart';
import '../../screens/Menu/Cart_data.dart';
import '../../screens/Menu/cart_screen.dart';
import '../Dostavka/DeliveryOrder.dart';
import '../Dostavka/courier_express_screen.dart';
import '../Dostavka/gorod_model.dart';
import '../Dostavka/mejgorod_model.dart';

class OrdersScreen extends StatefulWidget {
  final String userId;
  const OrdersScreen({super.key, required this.userId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Stream<List<Order>> ordersStream;
  late Stream<List<DeliveryOrder>> deliveryStream;
  late Stream<List<CityDeliveryOrder>> cityDeliveryStream;
  late Stream<List<MejCityDeliveryOrder>> mejcityDeliveryStream;

  List<Order> localOrderHistory = [];
  List<DeliveryOrder> localDeliveryHistory = [];
  List<CityDeliveryOrder> localCityDeliveryHistory = [];
  List<MejCityDeliveryOrder> localMejCityDeliveryHistory = [];

  @override
  void initState() {
    super.initState();
    _initOrdersStream();
  }

  void _initOrdersStream() {
    ordersStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Order.fromFirestore(doc.id, doc.data())).toList());

    deliveryStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('delivery_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => DeliveryOrder.fromFirestore(doc.id, doc.data())).toList());

    cityDeliveryStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cityOrders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CityDeliveryOrder.fromFirestore(doc.id, doc.data()))
        .toList());

    mejcityDeliveryStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('mejCityOrders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MejCityDeliveryOrder.fromFirestore(doc.id, doc.data()))
        .toList());
  }

  // --- МЕТОДЫ УДАЛЕНИЯ ---
  Future<void> _deleteOrder(String collectionPath, String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection(collectionPath)
          .doc(orderId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ удален')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _repeatOrder(Order order) {
    if (order.shopId == null || order.shopId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невозможно повторить заказ: отсутствует shopId')),
      );
      return;
    }

    for (var item in order.items) {
      addToCartItem(widget.userId, order.shopId!, item.dish);
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CartScreen(shopId: order.shopId!)),
    );
  }

  void addToLocalOrder(Order order) {
    setState(() {
      localOrderHistory.insert(0, order);
      if (localOrderHistory.length > 20) localOrderHistory.removeLast();
    });
  }

  void addToLocalDelivery(DeliveryOrder order) {
    setState(() {
      localDeliveryHistory.insert(0, order);
      if (localDeliveryHistory.length > 20) localDeliveryHistory.removeLast();
    });
  }

  void addToLocalCityDelivery(CityDeliveryOrder order) {
    setState(() {
      localCityDeliveryHistory.insert(0, order);
      if (localCityDeliveryHistory.length > 20) localCityDeliveryHistory.removeLast();
    });
  }

  void addToLocalMejCityDelivery(MejCityDeliveryOrder order) {
    setState(() {
      localMejCityDeliveryHistory.insert(0, order);
      if (localMejCityDeliveryHistory.length > 20) localMejCityDeliveryHistory.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История заказов'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<List<Order>>(
        stream: ordersStream,
        builder: (context, orderSnapshot) {
          final firestoreOrders = orderSnapshot.data ?? [];
          return StreamBuilder<List<DeliveryOrder>>(
            stream: deliveryStream,
            builder: (context, deliverySnapshot) {
              final firestoreDelivery = deliverySnapshot.data ?? [];
              return StreamBuilder<List<CityDeliveryOrder>>(
                stream: cityDeliveryStream,
                builder: (context, citySnapshot) {
                  final firestoreCityDelivery = citySnapshot.data ?? [];
                  return StreamBuilder<List<MejCityDeliveryOrder>>(
                    stream: mejcityDeliveryStream,
                    builder: (context, mejSnapshot) {
                      final firestoreMejCityDelivery = mejSnapshot.data ?? [];

                      final allOrders = [...localOrderHistory, ...firestoreOrders];
                      final allDelivery = [...localDeliveryHistory, ...firestoreDelivery];
                      final allCityDelivery = [...localCityDeliveryHistory, ...firestoreCityDelivery];
                      final allMejCityDelivery = [...localMejCityDeliveryHistory, ...firestoreMejCityDelivery];

                      final combinedList = [
                        ...allOrders.map((o) => {'type': 'food', 'order': o}),
                        ...allDelivery.map((d) => {'type': 'delivery', 'order': d}),
                        ...allCityDelivery.map((c) => {'type': 'city', 'order': c}),
                        ...allMejCityDelivery.map((m) => {'type': 'mejCity', 'order': m}),
                      ];

                      combinedList.sort((a, b) {
                        DateTime aDate = a['type'] == 'food'
                            ? (a['order'] as Order).dateTime
                            : a['type'] == 'delivery'
                            ? (a['order'] as DeliveryOrder).createdAt
                            : a['type'] == 'city'
                            ? (a['order'] as CityDeliveryOrder).createdAt
                            : (a['order'] as MejCityDeliveryOrder).createdAt;

                        DateTime bDate = b['type'] == 'food'
                            ? (b['order'] as Order).dateTime
                            : b['type'] == 'delivery'
                            ? (b['order'] as DeliveryOrder).createdAt
                            : b['type'] == 'city'
                            ? (b['order'] as CityDeliveryOrder).createdAt
                            : (b['order'] as MejCityDeliveryOrder).createdAt;

                        return bDate.compareTo(aDate);
                      });

                      if (combinedList.isEmpty) {
                        return const Center(
                          child: Text('Вы ещё не делали заказов', style: TextStyle(fontSize: 16)),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: combinedList.length,
                        itemBuilder: (context, index) {
                          final item = combinedList[index];
                          switch (item['type']) {
                            case 'food':
                              return _buildFoodOrderCard(item['order'] as Order);
                            case 'delivery':
                              return _buildDeliveryOrderCard(item['order'] as DeliveryOrder);
                            case 'city':
                              return _buildCityDeliveryCard(item['order'] as CityDeliveryOrder);
                            case 'mejCity':
                              return _buildMejCityDeliveryCard(item['order'] as MejCityDeliveryOrder);
                            default:
                              return const SizedBox.shrink();
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // =================== ВИДЖЕТЫ ДЛЯ КАРТОЧЕК С КНОПКОЙ УДАЛЕНИЯ ===================

  Widget _buildFoodOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.deepOrange.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Заказ еды от ${order.dateTime.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteOrder('orders', order.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(item.dish.imagePath, width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.dish.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${item.dish.price} ₽ × ${item.quantity}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text('${item.dish.price * item.quantity} ₽',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого: ${order.total.toStringAsFixed(0)} ₽',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () => _repeatOrder(order),
                  icon: const Icon(Icons.restart_alt, color: Colors.white),
                  label: const Text('Повторить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOrderCard(DeliveryOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.blueGrey.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Срочная доставка от ${order.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteOrder('delivery_orders', order.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Откуда: ${order.pickup.latitude.toStringAsFixed(5)}, ${order.pickup.longitude.toStringAsFixed(5)}'),
            Text('Куда: ${order.dropoff.latitude.toStringAsFixed(5)}, ${order.dropoff.longitude.toStringAsFixed(5)}'),
            Text('Опции: ${order.options.join(', ')}'),
            Text('Итого: ${order.totalCost.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Статус: ${order.status}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCityDeliveryCard(CityDeliveryOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.green.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Городская доставка от ${order.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteOrder('cityOrders', order.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Откуда: ${order.fromAddress}'),
            Text('Куда: ${order.toAddress}'),
            Text('Кузов: ${order.bodyType}'),
            Text('Грузчики: ${order.loaders}'),
            Text('Сопровождающий: ${order.escort}'),
            if (order.scheduledTime != null)
              Text('Время: ${order.scheduledTime!.toLocal().toString().split('.')[0]}'),
            Text('Итого: ${order.totalPrice} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Статус: ${order.status}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMejCityDeliveryCard(MejCityDeliveryOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.green.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Межгородская доставка от ${order.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteOrder('mejCityOrders', order.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Откуда: ${order.fromAddress}'),
            Text('Куда: ${order.toAddress}'),
            Text('Кузов: ${order.bodyType}'),
            Text('Грузчики: ${order.loaders}'),
            Text('Сопровождающий: ${order.escort}'),
            if (order.scheduledTime != null)
              Text('Время: ${order.scheduledTime!.toLocal().toString().split('.')[0]}'),
            Text('Итого: ${order.totalPrice} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Статус: ${order.status}'),
          ],
        ),
      ),
    );
  }
}
