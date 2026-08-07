import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/dish_model.dart';
import '../../models/order_model.dart';
import '../../screens/Menu/Cart_data.dart';
import '../../screens/Menu/cart_screen.dart';
import '../Dostavka/DeliveryOrder.dart';
import '../Dostavka/courier_express_screen.dart';
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

  List<Order> localOrderHistory = [];
  List<DeliveryOrder> localDeliveryHistory = [];

  @override
  void initState() {
    super.initState();
    _initOrdersStream();
  }

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
    // Загружаем заказы без неравенств и индексов, фильтрацию делаем в памяти через .map
    ordersStream = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      try {
        return Order.fromFirestore(doc.id, doc.data());
      } catch (e) {
        debugPrint('Ошибка парсинга заказа еды ${doc.id}: $e');
        return null;
      }
    })
        .where((order) => order != null)
        .cast<Order>()
    // Исключаем скрытые заказы прямо на клиенте
        .where((order) => docDataIsVisible(snapshot.docs, order.id))
        .toList());

    deliveryStream = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('delivery_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      try {
        return DeliveryOrder.fromFirestore(doc.id, doc.data());
      } catch (e) {
        debugPrint('Ошибка парсинга доставки ${doc.id}: $e');
        return null;
      }
    })
        .where((order) => order != null)
        .cast<DeliveryOrder>()
    // Исключаем скрытые доставки прямо на клиенте
        .where((order) => docDataIsVisible(snapshot.docs, order.id))
        .toList());
  }

  // Вспомогательная проверка поля hiddenForUser локально
  bool docDataIsVisible(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String id) {
    try {
      final doc = docs.firstWhere((d) => d.id == id);
      final data = doc.data();
      return data['hiddenForUser'] != true;
    } catch (_) {
      return true;
    }
  }

  // Помечаем заказ скрытым для клиента в БД
  Future<void> _deleteOrder(String collectionPath, String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection(collectionPath)
          .doc(orderId)
          .update({'hiddenForUser': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Заказ скрыт из истории', style: TextStyle(fontWeight: FontWeight.w600)),
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
          if (orderSnapshot.hasError) {
            return Center(child: Text('Ошибка еды: ${orderSnapshot.error}'));
          }

          return StreamBuilder<List<DeliveryOrder>>(
            stream: deliveryStream,
            builder: (context, deliverySnapshot) {
              if (deliverySnapshot.hasError) {
                return Center(child: Text('Ошибка доставки: ${deliverySnapshot.error}'));
              }

              if (orderSnapshot.connectionState == ConnectionState.waiting ||
                  deliverySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final firestoreOrders = orderSnapshot.data ?? [];
              final firestoreDelivery = deliverySnapshot.data ?? [];

              final combinedList = [
                ...localOrderHistory.map((o) => {'type': 'food', 'order': o}),
                ...firestoreOrders.map((o) => {'type': 'food', 'order': o}),
                ...localDeliveryHistory.map((d) => {'type': 'delivery', 'order': d}),
                ...firestoreDelivery.map((d) => {'type': 'delivery', 'order': d}),
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
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
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
                  return _buildExpressCard(orderData as DeliveryOrder);
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
    return (o as DeliveryOrder).createdAt;
  }

  Widget _buildExpressCard(DeliveryOrder order) {
    // Берем значения прямо из объекта, который пришел из базы
    String fromText = order.pickupAddress ?? 'Не указано';
    String toText = order.dropoffAddress ?? 'Не указано';

    // Заголовок заказа
    String subTypeTitle = 'Индивидуальная доставка';
    if (order.subType == 'buy') {
      subTypeTitle = 'Заказ: Купить и привезти';
    } else if (order.subType == 'pickup') {
      subTypeTitle = 'Заказ: Забрать отправление';
    } else if (order.subType == 'task') {
      subTypeTitle = 'Заказ: Поручение';
    }

    return _baseCard(
      color: const Color(0xFF8B5CF6),
      leadingWidget: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
        ),
        child: const Icon(Icons.directions_run_rounded, color: Color(0xFF8B5CF6), size: 18),
      ),
      title: subTypeTitle,
      dateTime: order.createdAt,
      path: 'delivery_orders',
      id: order.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeRow(Icons.circle_outlined, const Color(0xFF0F172A), "Откуда: $fromText"),
          _build3dConnector(),
          _routeRow(Icons.location_on_rounded, const Color(0xFF8B5CF6), "Куда: $toText"),

          // Выводим описание только если оно реально заполнено и не равно "Без описания"
          if (order.description != null &&
              order.description!.trim().isNotEmpty &&
              order.description != 'Без описания') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes, size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${order.description}",
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _divider(),
          _footerRow(order.totalCost.toInt().toString(), const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }
  Widget _buildFoodCard(Order order) {
    List<dynamic> displayItems = order.items;

    // 1. Приоритетно берем готовую итоговую сумму из полей документа в БД
    double finalTotalSum = 0.0;

    if (order.totalPrice != null && order.totalPrice! > 0) {
      finalTotalSum = order.totalPrice!.toDouble();
    } else if ((order as dynamic).total != null && ((order as dynamic).total as num) > 0) {
      finalTotalSum = ((order as dynamic).total as num).toDouble();
    } else {
      // 2. Фолбэк-пересчет, если в документе нет totalPrice / total
      double calculatedItemsTotal = 0.0;

      for (var item in displayItems) {
        final itemMap = item is Map ? item : null;

        final price = itemMap != null
            ? ((itemMap['price'] ?? 0.0) as num).toDouble()
            : ((item.dish?.price ?? 0.0) as num).toDouble();

        final quantity = itemMap != null
            ? ((itemMap['quantity'] ?? 1) as num).toInt()
            : ((item.quantity ?? 1) as num).toInt();

        double modifiersTotal = 0.0;
        final dynamic itemModifiers = itemMap != null
            ? (itemMap['modifiers'] ?? itemMap['addons'])
            : ((item as dynamic).modifiers ?? (item.dish as dynamic).modifiers);

        if (itemModifiers != null && itemModifiers is List) {
          for (var mod in itemModifiers) {
            if (mod is Map && mod['price'] != null) {
              modifiersTotal += (mod['price'] is num)
                  ? (mod['price'] as num).toDouble()
                  : (double.tryParse(mod['price'].toString()) ?? 0.0);
            }
          }
        }

        // Итоговая стоимость одной позиции = (Базовая цена + Модификаторы) * Количество
        calculatedItemsTotal += (price + modifiersTotal) * quantity;
      }

      final delivery = (order.deliveryPrice ?? 0.0).toDouble();
      finalTotalSum = calculatedItemsTotal + delivery;
    }

    final delivery = (order.deliveryPrice ?? 0.0).toDouble();

    Widget logoWidget = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2)),
      ),
      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFF97316), size: 18),
    );

    if (order.shopId != null && order.shopId!.isNotEmpty) {
      logoWidget = FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('categories').doc(order.shopId).get(),
        builder: (context, snapshot) {
          String? logoUrl;
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            logoUrl = data?['logoUrl'] ?? data?['image'];
          }

          if (logoUrl != null && logoUrl.isNotEmpty) {
            return Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2), width: 1.5),
              ),
              child: ClipOval(
                child: logoUrl.startsWith('http')
                    ? Image.network(
                  logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackRestaurantIcon(),
                )
                    : Image.asset(
                  logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackRestaurantIcon(),
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.restaurant_rounded, color: Color(0xFFF97316), size: 18),
          );
        },
      );
    }

    return _baseCard(
      color: const Color(0xFFF97316),
      leadingWidget: logoWidget,
      title: order.restaurantName ?? 'Заказ из заведения',
      dateTime: order.dateTime,
      path: 'orders',
      id: order.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...displayItems.asMap().entries.map((entry) {
            final int index = entry.key;
            final item = entry.value;

            final itemMap = item is Map ? item : null;

            final name = itemMap != null
                ? (itemMap['name'] ?? itemMap['title'] ?? 'Товар')
                : (item.dish?.name ?? 'Товар');

            final image = itemMap != null
                ? (itemMap['imagePath'] ?? itemMap['imageUrl'] ?? itemMap['image'] ?? '')
                : (item.dish?.imagePath ?? '');

            final price = itemMap != null
                ? ((itemMap['price'] ?? 0.0) as num).toDouble()
                : ((item.dish?.price ?? 0.0) as num).toDouble();

            final quantity = itemMap != null
                ? ((itemMap['quantity'] ?? 1) as num).toInt()
                : ((item.quantity ?? 1) as num).toInt();

            final weight = itemMap != null
                ? (itemMap['weight']?.toString() ?? '')
                : (item.dish?.weight?.toString() ?? '');

            String? size;
            if (itemMap != null) {
              size = itemMap['size'] ??
                  itemMap['selectedSize'] ??
                  itemMap['selected_size'] ??
                  itemMap['dishSize'];
            } else {
              try {
                size = (item as dynamic).size ??
                    (item as dynamic).selectedSize ??
                    (item as dynamic).selected_size;
              } catch (_) {}

              if ((size == null || size.toString().isEmpty) && item.dish != null) {
                try {
                  final d = item.dish;
                  if (d is Map) {
                    size = d['size'] ?? d['selectedSize'] ?? d['dishSize'];
                  } else {
                    size = (d as dynamic).size ?? (d as dynamic).selectedSize;
                  }
                } catch (_) {}
              }
            }

            final String finalSize = (size != null) ? size.toString().trim() : '';

            final dynamic rawModifiers = itemMap != null
                ? (itemMap['modifiers'] ?? itemMap['addons'])
                : ((item as dynamic).modifiers ?? (item.dish as dynamic).modifiers);

            final List<dynamic>? modifiers = rawModifiers is List ? rawModifiers : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (image.isNotEmpty)
                          ? (image.startsWith('http')
                          ? Image.network(
                        image,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
                      )
                          : Image.asset(
                        image,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
                      ))
                          : _imageErrorPlaceholder(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                '${price.toInt()} Руб',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (finalSize.isNotEmpty || (weight.isNotEmpty && weight != '0')) ...[
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (finalSize.isNotEmpty) 'Размер: $finalSize',
                                if (weight.isNotEmpty && weight != '0') weight
                              ].join(' • '),
                              style: const TextStyle(
                                color: Color(0xFFF97316),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$quantity шт',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (modifiers != null && modifiers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Дополнительно',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...modifiers.map((mod) {
                          String modName = '';
                          double modPrice = 0.0;

                          if (mod is Map) {
                            modName = mod['name']?.toString() ?? '';
                            modPrice = double.tryParse(mod['price']?.toString() ?? '0') ?? 0.0;
                          } else {
                            try {
                              modName = (mod as dynamic).name.toString();
                              modPrice = double.tryParse((mod as dynamic).price.toString()) ?? 0.0;
                            } catch (_) {
                              modName = mod.toString();
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add_rounded, size: 12, color: Color(0xFFF97316)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          modName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (modPrice > 0)
                                  Text(
                                    '+${modPrice.toInt()} Руб',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFF97316),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
          if (delivery > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.delivery_dining_rounded, size: 16, color: Color(0xFF94A3B8)),
                    SizedBox(width: 8),
                    Text(
                      'Доставка',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  '${delivery.toInt()} Руб',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
          _divider(),
          _footerRow(finalTotalSum.toInt().toString(), const Color(0xFFF97316)),
        ],
      ),
    );
  }




  Widget _fallbackRestaurantIcon() {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFF97316), size: 18),
    );
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade100,
      child: const Icon(Icons.fastfood_rounded, size: 24, color: Color(0xFF94A3B8)),
    );
  }

  Widget _baseCard({
    required Color color,
    required Widget leadingWidget,
    required String title,
    required DateTime dateTime,
    required String path,
    required String id,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      leadingWidget,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd.MM.yyyy  •  HH:mm').format(dateTime.toLocal()),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _deleteOrder(path, id),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _routeRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _build3dConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
      child: Column(
        children: List.generate(
          3,
              (index) => Container(
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            width: 2.5,
            height: 2.5,
            decoration: const BoxDecoration(
              color: Color(0xFFCBD5E1),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
    );
  }

  Widget _footerRow(String total, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Итого', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '$total Руб',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
          ],
        ),
      ],
    );
  }
}