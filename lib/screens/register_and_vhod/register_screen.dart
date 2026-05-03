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

  // ОБНОВЛЕННАЯ логика валидации: телефон должен быть ровно 8 символов
  bool get _isFormValid =>
      _nameController.text.isNotEmpty &&
          _phoneController.text.length == 8 && // Строго 8 цифр
          _emailController.text.isNotEmpty &&
          _passwordController.text.length >= 6;

  // Логика регистрации
  void _register() async {
    if (!_isFormValid) {
      _error('Заполните все поля правильно. Номер телефона — 8 цифр.');
      return;
    }

    String phone = '+373${_phoneController.text.trim()}';
    String rawPassword = _passwordController.text.trim(); // Просто строка без хеша

    try {
      await UserStorage.register(
        name: _nameController.text.trim(),
        phone: phone,
        email: _emailController.text.trim(),
        password: rawPassword, // Передаем чистую строку
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Регистрация успешна 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      String errorMessage = 'Ошибка регистрации';

      // Проверка на существующий аккаунт
      if (e.toString().contains('email-already-in-use') || e.toString().contains('already exists')) {
        errorMessage = 'Аккаунт с таким Email уже существует !';
      } else {
        errorMessage = 'Ошибка: $e';
      }

      _error(errorMessage);
    }
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          'Новый аккаунт',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
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
                  'Регистрация ',
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
              'Создайте профиль, чтобы заказывать доставку и отслеживать курьеров',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 35),

            // ИМЯ
            _buildField(
              controller: _nameController,
              label: 'Ваше имя *',
              icon: Icons.person_rounded,
              hint: 'Иван Иванов',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // ТЕЛЕФОН
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
            const SizedBox(height: 20),

            // EMAIL
            _buildField(
              controller: _emailController,
              label: 'Электронная почта *',
              icon: Icons.email_rounded,
              hint: 'example@mail.com',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // ПАРОЛЬ
            _buildField(
              controller: _passwordController,
              label: 'Придумайте пароль *',
              icon: Icons.lock_rounded,
              hint: 'Минимум 6 символов',
              isPassword: true,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 48),

            // КНОПКА
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isFormValid
                    ? [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
                    : [],
              ),
              child: ElevatedButton(
                onPressed: _isFormValid ? _register : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  disabledForegroundColor: Colors.grey[500],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'ЗАРЕГИСТРИРОВАТЬСЯ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
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
            onChanged: onChanged,
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
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: 15, fontWeight: FontWeight.w400),
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