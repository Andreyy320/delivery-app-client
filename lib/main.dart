import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:untitled1/screens/register_and_vhod/notification_service.dart';
import 'package:untitled1/shops/offline_screen.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart'; // Добавлено для работы проверки интернета

void main() async {

  // 🔹 ДОБАВЬ ЭТУ СТРОЧКУ ПЕРВОЙ
  HttpOverrides.global = MyHttpOverrides();

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ДОБАВЬ ЭТИ СТРОКИ:
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('Статус разрешения: ${settings.authorizationStatus}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 🛠️ ТЕСТОВЫЙ ТУМБЛЕР ДЛЯ ЭМУЛЯТОРА:
  // Поставь true — чтобы ПРИНУДИТЕЛЬНО увидеть экран "Нет интернета"
  // Поставь false — для обычной работы приложения (реальный режим сети)
  static const bool testOfflineMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery App',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true, // Для более современного вида (по желанию)
      ),
      // Исправленный глобальный перехватчик сети поверх любого экрана приложения
      builder: (context, child) {
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, snapshot) {
            // ДИАГНОСТИЧЕСКИЙ ПРИНТ: покажет статус сети в консоли Android Studio
            print("=== СТАТУС СЕТИ В ПРИЛОЖЕНИИ: ${snapshot.data} ===");

            // 1. Если стрим только запускается и ещё не получил данные от системы
            if (snapshot.connectionState == ConnectionState.waiting) {
              return child ?? const SizedBox.shrink(); // Просто показываем контент, не блокируя
            }

            // Проверяем, включен ли искусственный офлайн для тестов на эмуляторе
            final connectivity = testOfflineMode
                ? <ConnectivityResult>[ConnectivityResult.none]
                : snapshot.data;

            // 2. Если данные пришли, но список пуст или содержит статус отсутствия сети (.none)
            if (connectivity == null ||
                connectivity.isEmpty ||
                connectivity.contains(ConnectivityResult.none)) {
              return const OfflineScreen();
            }

            // 3. Если интернет активен (Wi-Fi, мобильные данные или другие типы подключения)
            return child!;
          },
        );
      },
      home: const MainScreen(),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}