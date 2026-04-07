import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_storage.dart';
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

  // Твоя логика валидации без изменений
  bool get _isFormValid =>
      _nameController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _passwordController.text.length >= 6;

  // Твоя функция регистрации без изменений
  void _register() async {
    if (!_isFormValid) {
      _error('Заполните все обязательные поля и пароль минимум 6 символов');
      return;
    }

    String phone = '+373${_phoneController.text.trim()}';

    try {
      await UserStorage.register(
        name: _nameController.text.trim(),
        phone: phone,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Регистрация успешна 🎉')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      _error('Ошибка регистрации: $e');
    }
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Создание аккаунта',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Регистрация',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Заполните данные для начала работы',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 35),

            // ИМЯ
            _buildField(
              controller: _nameController,
              label: 'Имя *',
              icon: Icons.person_outline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            // ТЕЛЕФОН
            _buildField(
              controller: _phoneController,
              label: 'Телефон *',
              icon: Icons.phone_android,
              prefixText: '+373 ',
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            // EMAIL
            _buildField(
              controller: _emailController,
              label: 'Email (обязательно)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            // ПАРОЛЬ
            _buildField(
              controller: _passwordController,
              label: 'Пароль * (мин. 6 симв.)',
              icon: Icons.lock_outline,
              isPassword: true,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 40),

            // КНОПКА (с твоим условием _isFormValid)
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isFormValid
                    ? [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
                    : [],
              ),
              child: ElevatedButton(
                onPressed: _isFormValid ? _register : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'ЗАРЕГИСТРИРОВАТЬСЯ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод для красивых полей
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? prefixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.deepOrange, size: 22),
          prefixText: prefixText,
          prefixStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}