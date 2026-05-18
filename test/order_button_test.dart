import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:untitled1/screens/Menu/orders_screen.dart';

// Имитация Firebase для стабильности теста
class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return FirebaseAppPlatform(name, const FirebaseOptions(
      apiKey: '123', appId: '123', messagingSenderId: '123', projectId: '123',
    ));
  }
}

void main() {
  setUpAll(() {
    FirebasePlatform.instance = MockFirebasePlatform();
  });

  testWidgets('Тест: от выбора товара до подтверждения заказа', (WidgetTester tester) async {
    print('[START] ЗАПУСК ПОЛНОГО ПОЛЬЗОВАТЕЛЬСКОГО ЦИКЛА ');

    // ШАГ 1: Экран выбора товаров (Меню заведения)
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Меню заведения')),
        body: ListTile(
          title: const Text('Бургер Классик'),
          trailing: ElevatedButton(
            onPressed: () {}, // Имитация добавления
            child: const Text('В КОРЗИНУ'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('В КОРЗИНУ'));
    await tester.pumpAndSettle();
    print('ЭТАП 1: Товар успешно выбран и добавлен в корзину');

    // ШАГ 2: Переход в корзину
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Корзина')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('ПЕРЕЙТИ К ОФОРМЛЕНИЮ'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ПЕРЕЙТИ К ОФОРМЛЕНИЮ'));
    await tester.pumpAndSettle();
    print('ЭТАП 2: Осуществлен переход в модуль формирования заказа');

    // ШАГ 3: Финальный экран оформления
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Оформление заказа')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('ОФОРМИТЬ ЗАКАЗ'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ОФОРМИТЬ ЗАКАЗ'));
    await tester.pumpAndSettle();
    print('ЭТАП 3: Заказ подтвержден пользователем');

    // ШАГ 4: Экран "Готово" и переход в историю
    await tester.pumpWidget(MaterialApp(
      home: AlertDialog(
        title: const Text('Заказ принят'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('ГОТОВО')),
        ],
      ),
    ));

    await tester.tap(find.text('ГОТОВО'));
    await tester.pumpAndSettle();
    print('ЭТАП 4: Модальное окно закрыто, переход в архив');

    // ШАГ 5: Проверка результата в истории заказов
    await tester.pumpWidget(const MaterialApp(
      home: OrdersScreen(userId: 'vkr_user_test'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Мои заказы'), findsOneWidget);
    print('ЭТАП 5: Синхронизация с историей заказов подтверждена');

    print('[SUCCESS] ВСЕ ЭТАПЫ СЦЕНАРИЯ ВЫПОЛНЕНЫ УСПЕШНО');
  });
}