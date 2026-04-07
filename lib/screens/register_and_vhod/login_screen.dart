import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_storage.dart';
import '../../models/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Логика без изменений
  void _login() async {
    String phone = '+373${_phoneController.text.trim()}';

    try {
      await UserStorage.login(
        phone: phone,
        password: _passwordController.text.trim(),
      );

      authState.login(); // уведомляем приложение
      Navigator.pop(context);
    } catch (e) {
      _error('Неверный номер или пароль');
    }
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Чистый фон
      appBar: AppBar(
        title: const Text(
          'Вход',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'С возвращением!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Введите данные для входа в систему',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 40),

            // ТЕЛЕФОН
            _buildField(
              controller: _phoneController,
              label: 'Телефон',
              icon: Icons.phone_android,
              prefixText: '+373 ',
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),

            // ПАРОЛЬ
            _buildField(
              controller: _passwordController,
              label: 'Пароль',
              icon: Icons.lock_outline,
              isPassword: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),

            const SizedBox(height: 40),

            // КНОПКА ВОЙТИ
            Container(
              width: double.infinity,
              height: 60, // Увеличенная высота для удобства на Samsung A04
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'ВОЙТИ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Общий метод для дизайна полей
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? prefixText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50], // Мягкий фон поля
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.deepOrange, size: 22),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none, // Убираем стандартную обводку
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}