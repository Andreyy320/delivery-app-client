import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled1/shops/offline_screen.dart';
import 'screens/main_screen.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui'; // Требуется для доступа к PlatformDispatcher

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  // Инициализация Firebase полностью удалена, так как переходим на собственный Node.js / PostgreSQL бэкенд

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const bool testOfflineMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery App',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      builder: (context, child) {
        // Получаем текущие данные MediaQuery телефона
        final mediaQueryData = MediaQuery.of(context);

        // Обертка для проверки интернета (вся ваша логика сохранена)
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildAppWithScaledText(mediaQueryData, child ?? const SizedBox.shrink());
            }

            final connectivity = testOfflineMode
                ? <ConnectivityResult>[ConnectivityResult.none]
                : snapshot.data;

            if (connectivity == null ||
                connectivity.isEmpty ||
                connectivity.contains(ConnectivityResult.none)) {
              return _buildAppWithScaledText(mediaQueryData, const OfflineScreen());
            }

            return _buildAppWithScaledText(mediaQueryData, child!);
          },
        );
      },
      home: const MainScreen(),
    );
  }

  // Железобетонная изоляция: полностью блокируем системное изменение размера дисплея и шрифта
  Widget _buildAppWithScaledText(MediaQueryData mediaQueryData, Widget widget) {
    // Получаем реальную физическую плотность экрана устройства напрямую из системы,
    // игнорируя изменения ползунка Display Size в настройках ОС.
    final view = PlatformDispatcher.instance.views.first;

    // Безопасная фиксация: вычисляем стабильный коэффициент для экрана
    const double designWidth = 410.0;
    final double lockedPixelRatio = view.physicalSize.width / designWidth;

    return MediaQuery(
      data: mediaQueryData.copyWith(
        // Жестко фиксируем масштаб шрифта на 1.0 (ползунок Font Size больше не влияет)
        textScaler: const TextScaler.linear(1.0),

        // Жестко фиксируем плотность пикселей на основе физического разрешения устройства,
        // полностью отрезая влияние системного ползунка "Display Size".
        devicePixelRatio: lockedPixelRatio.clamp(2.0, 4.0),
      ),
      child: widget,
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