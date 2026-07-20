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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Заказ удален', style: TextStyle(fontWeight: FontWeight.w600)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Мои заказы',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F6F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'История пока пуста',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Все ваши заказы появятся на этом экране',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: combinedList.length,
                        itemBuilder: (context, index) {
                          final item = combinedList[index];
                          final type = item['type'] as String;
                          final orderData = item['order'];

                          if (type == 'food') return _buildFoodCard(orderData as Order);
                          if (type == 'delivery') return _buildExpressCard(orderData as DeliveryOrder);
                          if (type == 'city') return _buildCargoCard('Город', orderData as CityDeliveryOrder, const Color(0xFF10B981), 'cityOrders');
                          return _buildCargoCard('Межгород', orderData as MejCityDeliveryOrder, const Color(0xFFD97706), 'mejCityOrders');
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
      color: const Color(0xFF8B5CF6),
      icon: Icons.directions_run_rounded,
      title: 'Экспресс курьер',
      dateTime: order.createdAt,
      path: 'delivery_orders',
      id: order.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeRow(Icons.circle_outlined, const Color(0xFF0F172A), "Откуда: $fromCoord"),
          _build3dConnector(),
          _routeRow(Icons.location_on_rounded, const Color(0xFF8B5CF6), "Куда: $toCoord"),

          if (order.options.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: order.options.map((opt) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text(_translateOption(opt), style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                  ],
                ),
              )).toList(),
            ),
          ],

          _divider(),
          _footerRow(order.totalCost.toInt().toString(), order.status, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildFoodCard(Order order) {
    return _baseCard(
      color: const Color(0xFFF97316),
      icon: Icons.restaurant_rounded,
      title: order.restaurantName ?? 'Доставка еды',
      dateTime: order.dateTime,
      path: 'orders',
      id: order.id,
      child: Column(
        children: [
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.dish.imagePath.startsWith('http')
                        ? Image.network(item.dish.imagePath, width: 42, height: 42, fit: BoxFit.cover)
                        : Image.asset(item.dish.imagePath, width: 42, height: 42, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.dish.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.quantity} шт',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )),
          _divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.total.toInt()} Руб',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
              ),
              Container(
                height: 38,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _repeatOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Повторить', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCargoCard(String title, dynamic order, Color color, String path) {
    return _baseCard(
      color: color,
      icon: Icons.local_shipping_rounded,
      title: 'Грузовое: $title',
      dateTime: order.createdAt,
      path: path,
      id: order.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeRow(Icons.circle_outlined, const Color(0xFF0F172A), order.fromAddress),
          _build3dConnector(),
          _routeRow(Icons.location_on_rounded, color, order.toAddress),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Кузов: ${order.bodyType} • Грузчики: ${order.loaders}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _divider(),
          _footerRow(order.totalPrice.toString(), order.status, color),
        ],
      ),
    );
  }

  Widget _baseCard({
    required Color color,
    required IconData icon,
    required String title,
    required DateTime dateTime,
    required String path,
    required String id,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFAFAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A), letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd.MM.yyyy  •  HH:mm').format(dateTime.toLocal()),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _deleteOrder(path, id),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _build3dConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 12, top: 3, bottom: 3),
      alignment: Alignment.centerLeft,
      child: Container(
        width: 2,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
  );

  Widget _routeRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _footerRow(String price, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$price Руб',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            _translateStatus(status).toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}