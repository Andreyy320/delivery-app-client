import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/order_model.dart';
import '../Dostavka/DeliveryOrder.dart';
import '../Dostavka/gorod_model.dart';
import '../Dostavka/mejgorod_model.dart'; // Модель городских заказов

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

  final Map<String, String> statusText = {
    'preparing': 'Ваш заказ готовится',
    'ready': 'Заказ готов',
    'inProgress': 'Курьер едет к вам',
    'delivered': 'Заказ доставлен',
    'new': 'Заказ создан',
  };

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Поток заказов еды
      ordersStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
          snapshot.docs
              .map((doc) => Order.fromFirestore(doc.id, doc.data()))
              .toList());

      // Поток срочной доставки
      deliveryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('delivery_orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
          snapshot.docs
              .map((doc) => DeliveryOrder.fromFirestore(doc.id, doc.data()))
              .toList());

      // Поток городских заказов
      cityDeliveryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cityOrders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
          snapshot.docs
              .map((doc) => CityDeliveryOrder.fromFirestore(doc.id, doc.data()))
              .toList());


      // Поток Межгородских заказов
      mejCityDeliveryStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('mejCityOrders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
          snapshot.docs
              .map((doc) =>
              MejCityDeliveryOrder.fromFirestore(doc.id, doc.data()))
              .toList());
    }
  }

  Widget _statusCircle(bool active, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? Colors.deepOrange : Colors.grey[300],
          child: Icon(
              icon, color: active ? Colors.white : Colors.grey[600], size: 16),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _line(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? Colors.deepOrange : Colors.grey[300],
      ),
    );
  }

  /// Карточка еды
  Widget buildFoodOrderCard(Order order) {

    final preparingActive = order.startedAt != null;       // ресторан начал готовить
    final readyActive = order.readyAt != null;            // заказ готов
    final inProgressActive = order.acceptedAt != null || order.inProgressAt != null; // курьер принял или в пути
    final deliveredActive = order.deliveredAt != null;    // доставлено

    String currentStatus() {
      if (deliveredActive) return 'Заказ доставлен';
      if (inProgressActive) return 'Курьер едет к вам';
      if (readyActive) return 'Заказ готов';
      if (preparingActive) return 'Заказ готовится';
      return 'Заказ создан';
    }

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
            Text(
              'Заказ от ${order.dateTime.toLocal().toString().split('.')[0]}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...order.items.map(
                  (item) => Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      item.dish.imagePath,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.dish.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${item.dish.price} ₽ × ${item.quantity}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('${item.dish.price * item.quantity} ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Итого: ${order.total.toStringAsFixed(0)} ₽',
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                _statusCircle(preparingActive, Icons.settings, 'Готовится'),
                _line(readyActive || inProgressActive || deliveredActive),
                _statusCircle(readyActive, Icons.check_circle_outline, 'Готов'),
                _line(inProgressActive || deliveredActive),
                _statusCircle(inProgressActive, Icons.directions_bike, 'В пути'),
                _line(deliveredActive),
                _statusCircle(deliveredActive, Icons.check_circle, 'Доставлено'),
              ],
            ),
            const SizedBox(height: 4),
            Text(currentStatus(),
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOrder(String collection, String id) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection(collection)
        .doc(id)
        .delete();
  }

    /// Карточка срочной доставки
  Widget buildDeliveryOrderCard(DeliveryOrder order) {
    // Логика активации точек (используем новые поля из модели)
    final acceptedActive = order.acceptedAt != null;       // Курьер принял
    final inProgressActive = order.inProgressAt != null;   // Курьер в пути
    final deliveredActive = order.deliveredAt != null;     // Посылка у клиента

    String currentStatus() {
      if (deliveredActive) return 'Посылка доставлена';
      if (inProgressActive) return 'Курьер везет вашу посылку';
      if (acceptedActive) return 'Курьер принял заказ';
      if (order.status == 'cancelled') return 'Заказ отменен';
      return 'Поиск курьера...';
    }

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
                // 🔹 Обернул только текст в Expanded, чтобы он не выталкивал корзину
                Expanded(
                  child: Text(
                    'Срочная доставка от ${order.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis, // Защита от вылета текста
                    maxLines: 1,
                  ),
                ),
                // Удаление как в еде
                if (deliveredActive || order.status == 'cancelled')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteOrder('delivery_orders', order.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Маршрут
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('Откуда: ${order.pickup.latitude.toStringAsFixed(4)}, ${order.pickup.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('Куда: ${order.dropoff.latitude.toStringAsFixed(4)}, ${order.dropoff.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 13))),
              ],
            ),

            const SizedBox(height: 12),
            Text('Итого: ${order.totalCost.toStringAsFixed(0)} ₽',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // Прогресс-бар (ВСЁ КАК БЫЛО)
            Row(
              children: [
                _statusCircle(true, Icons.fiber_new, 'Создан'),
                _line(acceptedActive || inProgressActive || deliveredActive),
                _statusCircle(acceptedActive, Icons.person_pin_circle, 'Принят'),
                _line(inProgressActive || deliveredActive),
                _statusCircle(inProgressActive, Icons.directions_bike, 'В пути'),
                _line(deliveredActive),
                _statusCircle(deliveredActive, Icons.check_circle, 'Доставлено'),
              ],
            ),
            const SizedBox(height: 4),
            Text(currentStatus(),
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ),
      ),
    );
  }


  /// Карточка городской доставки
  /// Карточка городской доставки
  Widget buildCityDeliveryOrderCard(CityDeliveryOrder order) {
    // Логика активации точек по времени (как в твоем примере)
    final acceptedActive = order.acceptedAt != null;       // Принят
    final inProgressActive = order.inProgressAt != null;   // В пути
    final deliveredActive = order.deliveredAt != null;     // Доставлено

    String currentStatus() {
      if (deliveredActive) return 'Доставка завершена';
      if (inProgressActive) return 'Машина в пути к вам';
      if (acceptedActive) return 'Заказ принят водителем';
      if (order.status == 'cancelled') return 'Заказ отменен';
      return 'Поиск машины...';
    }

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
                // 🔹 Защита от Overflow
                Expanded(
                  child: Text(
                    'Городская доставка от ${order.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // Корзина удаления
                if (deliveredActive || order.status == 'cancelled')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteOrder('delivery_orders', order.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Маршрут (используем адреса текстом)
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('Откуда: ${order.fromAddress}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('Куда: ${order.toAddress}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),

            const SizedBox(height: 8),
            // Опции заказа
            Text(
              'Опции: Кузов ${order.bodyType}, Грузчики: ${order.loaders}, Сопровождающий: ${order.escort}',
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),

            const SizedBox(height: 12),
            Text('Итого: ${order.totalPrice.toStringAsFixed(0)} ₽',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
            const SizedBox(height: 12),

            // Прогресс-бар (Идентичный твоему примеру)
            Row(
              children: [
                _statusCircle(true, Icons.fiber_new, 'Создан'),
                _line(acceptedActive || inProgressActive || deliveredActive),
                _statusCircle(acceptedActive, Icons.person_pin_circle, 'Принят'),
                _line(inProgressActive || deliveredActive),
                _statusCircle(inProgressActive, Icons.local_shipping, 'В пути'), // Иконка грузовика для города
                _line(deliveredActive),
                _statusCircle(deliveredActive, Icons.check_circle, 'Доставлено'),
              ],
            ),
            const SizedBox(height: 4),
            Text(currentStatus(),
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ),
      ),
    );
  }


  /// Карточка межгородской доставки
  Widget buildMejCityDeliveryOrderCard(MejCityDeliveryOrder order) {
    // Логика активации точек (используем новые поля из модели по твоему примеру)
    final acceptedActive = order.acceptedAt != null;       // Курьер принял
    final inProgressActive = order.inProgressAt != null;   // Курьер в пути
    final deliveredActive = order.deliveredAt != null;     // Посылка у клиента

    String currentStatus() {
      if (deliveredActive) return 'Доставлено в другой город';
      if (inProgressActive) return 'Груз в пути по межгороду';
      if (acceptedActive) return 'Водитель назначен';
      if (order.status == 'cancelled') return 'Заказ отменен';
      return 'Поиск машины для межгорода...';
    }

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
                // 🔹 Обернул текст в Expanded, чтобы не было Overflow из-за даты
                Expanded(
                  child: Text(
                    'Межгород от ${order.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // Удаление (появляется только в финале или при отмене)
                if (deliveredActive || order.status == 'cancelled')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteOrder('delivery_orders', order.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Маршрут
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('Откуда: ${order.fromAddress}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('Куда: ${order.toAddress}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),

            const SizedBox(height: 8),
            // Доп. инфо для межгорода
            Text(
              'Кузов: ${order.bodyType}, Грузчики: ${order.loaders}, Сопровождение: ${order.escort}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            const SizedBox(height: 12),
            Text('Итого: ${order.totalPrice.toStringAsFixed(0)} ₽',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // Прогресс-бар (Идентичный твоему примеру со срочной доставкой)
            Row(
              children: [
                _statusCircle(true, Icons.fiber_new, 'Создан'),
                _line(acceptedActive || inProgressActive || deliveredActive),
                _statusCircle(acceptedActive, Icons.person_pin_circle, 'Принят'),
                _line(inProgressActive || deliveredActive),
                _statusCircle(inProgressActive, Icons.local_shipping, 'В пути'), // Иконка фуры для межгорода
                _line(deliveredActive),
                _statusCircle(deliveredActive, Icons.check_circle, 'Прибыл'),
              ],
            ),
            const SizedBox(height: 4),
            Text(currentStatus(),
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('Вы не вошли в систему'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заказы'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<List<Order>>(
        stream: ordersStream,
        builder: (context, orderSnapshot) {
          final orders = orderSnapshot.data ?? [];

          return StreamBuilder<List<DeliveryOrder>>(
            stream: deliveryStream,
            builder: (context, deliverySnapshot) {
              final deliveries = deliverySnapshot.data ?? [];

              return StreamBuilder<List<CityDeliveryOrder>>(
                stream: cityDeliveryStream,
                builder: (context, citySnapshot) {
                  final cityOrders = citySnapshot.data ?? [];

                  return StreamBuilder<List<MejCityDeliveryOrder>>(
                    stream: mejCityDeliveryStream,
                    builder: (context, mejSnapshot) {
                      final mejCityOrders = mejSnapshot.data ?? [];

                      // Объединяем все четыре типа заказов
                      final combinedList = [
                        ...orders.map((o) => {'type': 'food', 'order': o}),
                        ...deliveries.map((d) =>
                        {
                          'type': 'delivery',
                          'order': d
                        }),
                        ...cityOrders.map((c) => {'type': 'city', 'order': c}),
                        ...mejCityOrders.map((m) =>
                        {
                          'type': 'mejCity',
                          'order': m
                        }),
                      ];

                      // Сортируем по дате
                      combinedList.sort((a, b) {
                        DateTime dateA = a['type'] == 'food'
                            ? (a['order'] as Order).dateTime
                            : a['type'] == 'delivery'
                            ? (a['order'] as DeliveryOrder).createdAt
                            : a['type'] == 'city'
                            ? (a['order'] as CityDeliveryOrder).createdAt
                            : (a['order'] as MejCityDeliveryOrder).createdAt;

                        DateTime dateB = b['type'] == 'food'
                            ? (b['order'] as Order).dateTime
                            : b['type'] == 'delivery'
                            ? (b['order'] as DeliveryOrder).createdAt
                            : b['type'] == 'city'
                            ? (b['order'] as CityDeliveryOrder).createdAt
                            : (b['order'] as MejCityDeliveryOrder).createdAt;

                        return dateB.compareTo(dateA);
                      });

                      if (combinedList.isEmpty) {
                        return const Center(
                          child: Text('Вы ещё не делали заказов',
                              style: TextStyle(fontSize: 16)),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: combinedList.length,
                        itemBuilder: (context, index) {
                          final item = combinedList[index];
                          switch (item['type']) {
                            case 'food':
                              return buildFoodOrderCard(item['order'] as Order);
                            case 'delivery':
                              return buildDeliveryOrderCard(
                                  item['order'] as DeliveryOrder);
                            case 'city':
                              return buildCityDeliveryOrderCard(
                                  item['order'] as CityDeliveryOrder);
                            case 'mejCity':
                              return buildMejCityDeliveryOrderCard(
                                  item['order'] as MejCityDeliveryOrder);
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
}

