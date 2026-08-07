import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  // Единая дизайн-система приложения
  static const Color _bgMain = Color(0xFFF4F5F7);
  static const Color _cardSurface = Colors.white;
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _accentYellow = Color(0xFFFCEE36);

  // Логика входа через твой сервер Node.js (PostgreSQL)
  void _login() async {
    if (_phoneController.text.length != 8) {
      _error('Номер телефона должен содержать ровно 8 цифр');
      return;
    }

    String phone = '+373${_phoneController.text.trim()}';
    String password = _passwordController.text.trim();

    final requestBody = {
      'phone': phone,
      'password': password,
    };

    print('=== [LOGIN] Отправка запроса ===');
    print('URL: http://10.0.2.2:3000/api/login');
    print('Body: ${jsonEncode(requestBody)}');

    try {
      const String url = 'http://10.0.2.2:3000/api/login';

      final response = await http.post(
        Uri.parse(url,
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('=== [LOGIN] Ответ от сервера ===');
      print('StatusCode: ${response.statusCode}');
      print('ResponseBody: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        authState.login(); // уведомляем приложение об успешном входе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text('Вход выполнен успешно 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _error(data['error'] ?? 'Неверный номер или пароль');
      }
    } catch (e) {
      print('=== [LOGIN] Ошибка сети ===');
      print('$e');
      _error('Нет связи с сервером. Проверьте node index.js');
    }
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgMain,
      appBar: AppBar(
        backgroundColor: _bgMain,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: _cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderSubtle, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Авторизация',
          style: TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Декоративные фоновые элементы в стиле приложения
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentYellow.withValues(alpha: 0.15),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),

                  const SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'С возвращением!',
                        style: TextStyle(
                          color: _textMain,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    'Введите данные, чтобы продолжить работу с заказами',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ФОРМА В ОБЩЕМ БЕЛОМ КОНТЕЙНЕРЕ КАРТОЧКИ
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _cardSurface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _borderSubtle, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: _textMain.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ТЕЛЕФОН (Строго 8 цифр)
                        _buildField(
                          controller: _phoneController,
                          label: 'Номер телефона',
                          icon: Icons.phone_android_rounded,
                          prefixText: '+373 ',
                          keyboardType: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ПАРОЛЬ
                        _buildField(
                          controller: _passwordController,
                          label: 'Пароль',
                          icon: Icons.lock_outline_rounded,
                          isPassword: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: _textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // КНОПКА ВОЙТИ В СТИЛЕ ПРИЛОЖЕНИЯ
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _textMain,
                      boxShadow: [
                        BoxShadow(
                          color: _textMain.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'ВОЙТИ В АККАУНТ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderSubtle, width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _textMain,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _textMain, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              suffixIcon: suffixIcon,
              hintText: isPassword ? '••••••••' : '77x xxxxx',
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}