import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled1/screens/Menu/cart_screen.dart';
import 'package:untitled1/screens/Menu/orders_screen.dart';
import 'package:untitled1/screens/Menu/profile_screen.dart';
import 'package:untitled1/screens/categories_page.dart';
import 'package:untitled1/models/dish_model.dart';
import 'package:untitled1/screens/Menu/Cart_data.dart';
import 'package:untitled1/screens/register_and_vhod/notification_service.dart';
import 'package:untitled1/screens/register_and_vhod/user_storage.dart';
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
  String? currentShopId;
  DateTime? _appStartTime; // Время запуска

  final List<GlobalKey<NavigatorState>> _navigatorKeys =
  List.generate(4, (_) => GlobalKey<NavigatorState>());

  void addDishToCart(Dish dish, String shopId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    addToCartItem(user.uid, shopId, dish);
    currentShopId = shopId; // сохраняем текущий магазин
    setState(() {});
  }

  Future<bool> _onWillPop() async {
    final isFirstRouteInCurrentTab =
    !await _navigatorKeys[_currentIndex].currentState!.maybePop();
    return isFirstRouteInCurrentTab;
  }

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now();
    _restoreAuth();
  }
  @override
  void dispose() {
    // Закрываем поток при уничтожении экрана
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreAuth() async {
    final currentUser = await UserStorage.getCurrentUser();
    if (currentUser != null) {
      debugPrint('🔹 Current logged in: ${currentUser['phone']}');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _startListeningToOrders(user.uid);
      }
      authState.login();
      setState(() {});
    }
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

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }

  void _startListeningToOrders(String userId) {
    // 1. Отменяем предыдущую подписку, если она была
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

        // Получаем время создания заказа
        Timestamp? timestamp = data['createdAt'] as Timestamp?;

        // Если времени еще нет (сервер не успел записать), пропускаем этот миг
        if (timestamp == null && change.type == DocumentChangeType.added) continue;

        DateTime orderTime = timestamp?.toDate() ?? DateTime(2020);

        // 2. ПРОВЕРКА: Пропускаем всё, что создано ДО запуска приложения
        if (_appStartTime != null && orderTime.isBefore(_appStartTime!)) {
          _globalProcessedOrders[orderId] = status; // Запоминаем текущий статус молча
          continue;
        }

        // 3. ЗАЩИТА ОТ ДУБЛЕЙ: Если этот статус уже пушили для этого заказа — игнорим
        if (_globalProcessedOrders[orderId] == status) {
          continue;
        }

        // 4. Если тип изменения подходит (добавлен или изменен)
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {

          // Запоминаем статус ПЕРЕД показом, чтобы не дублировать
          _globalProcessedOrders[orderId] = status;

          debugPrint("🔔 Отправка уведомления для заказа $orderId: $status");
          _triggerNotification(status);
        }
      }
    }, onError: (error) => debugPrint("❌ Ошибка прослушки: $error"));
  }

  // Вынес тексты уведомлений сюда для удобства
  void _triggerNotification(String status) {
    if (status == 'new') {
      NotificationService.showNotification("Заказ создан 📝", "Заказ успешно оформлен и ожидает подтверждения.");
    } else if (status == 'accepted') {
      NotificationService.showNotification("Заказ принят ✅", "Мы начали работу над заказом.");
    } else if (status == 'preparing') {
      NotificationService.showNotification("Ваш заказ готовится 🍳", "Повара приступили к приготовлению блюд.");
    } else if (status == 'ready') {
      NotificationService.showNotification("Заказ готов! 📦", "Еда упакована и готова к передаче.");
    } else if (status == 'delivery' || status == 'inProgress') {
      NotificationService.showNotification("Курьер в пути 🛵", "Заказ передан доставке, скоро будем!");
    } else if (status == 'delivered') {
      NotificationService.showNotification("Заказ доставлен ✨", "Приятного аппетита! Ждем вас снова.");
    } else if (status == 'cancelled' || status == 'отменен') {
      NotificationService.showNotification("Заказ отменен ❌", "К сожалению, ваш заказ был отменен.");
    }
  }

  void _showAuthRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            // Красивая иконка сверху
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                color: Colors.deepOrange,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Требуется вход',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Отмена', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 3); // Переход в профиль
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Войти',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, CategoriesPage(addToCart: addDishToCart)),
            // 🔹 Нижняя панель корзины показывает ВСЕ магазины
            _buildTabNavigator(1, CartScreen(shopId: null)), // 🔹 null = объединённая корзина всех магазинов
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
              selectedItemColor: Colors.orange,
              onTap: (index) {
                if (index == 2 && !isLoggedIn) {
                  _showAuthRequired(context);
                  return;
                }
                if (index == _currentIndex) {
                  _navigatorKeys[index]
                      .currentState
                      ?.popUntil((route) => route.isFirst);
                } else {
                  setState(() => _currentIndex = index);
                }
              },
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home), label: 'Главная'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_cart), label: 'Корзина'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long), label: 'Заказы'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
              ],
            );
          },
        ),
      ),
    );
  }
}
