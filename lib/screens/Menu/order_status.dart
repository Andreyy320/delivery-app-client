import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/order_model.dart';
import '../Dostavka/DeliveryOrder.dart';
import '../../NO_USED_SCREEN/gorod_model.dart';
import '../../NO_USED_SCREEN/mejgorod_model.dart';
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

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Ожидание';
      case 'new': return 'Новый';
      case 'accepted': return 'Принят';
      case 'preparing': return 'Готовится';
      case 'ready': return 'Готов';
      case 'in_progress':
      case 'inprogress':
      case 'delivering': return 'В пути';
      case 'delivered':
      case 'completed': return 'Доставлен';
      case 'cancelled': return 'Отменен';
      default: return status;
    }
  }

  Widget _buildCancelledWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AEF4444),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFE11D48), size: 20),
          SizedBox(width: 8),
          Text(
            "ЗАКАЗ ОТМЕНЕН",
            style: TextStyle(
              color: Color(0xFFE11D48),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(List<bool> steps, List<IconData> icons, List<String> labels, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isEven) {
            final stepIdx = index ~/ 2;
            final isActive = steps[stepIdx];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? LinearGradient(
                      colors: [
                        activeColor.withOpacity(0.85),
                        activeColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: isActive
                        ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 2,
                        offset: const Offset(-1, -1),
                      ),
                    ]
                        : [
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(-1, -1),
                      )
                    ],
                  ),
                  child: Icon(
                    icons[stepIdx],
                    color: isActive ? Colors.white : const Color(0xFF64748B),
                    size: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[stepIdx],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            );
          } else {
            final lineIdx = index ~/ 2;
            final isLineActive = steps[lineIdx + 1];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isLineActive ? activeColor : const Color(0xFFE2E8F0),
                    boxShadow: isLineActive
                        ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : [
                      const BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 1,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }),
      ),
    );
  }

  Widget buildFoodOrderCard(Order order) {
    bool isCancelled = order.status == 'cancelled';

    // Безопасная проверка для nullable String
    String title = (order.restaurantName != null && order.restaurantName!.isNotEmpty)
        ? order.restaurantName!
        : 'Заказ из ресторана';

    String prepLabel = 'Готовим';
    IconData prepIcon = Icons.restaurant_rounded;
    Color themeColor = const Color(0xFFF97316);

    if (order.type == 'apteka') {
      if (order.restaurantName == null || order.restaurantName!.isEmpty) {
        title = 'Заказ из аптеки';
      }
      prepLabel = 'Собираем';
      prepIcon = Icons.medical_services_rounded;
      themeColor = const Color(0xFF0D9488);
    } else if (order.type == 'electronika') {
      if (order.restaurantName == null || order.restaurantName!.isEmpty) {
        title = 'Заказ электроники';
      }
      prepLabel = 'Собираем';
      prepIcon = Icons.devices_rounded;
      themeColor = const Color(0xFF6366F1);
    } else if (order.type == 'product') {
      if (order.restaurantName == null || order.restaurantName!.isEmpty) {
        title = 'Заказ продуктов';
      }
      prepLabel = 'Собираем';
      prepIcon = Icons.shopping_basket_rounded;
      themeColor = const Color(0xFF16A34A);
    } else if (order.type == 'svetok') {
      if (order.restaurantName == null || order.restaurantName!.isEmpty) {
        title = 'Заказ цветов';
      }
      prepLabel = 'Собираем';
      prepIcon = Icons.local_florist_rounded;
      themeColor = const Color(0xFFEC4899);
    }

    final steps = [
      true,
      order.startedAt != null,
      order.readyAt != null,
      order.acceptedAt != null || order.inProgressAt != null,
      order.deliveredAt != null
    ];
    final icons = [
      Icons.receipt_long_rounded,
      prepIcon,
      Icons.takeout_dining_rounded,
      Icons.delivery_dining_rounded,
      Icons.check_circle_rounded
    ];
    final labels = ['Создан', prepLabel, 'Готов', 'В пути', 'У вас'];

    return _baseCard(
      title: title,
      date: order.dateTime,
      status: isCancelled ? 'Отменен' : (order.deliveredAt != null ? 'Доставлен' : 'Активен'),
      color: isCancelled ? const Color(0xFFEF4444) : themeColor,
      onDelete: isCancelled || order.deliveredAt != null ? () => _deleteOrder('orders', order.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...order.items.asMap().entries.map((entry) {
            final int index = entry.key;
            final item = entry.value;

            final name = item.dish.name;
            final image = item.dish.imagePath;
            final price = (item.dish.price ?? 0.0).toDouble();
            final quantity = (item.quantity ?? 1).toInt();
            final size = item.selectedSize;
            final weight = item.dish.weight;

            final dynamic rawModifiers = (item as dynamic).modifiers ?? (item.dish as dynamic).modifiers;
            final List<dynamic>? modifiers = rawModifiers is List ? rawModifiers : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (image.isNotEmpty)
                          ? (image.startsWith('http')
                          ? Image.network(
                        image,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageErrorPlaceholder(themeColor),
                      )
                          : Image.asset(
                        image,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageErrorPlaceholder(themeColor),
                      ))
                          : _imageErrorPlaceholder(themeColor),
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
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${price.toInt()} Руб',
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if ((size != null && size.isNotEmpty) || (weight.isNotEmpty && weight != '0')) ...[
                                const Text('  •  ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                Text(
                                  [
                                    if (size != null && size.isNotEmpty) size,
                                    if (weight.isNotEmpty && weight != '0') weight
                                  ].join(' • '),
                                  style: TextStyle(
                                    color: themeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity шт',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                if (modifiers != null && modifiers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Дополнительно',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                                      Icon(Icons.add_rounded, size: 12, color: themeColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          modName,
                                          style: const TextStyle(
                                            fontSize: 11,
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: themeColor,
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
          const SizedBox(height: 8),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          isCancelled ? _buildCancelledWidget() : _buildProgressBar(steps, icons, labels, themeColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'К оплате',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${order.total.toInt()} Руб',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageErrorPlaceholder(Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.fastfood_rounded, size: 22, color: color),
    );
  }

  Widget buildDeliveryOrderCard(DeliveryOrder order) {
    bool isCancelled = order.status == 'cancelled';
    final steps = [true, order.acceptedAt != null, order.inProgressAt != null, order.deliveredAt != null];
    final icons = [
      Icons.fiber_new_rounded,
      Icons.person_pin_circle_rounded,
      Icons.directions_bike_rounded,
      Icons.done_all_rounded
    ];
    final labels = ['Новый', 'Принят', 'Везем', 'Готово'];

    final pickupText = order.pickupAddress ?? 'Адрес отправления не указан';
    final dropoffText = order.dropoffAddress ?? 'Адрес назначения не указан';

    return _baseCard(
      title: 'Индивидуальная доставка',
      date: order.createdAt,
      status: isCancelled ? 'Отменен' : _translateStatus(order.status),
      color: isCancelled ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
      onDelete: (order.deliveredAt != null || isCancelled) ? () => _deleteOrder('delivery_orders', order.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _locationRow(Icons.radio_button_checked_rounded, pickupText, const Color(0xFF2563EB)),
          const SizedBox(height: 6),
          _locationRow(Icons.location_on_rounded, dropoffText, const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          isCancelled ? _buildCancelledWidget() : _buildProgressBar(steps, icons, labels, const Color(0xFF2563EB)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Стоимость',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${order.totalCost.toInt()} Руб',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCargoCard(String type, dynamic order, Color color, String collection) {
    bool isCancelled = order.status == 'cancelled';
    final steps = [true, order.acceptedAt != null, order.inProgressAt != null, order.deliveredAt != null];
    final icons = [
      Icons.playlist_add_check_rounded,
      Icons.assignment_ind_rounded,
      Icons.local_shipping_rounded,
      Icons.home_work_rounded
    ];
    final labels = ['Заявка', 'Водитель', 'В пути', 'Прибыл'];

    return _baseCard(
      title: type,
      date: order.createdAt,
      status: isCancelled ? 'Отменен' : _translateStatus(order.status),
      color: isCancelled ? const Color(0xFFEF4444) : color,
      onDelete: (order.deliveredAt != null || isCancelled) ? () => _deleteOrder(collection, order.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${order.fromAddress} → ${order.toAddress}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Кузов: ${order.bodyType}  •  Грузчики: ${order.loaders}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          isCancelled ? _buildCancelledWidget() : _buildProgressBar(steps, icons, labels, color),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${order.totalPrice.toInt()} Руб',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _baseCard({
    required String title,
    required DateTime date,
    required String status,
    required Color color,
    required Widget child,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF8FAFC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 6,
            spreadRadius: -2,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM, HH:mm').format(date.toLocal()),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (onDelete != null)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: onDelete,
                      splashRadius: 22,
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _locationRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteOrder(String collection, String id) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection(collection).doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEEF2F6),
        appBar: AppBar(
          title: const Text(
            'Статус заказов',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFEEF2F6),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Авторизуйтесь для просмотра',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      appBar: AppBar(
        title: const Text(
          'Статус заказов',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFEEF2F6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.08),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.9),
                                      blurRadius: 10,
                                      offset: const Offset(-5, -5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 52,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Активных заказов нет',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Ваши оформленные заказы будут отображаться здесь',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        physics: const BouncingScrollPhysics(),
                        itemCount: combined.length,
                        itemBuilder: (context, index) {
                          final item = combined[index];
                          final type = item['type'];
                          final order = item['order'];

                          if (type == 'food') return buildFoodOrderCard(order as Order);
                          if (type == 'delivery') return buildDeliveryOrderCard(order as DeliveryOrder);
                          if (type == 'city') {
                            return buildCargoCard('Городская доставка', order, const Color(0xFF16A34A), 'cityOrders');
                          }
                          return buildCargoCard('Межгород доставка', order, const Color(0xFF475569), 'mejCityOrders');
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