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

        if (timestamp != null) {
          DateTime orderTime = timestamp.toDate();
          if (_appStartTime != null && orderTime.isBefore(_appStartTime!)) {
            _globalProcessedOrders[orderId] = status;
            continue;
          }
        } else if (change.type == DocumentChangeType.added) {
          continue;
        }

        if (_globalProcessedOrders[orderId] == status) continue;

        if (change.type == DocumentChangeType.modified ||
            change.type == DocumentChangeType.added) {
          _globalProcessedOrders[orderId] = status;
          _triggerNotification(status);
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
    };

    if (notifications.containsKey(status)) {
      NotificationService.showNotification(
          notifications[status]![0], notifications[status]![1]);
    }
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
        extendBody: true, // Позволяет контенту заходить под парящий навигатор
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

  /// Премиальный парящий Bottom Navigation Bar
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
          // Глубокая объёмная тень
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

  /// Премиальный диалог авторизации
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
              // 3D иконка замочка
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF4F46E5),
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
              Text(
                'Чтобы отслеживать статус доставки и видеть историю заказов, войдите в свой профиль.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
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