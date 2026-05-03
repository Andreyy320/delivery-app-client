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

  final List<GlobalKey<NavigatorState>> _navigatorKeys =
  List.generate(4, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now();
    _restoreAuth();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreAuth() async {
    final currentUser = await UserStorage.getCurrentUser();
    if (currentUser != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _startListeningToOrders(user.uid);
      }
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

        if (timestamp == null && change.type == DocumentChangeType.added) continue;
        DateTime orderTime = timestamp?.toDate() ?? DateTime(2020);

        if (_appStartTime != null && orderTime.isBefore(_appStartTime!)) {
          _globalProcessedOrders[orderId] = status;
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, const CategoriesPage()),
            // Вкладка корзины всё еще динамически подгружает нужный shopId
            _buildTabNavigator(1, ValueListenableBuilder<String?>(
              valueListenable: currentActiveShopId,
              builder: (context, activeShopId, _) {
                return CartScreen(shopId: activeShopId);
              },
            )),
            _buildTabNavigator(2, _buildOrdersTab()),
            _buildTabNavigator(3, const ProfileScreen()),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: authState,
          builder: (context, isLoggedIn, _) {
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.deepOrange,
              unselectedItemColor: Colors.grey,
              onTap: (index) {
                if (index == 2 && !isLoggedIn) {
                  _showAuthRequired(context);
                  return;
                }
                if (index == _currentIndex) {
                  _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
                } else {
                  setState(() => _currentIndex = index);
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Главная'),
                // Обычная иконка без красного круга и цифр
                BottomNavigationBarItem(icon: Icon(Icons.shopping_basket), label: 'Корзина'),
                BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Заказы'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Профиль'),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAuthRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_person_rounded, color: Colors.deepOrange, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Требуется вход', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Чтобы смотреть историю заказов и оформлять новые, нужно войти в аккаунт или зарегистрироваться.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 3);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Войти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
}
