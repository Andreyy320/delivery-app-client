import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/order_model.dart';
import '../Dostavka/DeliveryOrder.dart';
import '../Dostavka/gorod_model.dart';
import '../Dostavka/mejgorod_model.dart';
import 'package:intl/intl.dart';

class OrdersStatusScreen extends StatefulWidget {
  const OrdersStatusScreen({super.key});

  @override
  State<OrdersStatusScreen> createState() => _OrdersStatusScreenState();
}

class _OrdersStatusScreenState extends State<OrdersStatusScreen> {
  late final User? user;

  Stream<List<Order>>? ordersStream;
  Stream<List<DeliveryOrder>>? deliveryStream;
  Stream<List<CityDeliveryOrder>>? cityDeliveryStream;
  Stream<List<MejCityDeliveryOrder>>? mejCityDeliveryStream;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      ordersStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Order.fromFirestore(doc.id, doc.data())).toList());

      deliveryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('delivery_orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => DeliveryOrder.fromFirestore(doc.id, doc.data())).toList());

      cityDeliveryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cityOrders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => CityDeliveryOrder.fromFirestore(doc.id, doc.data())).toList());

      mejCityDeliveryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('mejCityOrders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => MejCityDeliveryOrder.fromFirestore(doc.id, doc.data())).toList());
    }
  }

  // --- ФУНКЦИЯ ПЕРЕВОДА СТАТУСОВ ---
  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'Новый';
      case 'accepted':
        return 'Принят';
      case 'preparing':
        return 'Готовится';
      case 'ready':
        return 'Готов';
      case 'in_progress':
      case 'inprogress':
      case 'delivering':
        return 'В пути';
      case 'delivered':
      case 'completed':
        return 'Доставлен';
      case 'cancelled':
        return 'Отменен';
      default:
        return status;
    }
  }

  Widget _buildProgressBar(List<bool> steps, List<IconData> icons, List<String> labels, Color activeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isEven) {
            final stepIdx = index ~/ 2;
            final isActive = steps[stepIdx];
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : Colors.grey[200],
                    shape: BoxShape.circle,
                    boxShadow: isActive ? [BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Icon(icons[stepIdx], color: isActive ? Colors.white : Colors.grey[400], size: 14),
                ),
                const SizedBox(height: 6),
                Text(labels[stepIdx], style: TextStyle(fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.black87 : Colors.grey)),
              ],
            );
          } else {
            final lineIdx = index ~/ 2;
            final isLineActive = steps[lineIdx + 1];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 3,
                  decoration: BoxDecoration(
                    color: isLineActive ? activeColor : Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }
        }),
      ),
    );
  }

  // --- КАРТОЧКА ЕДЫ / МАГАЗИНОВ ---
  Widget buildFoodOrderCard(Order order) {
    bool isCancelled = order.status == 'cancelled';

    String title = 'Заказ из ресторана';
    String prepLabel = 'Готовим';
    IconData prepIcon = Icons.restaurant;
    Color themeColor = Colors.deepOrange;

    if (order.type == 'apteka') {
      title = 'Заказ из аптеки';
      prepLabel = 'Собираем';
      prepIcon = Icons.medical_services;
      themeColor = Colors.teal;
    } else if (order.type == 'electronika') {
      title = 'Заказ электроники';
      prepLabel = 'Собираем';
      prepIcon = Icons.devices;
      themeColor = Colors.indigo;
    } else if (order.type == 'product') {
      title = 'Заказ продуктов';
      prepLabel = 'Собираем';
      prepIcon = Icons.shopping_basket;
      themeColor = Colors.green;
    } else if (order.type == 'svetok') {
      title = 'Заказ цветов';
      prepLabel = 'Собираем';
      prepIcon = Icons.local_florist;
      themeColor = Colors.pinkAccent;
    }

    final steps = [
      true,
      order.startedAt != null,
      order.readyAt != null,
      order.acceptedAt != null || order.inProgressAt != null,
      order.deliveredAt != null
    ];

    final icons = [Icons.receipt_long, prepIcon, Icons.takeout_dining, Icons.delivery_dining, Icons.check_circle];
    final labels = ['Создан', prepLabel, 'Готов', 'В пути', 'У вас'];

    return _baseCard(
      title: title,
      date: order.dateTime,
      status: isCancelled ? 'Отменен' : (order.deliveredAt != null ? 'Доставлен' : 'Активен'),
      color: isCancelled ? Colors.red : themeColor,
      onDelete: isCancelled || order.deliveredAt != null ? () => _deleteOrder('orders', order.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${item.dish.name} x${item.quantity}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
          )),
          const Divider(height: 24),
          if (isCancelled)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text("ЗАКАЗ ОТМЕНЕН", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            )
          else
            _buildProgressBar(steps, icons, labels, themeColor),
          Text('${order.total.toInt()} Руб', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  // --- КАРТОЧКА ДОСТАВКИ ---
  Widget buildDeliveryOrderCard(DeliveryOrder order) {
    bool isCancelled = order.status == 'cancelled';
    final steps = [true, order.acceptedAt != null, order.inProgressAt != null, order.deliveredAt != null];
    final icons = [Icons.fiber_new, Icons.person_pin_circle, Icons.directions_bike, Icons.done_all];
    final labels = ['Новый', 'Принят', 'Везем', 'Готово'];

    return _baseCard(
      title: 'Срочная доставка',
      date: order.createdAt,
      status: isCancelled ? 'Отменен' : _translateStatus(order.status),
      color: isCancelled ? Colors.red : Colors.blueAccent,
      onDelete: (order.deliveredAt != null || isCancelled) ? () => _deleteOrder('delivery_orders', order.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _locationRow(Icons.radio_button_checked, 'Откуда', Colors.blue),
          _locationRow(Icons.location_on, 'Куда', Colors.redAccent),
          if (isCancelled)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text("ЗАКАЗ ОТМЕНЕН", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            )
          else
            _buildProgressBar(steps, icons, labels, Colors.blueAccent),
          Text('${order.totalCost.toInt()} Руб', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  // --- КАРТОЧКА ГРУЗОПЕРЕВОЗОК ---
  Widget buildCargoCard(String type, dynamic order, Color color, String collection) {
    bool isCancelled = order.status == 'cancelled';
    final steps = [true, order.acceptedAt != null, order.inProgressAt != null, order.deliveredAt != null];
    final icons = [Icons.playlist_add_check, Icons.assignment_ind, Icons.local_shipping, Icons.home_work];
    final labels = ['Заявка', 'Водитель', 'В пути', 'Прибыл'];

    return _baseCard(
      title: type,
      date: order.createdAt,
      status: isCancelled ? 'Отменен' : _translateStatus(order.status),
      color: isCancelled ? Colors.red : color,
      onDelete: (order.deliveredAt != null || isCancelled) ? () => _deleteOrder(collection, order.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${order.fromAddress} → ${order.toAddress}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('Кузов: ${order.bodyType} • Грузчики: ${order.loaders}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (isCancelled)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text("ЗАКАЗ ОТМЕНЕН", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            )
          else
            _buildProgressBar(steps, icons, labels, color),
          Text('${order.totalPrice.toInt()} Руб', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _baseCard({required String title, required DateTime date, required String status, required Color color, required Widget child, VoidCallback? onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(DateFormat('dd MMM, HH:mm').format(date.toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                if (onDelete != null)
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
        ],
      ),
    );
  }

  Widget _locationRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54))]),
    );
  }

  Future<void> _deleteOrder(String collection, String id) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection(collection).doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Авторизуйтесь для просмотра'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Статус заказов', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Order>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          return StreamBuilder<List<DeliveryOrder>>(
            stream: deliveryStream,
            builder: (context, snapshotDel) {
              return StreamBuilder<List<CityDeliveryOrder>>(
                stream: cityDeliveryStream,
                builder: (context, snapshotCity) {
                  return StreamBuilder<List<MejCityDeliveryOrder>>(
                    stream: mejCityDeliveryStream,
                    builder: (context, snapshotMej) {
                      final combined = [
                        ...(snapshot.data ?? []).map((o) => {'type': 'food', 'order': o}),
                        ...(snapshotDel.data ?? []).map((d) => {'type': 'delivery', 'order': d}),
                        ...(snapshotCity.data ?? []).map((c) => {'type': 'city', 'order': c}),
                        ...(snapshotMej.data ?? []).map((m) => {'type': 'mej', 'order': m}),
                      ];

                      combined.sort((a, b) => _getOrderDate(b).compareTo(_getOrderDate(a)));

                      if (combined.isEmpty) {
                        return Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.query_stats_rounded, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text('Активных заказов нет', style: TextStyle(color: Colors.grey)),
                          ],
                        ));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: combined.length,
                        itemBuilder: (context, index) {
                          final item = combined[index];
                          final type = item['type'];
                          final order = item['order'];

                          if (type == 'food') return buildFoodOrderCard(order as Order);
                          if (type == 'delivery') return buildDeliveryOrderCard(order as DeliveryOrder);
                          if (type == 'city') return buildCargoCard('Городская доставка', order, Colors.green, 'cityOrders');
                          return buildCargoCard('Межгород доставка', order, Colors.blueGrey, 'mejCityOrders');
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

  DateTime _getOrderDate(Map<String, dynamic> item) {
    final type = item['type'];
    final o = item['order'];
    if (type == 'food') return (o as Order).dateTime;
    if (type == 'delivery') return (o as DeliveryOrder).createdAt;
    if (type == 'city') return (o as CityDeliveryOrder).createdAt;
    return (o as MejCityDeliveryOrder).createdAt;
  }
}
