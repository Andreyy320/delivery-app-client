import 'package:flutter/material.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 30),
              const Text(
                "УПС... ИНТЕРНЕТ ПРОПАЛ",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 15),
              Text(
                "Для работы приложения и оформления заказов необходимо стабильное соединение с сетью.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}
