import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  bool isLoading = false;

  // Твоя логика без изменений
  Future<void> _changePassword() async {
    setState(() => isLoading = true);

    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final repeatPassword = _repeatPasswordController.text.trim();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Пользователь не найден');
      setState(() => isLoading = false);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Минимум 6 символов');
      setState(() => isLoading = false);
      return;
    }

    if (newPassword != repeatPassword) {
      _showMessage('Пароли не совпадают');
      setState(() => isLoading = false);
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      setState(() => isLoading = false);

      _showMessage('Пароль успешно изменён');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showMessage('Ошибка: неверный старый пароль');
      setState(() => isLoading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: text.contains('Ошибка') ? Colors.redAccent : Colors.green,
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
          'Безопасность',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Обновление пароля ',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Для смены пароля введите ваш текущий пароль и придумайте новый.',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 40),

            // СТАРЫЙ ПАРОЛЬ
            _buildField(
              controller: _oldPasswordController,
              label: 'Старый пароль',
              icon: Icons.lock_open_rounded,
            ),
            const SizedBox(height: 20),

            // НОВЫЙ ПАРОЛЬ
            _buildField(
              controller: _newPasswordController,
              label: 'Новый пароль',
              icon: Icons.lock_outline_rounded,
              hint: 'Минимум 6 символов',
            ),
            const SizedBox(height: 20),

            // ПОВТОР ПАРОЛЯ
            _buildField(
              controller: _repeatPasswordController,
              label: 'Подтвердите пароль',
              icon: Icons.verified_user_outlined,
              hint: 'Повторите новый пароль еще раз',
            ),

            const SizedBox(height: 48),

            // КНОПКА СОХРАНИТЬ
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!isLoading)
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Text(
                  'СОХРАНИТЬ ПАРОЛЬ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5),
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
            obscureText: true,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.deepOrange, size: 22),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: 15, fontWeight: FontWeight.w400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}