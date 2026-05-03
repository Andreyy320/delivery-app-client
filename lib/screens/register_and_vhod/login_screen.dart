import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_storage.dart';
import '../../models/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Логика входа с проверкой на 8 цифр
  void _login() async {
    // Если введено меньше или больше 8 цифр — выдаем ошибку
    if (_phoneController.text.length != 8) {
      _error('Номер телефона должен содержать ровно 8 цифр');
      return;
    }

    String phone = '+373${_phoneController.text.trim()}';

    try {
      await UserStorage.login(
        phone: phone,
        password: _passwordController.text.trim(),
      );

      authState.login(); // уведомляем приложение
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _error('Неверный номер или пароль');
    }
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Авторизация',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            const SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'С возвращением! ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Введите данные, чтобы продолжить работу с заказами',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),

            // ТЕЛЕФОН (Теперь строго 8 цифр)
            _buildField(
              controller: _phoneController,
              label: 'Номер телефона',
              icon: Icons.phone_android_rounded,
              prefixText: '+373 ',
              keyboardType: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8), // ОГРАНИЧЕНИЕ 8 ЦИФР
              ],
            ),
            const SizedBox(height: 20),

            // ПАРОЛЬ
            _buildField(
              controller: _passwordController,
              label: 'Пароль',
              icon: Icons.lock_open_rounded,
              isPassword: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),

            const SizedBox(height: 48),

            // КНОПКА ВОЙТИ
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
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
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'ВОЙТИ В АККАУНТ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.deepOrange, size: 22),
              prefixIconConstraints: const BoxConstraints(minWidth: 50),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              suffixIcon: suffixIcon,
              hintText: isPassword ? '••••••••' : '77x xxxxx',
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}