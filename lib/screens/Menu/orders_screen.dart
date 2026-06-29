import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/order_model.dart';
import '../../screens/Menu/Cart_data.dart';
import '../../screens/Menu/cart_screen.dart';
import '../Dostavka/DeliveryOrder.dart';
import '../Dostavka/courier_express_screen.dart';
import '../Dostavka/gorod_model.dart';
import '../Dostavka/mejgorod_model.dart';
import 'package:intl/intl.dart';

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

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'new': return 'Новый';
      case 'preparing': return 'Готовится';
      case 'accepted': return 'Принят';
      case 'in_progress':
      case 'inprogress': return 'В пути';
      case 'ready': return 'Готов';
      case 'delivered':
      case 'completed': return 'Доставлен';
      case 'cancelled': return 'Отменен';
      default: return status;
    }
  }

  // Перевод доп. опций для красоты
  String _translateOption(String option) {
    switch (option) {
      case 'receiver_pay': return 'Оплата получателем';
      case 'fragile': return 'Хрупкое';
      case 'large': return 'Габаритный груз';
      case 'escort': return 'Сопровождение';
      default: return option;
    }
  }

  void _initOrdersStream() {
    ordersStream = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('orders')
        .orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Order.fromFirestore(doc.id, doc.data())).toList());

    deliveryStream = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('delivery_orders')
        .orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DeliveryOrder.fromFirestore(doc.id, doc.data())).toList());

    cityDeliveryStream = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('cityOrders')
        .orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CityDeliveryOrder.fromFirestore(doc.id, doc.data())).toList());

    mejcityDeliveryStream = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('mejCityOrders')
        .orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MejCityDeliveryOrder.fromFirestore(doc.id, doc.data())).toList());
  }

  Future<void> _deleteOrder(String collectionPath, String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId).collection(collectionPath).doc(orderId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ удален'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void _repeatOrder(Order order) {
    if (order.shopId == null || order.shopId!.isEmpty) return;
    for (var item in order.items) {
      addToCartItem(widget.userId, order.shopId!, item.dish);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CartScreen(shopId: order.shopId!, restaurantName: order.restaurantName ?? "Ресторан")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text('Мои заказы', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
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

                      final combinedList = [
                        ...localOrderHistory.map((o) => {'type': 'food', 'order': o}),
                        ...firestoreOrders.map((o) => {'type': 'food', 'order': o}),
                        ...localDeliveryHistory.map((d) => {'type': 'delivery', 'order': d}),
                        ...firestoreDelivery.map((d) => {'type': 'delivery', 'order': d}),
                        ...localCityDeliveryHistory.map((c) => {'type': 'city', 'order': c}),
                        ...firestoreCityDelivery.map((c) => {'type': 'city', 'order': c}),
                        ...localMejCityDeliveryHistory.map((m) => {'type': 'mejCity', 'order': m}),
                        ...firestoreMejCityDelivery.map((m) => {'type': 'mejCity', 'order': m}),
                      ];

                      combinedList.sort((a, b) => _getDateTime(b).compareTo(_getDateTime(a)));

                      if (combinedList.isEmpty) {
                        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 16), const Text('История пуста', style: TextStyle(color: Colors.grey, fontSize: 18))]));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: combinedList.length,
                        itemBuilder: (context, index) {
                          final item = combinedList[index];
                          final type = item['type'] as String;
                          final orderData = item['order'];

                          if (type == 'food') return _buildFoodCard(orderData as Order);
                          if (type == 'delivery') return _buildExpressCard(orderData as DeliveryOrder);
                          if (type == 'city') return _buildCargoCard('Город', orderData as CityDeliveryOrder, Colors.green, 'cityOrders');
                          return _buildCargoCard('Межгород', orderData as MejCityDeliveryOrder, Colors.blue, 'mejCityOrders');
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

  DateTime _getDateTime(Map<String, dynamic> item) {
    final type = item['type'];
    final o = item['order'];
    if (type == 'food') return (o as Order).dateTime;
    if (type == 'delivery') return (o as DeliveryOrder).createdAt;
    if (type == 'city') return (o as CityDeliveryOrder).createdAt;
    return (o as MejCityDeliveryOrder).createdAt;
  }

  Widget _buildExpressCard(DeliveryOrder order) {
    String fromCoord = "${order.pickup.latitude.toStringAsFixed(6)}, ${order.pickup.longitude.toStringAsFixed(6)}";
    String toCoord = "${order.dropoff.latitude.toStringAsFixed(6)}, ${order.dropoff.longitude.toStringAsFixed(6)}";

    return _baseCard(
      color: Colors.deepPurple,
      title: 'Экспресс курьер',
      dateTime: order.createdAt,
      path: 'delivery_orders',
      id: order.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeRow(Icons.circle, Colors.deepPurple, "Откуда: $fromCoord"),
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: SizedBox(height: 10, child: VerticalDivider(width: 1, thickness: 1, color: Colors.black12)),
          ),
          _routeRow(Icons.location_on, Colors.redAccent, "Куда: $toCoord"),

          const SizedBox(height: 12),

          if (order.options.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: order.options.map((opt) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black.withOpacity(0.05))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 10, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(_translateOption(opt), style: const TextStyle(fontSize: 10, color: Colors.black87)),
                  ],
                ),
              )).toList(),
            ),

          const Divider(height: 24),
          _footerRow(order.totalCost.toInt().toString(), order.status, Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildFoodCard(Order order) {
    return _baseCard(
      color: Colors.deepOrange,
      title: order.restaurantName ?? 'Доставка еды',
      dateTime: order.dateTime,
      path: 'orders',
      id: order.id,
      child: Column(
        children: [
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: item.dish.imagePath.startsWith('http') ? Image.network(item.dish.imagePath, width: 40, height: 40, fit: BoxFit.cover) : Image.asset(item.dish.imagePath, width: 40, height: 40, fit: BoxFit.cover)),
                const SizedBox(width: 12),
                Expanded(child: Text(item.dish.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('${item.quantity} x', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.total.toInt()} Руб', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              TextButton(onPressed: () => _repeatOrder(order), style: TextButton.styleFrom(backgroundColor: Colors.deepOrange.withOpacity(0.1), foregroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Повторить')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCargoCard(String title, dynamic order, Color color, String path) {
    return _baseCard(
      color: color,
      title: 'Грузовое: $title',
      dateTime: order.createdAt,
      path: path,
      id: order.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeRow(Icons.circle, color, order.fromAddress),
          _routeRow(Icons.location_on, Colors.redAccent, order.toAddress),
          const SizedBox(height: 6),
          Text('Тип: ${order.bodyType} • Грузчики: ${order.loaders}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
          const Divider(height: 20),
          _footerRow(order.totalPrice.toString(), order.status, color),
        ],
      ),
    );
  }

  Widget _baseCard({required Color color, required String title, required DateTime dateTime, required String path, required String id, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Чтобы крестик выравнивался аккуратно по верхней линии
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.local_shipping_rounded, color: color, size: 16)
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                                DateFormat('dd.MM.yyyy  •  HH:mm').format(dateTime.toLocal()),
                                style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteOrder(path, id),
                  icon: const Icon(Icons.close, size: 16, color: Colors.black26),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: child),
        ],
      ),
    );
  }

  Widget _routeRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _footerRow(String price, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$price Руб', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(_translateStatus(status).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ],
    );
  }
}