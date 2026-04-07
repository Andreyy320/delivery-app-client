import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/orders_data.dart';
import '../Menu/Cart_data.dart';
import '../../models/order_model.dart';

class CheckoutScreen extends StatefulWidget {
  final String shopId; // корзина привязана к магазину
  final Function(Order)? onOrderPlaced;
  final String restaurantName;

  const CheckoutScreen({super.key, required this.shopId, this.onOrderPlaced, required this.restaurantName,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  LatLng? _deliveryLocation;
  String _comment = '';
  String _selectedPayment = 'online';

  late final ValueNotifier<List<CartItem>> cartNotifier;
  String? userId; // 🔹 для привязки к пользователю

  final paymentOptions = [
    {'id': 'online', 'label': 'Оплатить \nонлайн', 'icon': Icons.payment},
    {'id': 'cash', 'label': 'Наличными', 'icon': Icons.money},
    {'id': 'card', 'label': 'Карта \nКлевер', 'icon': Icons.credit_card},
    {'id': 'qr', 'label': 'QR', 'icon': Icons.qr_code},
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      cartNotifier = getCart(userId!, widget.shopId); // 🔹 привязка корзины к пользователю
    } else {
      cartNotifier = ValueNotifier([]);
    }
  }

  double get total =>
      cartNotifier.value.fold(0, (sum, item) => sum + item.dish.price * item.quantity);

  Future<void> _pickDeliveryLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
    if (result != null) setState(() => _deliveryLocation = result);
  }

  Future<void> _saveOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    if (_deliveryLocation == null || cartNotifier.value.isEmpty) return;

    try {
      // 🔹 добавляем заказ через OrdersService
      await OrdersService.addOrder(
        userId!,
        cartNotifier.value,
        restaurantName: widget.restaurantName, // название ресторана
        shopId: widget.shopId,
        comment: _comment,
        paymentMethod: _selectedPayment,
      );

      clearCart(userId!, widget.shopId); // очищаем корзину

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении заказа: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа'), backgroundColor: Colors.deepOrange),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Доставка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDeliveryLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _deliveryLocation != null
                            ? 'Широта: ${_deliveryLocation!.latitude}, Долгота: ${_deliveryLocation!.longitude}'
                            : 'Выберите адрес доставки',
                        style: TextStyle(
                            color: _deliveryLocation != null ? Colors.black : Colors.grey[600]),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Комментарий к заказу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                  hintText: 'Комментарий к заказу', border: OutlineInputBorder()),
              maxLines: 2,
              onChanged: (value) => setState(() => _comment = value),
            ),
            const SizedBox(height: 16),
            const Text('Оплата', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: paymentOptions.map((option) {
                final selected = _selectedPayment == option['id'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2), // Уменьшили отступы между кнопками
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPayment = option['id'] as String),
                      child: Container(
                        height: 75, // Чуть уменьшили общую высоту
                        decoration: BoxDecoration(
                          color: selected ? Colors.deepOrange : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: selected ? Colors.deepOrange : Colors.grey[300]!,
                              width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              option['icon'] as IconData,
                              color: selected ? Colors.white : Colors.black54,
                              size: 22, // Уменьшили иконку с 28 до 22
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: FittedBox( // 👈 ГЛАВНОЕ: сжимает текст, если он не лезет
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  (option['label'] as String).replaceAll('\n', ' '), // Убираем принудительный перенос
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11, // Базовый шрифт чуть меньше
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('К оплате:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(0)} ₽',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveOrder,
                style: ElevatedButton.styleFrom(
                  // Используем глубокий зеленый цвет для "успешного" действия
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 4, // Добавили небольшую тень для объема
                  shadowColor: Colors.black.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 18), // Сделали кнопку чуть "толще"
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // Более мягкие углы
                  ),
                ),
                child: const Text(
                    'Оформить заказ',
                    style: TextStyle(
                      fontSize: 18, // Шрифт чуть крупнее
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1, // Небольшой межбуквенный интервал для стиля
                    )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Остальная часть (OrderConfirmationScreen и SelectLocationScreen) без изменений


/// Экран подтверждения заказа
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Получаем ширину экрана, чтобы делать элементы пропорциональными
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white, // Чистый белый фон выглядит лучше
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Отступы от краев экрана
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Центрируем всё по вертикали
            children: [
              // 1. КАРТИНКА (теперь она видна!)
              // flexible позволяет картинке сжиматься на маленьких экранах
              Flexible(
                flex: 3,
                child: Image.asset(
                  'assets/images/zakaz_oformlen.jpg',
                  width: screenWidth * 0.5, // 50% от ширины экрана
                  // height: 150, // Высота теперь пропорциональна, убрал жесткие 26
                  fit: BoxFit.contain, // Сохраняет пропорции картинки
                ),
              ),
              const SizedBox(height: 32),

              // 2. ЗАГОЛОВОК
              const Text(
                'Заказ оформлен!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30, // Шрифт крупнее для Samsung A04
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),

              // 3. ОПИСАНИЕ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Спасибо за ваш заказ.\nКурьер скоро доставит его по адресу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17, // Более читабельный размер
                    color: Colors.grey[700],
                    height: 1.4, // Межстрочный интервал для легкого чтения
                  ),
                ),
              ),

              // 4. ПРОСТРАНСТВО ДО КНОПКИ
              const Spacer(flex: 2), // Толкает кнопку вниз, оставляя место сверху

              // 5. КНОПКА (теперь большая и красивая)
              Container(
                width: double.infinity, // На всю ширину
                height: 60, // Фиксированная удобная высота
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Красивое оранжевое "свечение"
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  // Закрываем все до главного экрана
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    elevation: 0, // Тень мы уже сделали через Container
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ВЕРНУТЬСЯ В МЕНЮ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Отступ от самого низа экрана
            ],
          ),
        ),
      ),
    );
  }
}

/// Выбор локации на карте
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  LatLng? selectedLatLng;
  final MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите адрес', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.black), // Стрелочка назад тоже белая
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
              initialZoom: 16,
              onTap: (tapPos, latLng) => setState(() => selectedLatLng = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50,
                        // Тень для маркера, чтобы он не терялся
                        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // КНОПКА ТУТ
          if (selectedLatLng != null)
            Positioned(
              bottom: 30, // Чуть выше, чтобы не мешала системная полоса снизу
              left: 20,
              right: 20,
              child: SizedBox(
                height: 60, // Делаем кнопку высокой и удобной
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange, // Твой оранжевый цвет
                    foregroundColor: Colors.white,  // БЕЛЫЙ ЦВЕТ ТЕКСТА (теперь нормальный)
                    elevation: 8,                  // Тень кнопки
                    shadowColor: Colors.orange.withOpacity(0.5), // Оранжевое свечение тени
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // Скругленные углы
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, selectedLatLng),
                  child: const Text(
                    'ПОДТВЕРДИТЬ АДРЕС',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold, // Жирный шрифт
                      letterSpacing: 1.2,          // Красивое расстояние между буквами
                    ),
                  ),
                ),
              ),
            ),

          // Подсказка, если еще ничего не выбрали
          if (selectedLatLng == null)
            Positioned(
              top: 20,
              left: 60,
              right: 60,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Нажмите на карту',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
        ],
      ),
    );
  }
}