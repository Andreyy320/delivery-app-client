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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? currentShopId;

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
    _restoreAuth();
  }

  Future<void> _restoreAuth() async {
    final currentUser = await UserStorage.getCurrentUser();
    if (currentUser != null) {
      debugPrint('🔹 Current logged in: ${currentUser['phone']}');

      // ПОЛУЧАЕМ ID И ЗАПУСКАЕМ СЛУШАТЕЛЯ
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _startListeningToOrders(user.uid); // <--- ВОТ ТУТ ЗАПУСК
      }

      authState.login();
      setState(() {});
    } else {
      debugPrint('🔹 No user logged in');
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
    // Путь через users -> UID -> orders
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .snapshots()
        .listen((snapshot) {

      print("🔔 База моргнула! В твоих заказах документов: ${snapshot.docs.length}");

      for (var change in snapshot.docChanges) {
        // Срабатывает и при создании (new), и при изменении (preparing, ready и т.д.)
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          // Берем статус как есть, чтобы регистр (большие/маленькие буквы) совпадал с твоим списком
          String status = (data['status'] ?? '').toString();

          print("🔍 Статус заказа ${change.doc.id} изменился на: $status");

          // Твои статусы один в один
          if (status == 'new') {
            NotificationService.showNotification("Заказ создан 📝", "Заказ успешно оформлен и ожидает подтверждения.");
          }
          else if (status == 'preparing') {
            NotificationService.showNotification("Ваш заказ готовится 🍳", "Повара приступили к приготовлению ваших блюд.");
          }
          else if (status == 'ready') {
            NotificationService.showNotification("Заказ готов! 📦", "Еда упакована и готова к передаче курьеру.");
          }
          else if (status == 'inProgress') {
            NotificationService.showNotification("Курьер едет к вам 🛵", "Заказ передан доставке, скоро будем у вас!");
          }
          else if (status == 'delivered') {
            NotificationService.showNotification("Заказ доставлен ✨", "Приятного аппетита! Ждем вас снова.");
          }
          else if (status == 'cancelled' || status == 'отменен') {
            NotificationService.showNotification("Заказ отменен ❌", "К сожалению, ваш заказ был отменен.");
          }
        }
      }
    }, onError: (error) => print("❌ Ошибка прослушки: $error"));
  }

  void _showAuthRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Требуется вход'),
        content: const Text(
            'Чтобы смотреть заказы и оформлять их, нужно войти или зарегистрироваться.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 3); // Профиль
            },
            child: const Text('Войти'),
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
