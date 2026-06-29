import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:untitled1/screens/register_and_vhod/notification_service.dart';
import 'package:untitled1/shops/offline_screen.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint('FIREBASE INIT ERROR: $e');
  }

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
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return child ?? const SizedBox.shrink();
            }

            final connectivity = testOfflineMode
                ? <ConnectivityResult>[ConnectivityResult.none]
                : snapshot.data;

            if (connectivity == null ||
                connectivity.isEmpty ||
                connectivity.contains(ConnectivityResult.none)) {
              return const OfflineScreen();
            }

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