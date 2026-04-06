import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../register_and_vhod/user_storage.dart';

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
      // проверка старого пароля
      final cred = EmailAuthProvider.credential(
        email: user.email!, // техническая почта из Firebase
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(cred);

      // меняем пароль
      await user.updatePassword(newPassword);

      setState(() => isLoading = false);

      _showMessage('Пароль изменён. Войдите заново.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showMessage('Ошибка: неверный старый пароль или проблема с сетью');
      setState(() => isLoading = false);
    }
  }



  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Изменить пароль'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Старый пароль',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Новый пароль',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _repeatPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Повторите новый пароль',
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
