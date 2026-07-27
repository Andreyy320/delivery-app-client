import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled1/screens/Menu/cart_screen.dart';
import 'package:untitled1/screens/Menu/orders_screen.dart';
import 'package:untitled1/screens/Menu/profile_screen.dart';
import 'package:untitled1/screens/categories_page.dart';
import 'package:untitled1/screens/register_and_vhod/notification_service.dart';
import 'package:untitled1/screens/register_and_vhod/user_storage.dart';
import 'package:untitled1/screens/Menu/Cart_data.dart';
import '../models/auth_state.dart';

final Map<String, String> _globalProcessedOrders = {};
StreamSubscription<QuerySnapshot>? _ordersSubscription;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime? _appStartTime;
  StreamSubscription<User?>? _authSubscription;
  bool _isDialogShowing = false;

  final List<GlobalKey<NavigatorState>> _navigatorKeys =
  List.generate(4, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now().subtract(const Duration(seconds: 2));
    _initAuthListener();
    _restoreAuth();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _startListeningToOrders(user.uid);
      } else {
        _ordersSubscription?.cancel();
        _globalProcessedOrders.clear();
      }
    });
  }

  Future<void> _restoreAuth() async {
    final currentUser = await UserStorage.getCurrentUser();
    if (currentUser != null) {
      authState.login();
      if (mounted) setState(() {});
    }
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }

  Widget _buildOrdersTab() {
    return ValueListenableBuilder<bool>(
      valueListenable: authState,
      builder: (context, isLoggedIn, _) {
        final user = FirebaseAuth.instance.currentUser;
        if (!isLoggedIn || user == null) return const ProfileScreen();
        return OrdersScreen(userId: user.uid);
      },
    );
  }

  void _startListeningToOrders(String userId) {
    _ordersSubscription?.cancel();
    _ordersSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>;
        final orderId = change.doc.id;
        final status = (data['status'] ?? '').toString();
        Timestamp? timestamp = data['createdAt'] as Timestamp?;

        // ИЗМЕНЕНИЕ: Если статус требует действия, мы не должны его пропускать,
        // даже если заказ был создан до запуска приложения!
        if (change.type == DocumentChangeType.added && status != 'action_required') {
          if (timestamp != null) {
            DateTime orderTime = timestamp.toDate();
            if (_appStartTime != null && orderTime.isBefore(_appStartTime!)) {
              _globalProcessedOrders[orderId] = status;
              continue;
            }
          } else {
            continue;
          }
        }

        if (_globalProcessedOrders[orderId] == status) continue;

        if (change.type == DocumentChangeType.modified ||
            change.type == DocumentChangeType.added) {
          _globalProcessedOrders[orderId] = status;

          // Триггерим уведомление (можно оставить или убрать, если шторки достаточно)
          if (status != 'action_required') {
            _triggerNotification(status);
          }

          // Показ шторки замены
          if (status == 'action_required' && !_isDialogShowing) {
            _isDialogShowing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showReplacementBottomSheet(change.doc);
              }
            });
          }
        }
      }
    });
  }
  void _triggerNotification(String status) {
    final Map<String, List<String>> notifications = {
      'new': ["Заказ создан 📝", "Заказ успешно оформлен."],
      'accepted': ["Заказ принят ✅", "Мы начали работу над заказом."],
      'preparing': ["Готовим 🍳", "Повара приступили к работе."],
      'ready': ["Готов! 📦", "Еда упакована."],
      'delivery': ["В пути 🛵", "Курьер скоро будет!"],
      'inProgress': ["В пути 🛵", "Курьер скоро будет!"],
      'delivered': ["Доставлен ✨", "Приятного аппетита!"],
      'cancelled': ["Отменен ❌", "Заказ был отменен."],
      'action_required': ["Требуется действие ⚠️", "Заведение предлагает замену товара."],
    };

    if (notifications.containsKey(status)) {
      NotificationService.showNotification(
          notifications[status]![0], notifications[status]![1]);
    }
  }

  /// Карточка отображения конкретной замены без красного крестика (только фото)
  Widget _buildItemReplacementCard({
    required String oldName,
    required String newName,
    String? oldImage,
    String? newImage,
    num? oldPrice,
    num? newPrice,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Нет в наличии - выводим фото товара
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (oldImage != null && oldImage.isNotEmpty)
                    ? Image.network(
                  oldImage,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.fastfood, size: 24, color: Colors.grey),
                  ),
                )
                    : Container(
                  width: 44,
                  height: 44,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.fastfood, size: 24, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Закончился:',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    Text(
                      oldName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
              if (oldPrice != null)
                Text(
                  '${oldPrice.toInt()} ₽',
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_downward_rounded, color: Colors.deepOrange, size: 20),
                ),
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
          ),

          // Предлагаемая замена - выводим фото товара
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (newImage != null && newImage.isNotEmpty)
                    ? Image.network(
                  newImage,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: Colors.orange.shade50,
                    child: const Icon(Icons.fastfood, size: 24, color: Colors.deepOrange),
                  ),
                )
                    : Container(
                  width: 44,
                  height: 44,
                  color: Colors.orange.shade50,
                  child: const Icon(Icons.fastfood, size: 24, color: Colors.deepOrange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Предлагаем взамен:',
                      style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      newName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              if (newPrice != null)
                Text(
                  '${newPrice.toInt()} ₽',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Крупный выезжающий снизу блок предложения замены товара
  void _showReplacementBottomSheet(DocumentSnapshot orderDoc) {
    final data = orderDoc.data() as Map<String, dynamic>? ?? {};

    // Парсим данные замены из различных вариантов структуры в БД
    List<Map<String, dynamic>> replacementItems = [];

    if (data.containsKey('replacements') && data['replacements'] is List) {
      replacementItems = List<Map<String, dynamic>>.from(data['replacements']);
    } else if (data.containsKey('replacement') && data['replacement'] is Map) {
      replacementItems.add(Map<String, dynamic>.from(data['replacement']));
    } else {
      // Фолбэк парсинга
      replacementItems.add({
        'oldItemName': data['oldItemName'] ?? data['outOfStockItem'] ?? 'Товар',
        'newItemName': data['newItemName'] ?? data['replacementItem'] ?? 'Альтернативный товар',
        'oldItemImage': data['oldItemImage'] ?? data['oldImage'],
        'newItemImage': data['newItemImage'] ?? data['newImage'],
        'oldPrice': data['oldPrice'],
        'newPrice': data['newPrice'],
        'oldQuantity': data['oldQuantity'] ?? 1,
        'newQuantity': data['newQuantity'] ?? 1,
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.published_with_changes_rounded,
                      color: Colors.deepOrange,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Замена товара в заказе',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'К сожалению, некоторых позиций нет в наличии. Заведение предлагает следующую замену:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Выводим список заменяемых позиций
                  ...replacementItems.map((item) {
                    return _buildItemReplacementCard(
                      oldName: item['oldItemName'] ?? item['oldName'] ?? 'Товар',
                      newName: item['newItemName'] ?? item['newItemName'] ?? 'Замена',
                      oldImage: item['oldItemImage'] ?? item['oldImage'],
                      newImage: item['newItemImage'] ?? item['newImage'],
                      oldPrice: item['oldPrice'],
                      newPrice: item['newPrice'],
                    );
                  }),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await orderDoc.reference.update({
                              'status': 'cancelled',
                              'cancelReason': 'Отказ от замены',
                            });
                          },
                          child: const Text(
                            'Отменить заказ',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),



                          onPressed: () async {
                            Navigator.pop(sheetContext);

                            // 1. Берем текущие товары из заказа
                            List<Map<String, dynamic>> currentItems = List.from(
                              (data['items'] ?? []).map((item) => Map<String, dynamic>.from(item)),
                            );

                            // 2. Обрабатываем актуальную замену из списка
                            if (replacementItems.isNotEmpty) {
                              for (var replacement in replacementItems) {
                                // Собираем все возможные варианты названий старого товара для надежного удаления
                                final possibleOldNames = [
                                  replacement['oldItemName'],
                                  replacement['oldName'],
                                  replacement['old'],
                                ].where((n) => n != null).map((n) => n.toString().trim().toLowerCase()).toList();

                                // УДАЛЯЕМ ВСЕ совпадения со старым товаром из списка
                                if (possibleOldNames.isNotEmpty) {
                                  currentItems.removeWhere((item) {
                                    final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
                                    return possibleOldNames.contains(itemName);
                                  });
                                }

                                // Добавляем новый товар
                                final newName = (replacement['newItemName'] ?? replacement['newName'] ?? '').toString().trim();
                                final newPrice = replacement['newPrice'] ?? 0;
                                final newImage = replacement['newItemImage'] ?? replacement['newImage'] ?? '';
                                final newQtyToAdd = (replacement['newQuantity'] ?? 1) as int;

                                if (newName.isNotEmpty) {
                                  // Проверяем, есть ли уже такой новый товар в списке
                                  final existingIndex = currentItems.indexWhere((item) {
                                    final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
                                    return itemName == newName.toLowerCase();
                                  });

                                  if (existingIndex != -1) {
                                    // Если есть — просто увеличиваем количество, чтобы не плодить дубликаты
                                    int existingQty = (currentItems[existingIndex]['quantity'] ?? 1) as int;
                                    currentItems[existingIndex]['quantity'] = existingQty + newQtyToAdd;
                                  } else {
                                    // Если нет — добавляем ровно 1 раз
                                    currentItems.add({
                                      'name': newName,
                                      'price': newPrice,
                                      'quantity': newQtyToAdd,
                                      'imagePath': newImage,
                                    });
                                  }
                                }
                              }
                            }

                            // 3. Пересчитываем общую стоимость товаров
                            num newItemsPrice = 0;
                            for (var item in currentItems) {
                              final price = (item['price'] ?? 0) as num;
                              final qty = (item['quantity'] ?? 1) as int;
                              newItemsPrice += price * qty;
                            }

                            final deliveryPrice = (data['deliveryPrice'] ?? data['deliveryCost'] ?? 0) as num;
                            final newTotal = newItemsPrice + deliveryPrice;

                            // 4. Обновляем документ в Firestore
                            await orderDoc.reference.update({
                              'status': 'zamena',
                              'replacementAccepted': true,
                              'items': currentItems,
                              'itemsPrice': newItemsPrice,
                              'totalPrice': newItemsPrice,
                              'total': newTotal,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          },
                          child: const Text(
                            'Принять замену',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final NavigatorState? navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, const CategoriesPage()),
            _buildTabNavigator(
              1,
              ValueListenableBuilder<String?>(
                valueListenable: currentActiveShopId,
                builder: (context, activeShopId, _) {
                  return CartScreen(shopId: activeShopId);
                },
              ),
            ),
            _buildTabNavigator(2, _buildOrdersTab()),
            _buildTabNavigator(3, const ProfileScreen()),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: authState,
          builder: (context, isLoggedIn, _) {
            return _buildCustomFloatingNavBar(isLoggedIn);
          },
        ),
      ),
    );
  }

  Widget _buildCustomFloatingNavBar(bool isLoggedIn) {
    final items = [
      _NavBarItemData(activeIcon: Icons.home_rounded, inactiveIcon: Icons.home_outlined, label: 'Главная'),
      _NavBarItemData(activeIcon: Icons.shopping_bag_rounded, inactiveIcon: Icons.shopping_bag_outlined, label: 'Корзина'),
      _NavBarItemData(activeIcon: Icons.receipt_long_rounded, inactiveIcon: Icons.receipt_long_outlined, label: 'Заказы'),
      _NavBarItemData(activeIcon: Icons.person_rounded, inactiveIcon: Icons.person_outline_rounded, label: 'Профиль'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = _currentIndex == index;
            final item = items[index];

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (index == 2 && !isLoggedIn) {
                    _showAuthRequired(context);
                    return;
                  }
                  if (index == _currentIndex) {
                    _navigatorKeys[index]
                        .currentState
                        ?.popUntil((r) => r.isFirst);
                  } else {
                    setState(() => _currentIndex = index);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16 : 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isSelected ? item.activeIcon : item.inactiveIcon,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                          letterSpacing: -0.2,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _showAuthRequired(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF4F46E5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Требуется вход',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Чтобы отслеживать статус доставки и видеть историю заказов, войдите в свой профиль.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Позже',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 3);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Войти',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  _NavBarItemData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}