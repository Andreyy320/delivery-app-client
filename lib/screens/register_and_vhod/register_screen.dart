import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Единая дизайн-система приложения
  static const Color _bgMain = Color(0xFFF4F5F7);
  static const Color _cardSurface = Colors.white;
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _accentYellow = Color(0xFFFCEE36);

  // Валидация: телефон должен быть ровно 8 символов
  bool get _isFormValid =>
      _nameController.text.isNotEmpty &&
          _phoneController.text.length == 8 &&
          _emailController.text.isNotEmpty &&
          _passwordController.text.length >= 6;

  // Логика регистрации через твой сервер с подробными логами
  void _register() async {
    if (!_isFormValid) {
      _error('Заполните все поля правильно. Номер телефона — 8 цифр.');
      return;
    }

    String phone = '+373${_phoneController.text.trim()}';
    String rawPassword = _passwordController.text.trim();

    final requestBody = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': phone,
      'password': rawPassword,
      'role': 'client',
    };

    // ЛОГ 1: Что отправляем
    print('=== [REGISTRATION] Отправка запроса на сервер ===');
    print('URL: http://10.0.2.2:3000/api/register');
    print('Body: ${jsonEncode(requestBody)}');

    try {
      const String url = 'http://10.0.2.2:3000/api/register';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // ЛОГ 2: Что ответил сервер
      print('=== [REGISTRATION] Ответ от сервера ===');
      print('StatusCode: ${response.statusCode}');
      print('ResponseBo: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text('Регистрация успешна 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        _error(data['error'] ?? 'Ошибка при регистрации на сервере');
      }
    } catch (e) {
      // ЛОГ 3: Ошибка сети / подключения
      print('=== [REGISTRATION] Ошибка исключения ===');
      print('$e');
      _error('Нет связи с сервером. Проверьте запущен ли node index.js');
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
          'Новый аккаунт',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Регистрация',
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
                    'Создайте профиль, чтобы заказывать доставку и отслеживать курьеров',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

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
                        _buildField(
                          controller: _nameController,
                          label: 'Ваше имя *',
                          icon: Icons.person_outline_rounded,
                          hint: 'Иван Иванов',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        _buildField(
                          controller: _phoneController,
                          label: 'Контактный телефон *',
                          icon: Icons.phone_android_rounded,
                          prefixText: '+373 ',
                          hint: '77712345',
                          keyboardType: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        _buildField(
                          controller: _emailController,
                          label: 'Электронная почта *',
                          icon: Icons.email_outlined,
                          hint: 'example@mail.com',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        _buildField(
                          controller: _passwordController,
                          label: 'Придумайте пароль *',
                          icon: Icons.lock_outline_rounded,
                          hint: 'Минимум 6 символов',
                          isPassword: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _isFormValid ? _textMain : _cardSurface,
                      border: _isFormValid ? null : Border.all(color: _borderSubtle, width: 1),
                      boxShadow: _isFormValid
                          ? [
                        BoxShadow(
                          color: _textMain.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: _isFormValid ? _register : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: _isFormValid ? Colors.white : _textMuted,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'ЗАРЕГИСТРИРОВАТЬСЯ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: _isFormValid ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
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
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    void Function(String)? onChanged,
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
            onChanged: onChanged,
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
              hintText: hint,
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