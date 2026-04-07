import 'package:flutter/material.dart';
import '../../models/auth_state.dart';
import '../register_and_vhod/about_app_screen.dart';
import '../register_and_vhod/notification_settings_screen.dart';
import '../register_and_vhod/user_storage.dart';
import '../register_and_vhod/login_screen.dart';
import '../register_and_vhod/register_screen.dart';
import 'order_status.dart';
import 'orders_screen.dart';
import '../register_and_vhod/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser(); // загружаем пользователя при старте
  }

  Future<void> _loadUser() async {
    setState(() {
      isLoading = true;
    });

    final user = await UserStorage.getCurrentUser();
    debugPrint('🔹 Loaded User: $user');

    if (mounted) { // важно проверить, что виджет ещё жив
      setState(() {
        currentUser = user;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: authState,
      builder: (context, isLoggedIn, _) {
        if (!isLoggedIn) {
          return _buildAuthButtons();
        }

        // Если данные ещё не загружены — показываем индикатор
        if (isLoading || currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildProfile();
      },
    );
  }

  Widget _buildAuthButtons() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // 🎯 ДОБАВЛЕНО: Центрирует все элементы внутри колонки по горизонтали
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Логотип или иконка приложения
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_shipping, size: 80, color: Colors.deepOrange),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Добро пожаловать!',
                  textAlign: TextAlign.center, // Явно центрируем текст внутри виджета
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Войдите, чтобы управлять заказами',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center, // Текст подзаголовка тоже по центру
                ),
                const SizedBox(height: 48),

                // Кнопка ВОЙТИ
                _buildBigButton(
                  label: 'ВОЙТИ',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ).then((_) => _loadUser()),
                ),

                const SizedBox(height: 16),

                // Кнопка РЕГИСТРАЦИЯ
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                    ).then((_) => _loadUser()),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.deepOrange, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'СОЗДАТЬ АККАУНТ',
                      style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Вынес нашу фирменную кнопку в отдельный метод, чтобы не дублировать код
  Widget _buildBigButton({required String label, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 60,
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }
  Widget _buildProfile() {
    final name = currentUser?['name'] ?? 'Гость';
    final phone = currentUser?['phone'] ?? 'Не указан';
    final email = currentUser?['email'] ?? 'Не указан';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ВЕРХНЯЯ КАРТОЧКА (ШАПКА)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepOrange, Colors.orangeAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // --- ИСПРАВЛЕННЫЙ БЛОК КОНТАКТОВ ---
                  Column(
                    children: [
                      // Строка с телефоном
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8), // Отступ между телефоном и почтой
                      // Строка с почтой
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.email, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              email,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              overflow: TextOverflow.ellipsis, // Защита от очень длинных почт
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // ----------------------------------
                ],
              ),
            ),

            const SizedBox(height: 24),

            // МЕНЮ НАСТРОЕК
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('  Личные данные', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildMenuCard([
                    _menuItem(Icons.receipt_long, 'История заказов', () {
                      if (currentUser != null && currentUser!['uid'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(userId: currentUser!['uid'])));
                      }
                    }),
                    _menuItem(Icons.local_shipping, 'Мои заказы', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersStatusScreen()));
                    }),
                  ]),

                  const SizedBox(height: 24),
                  const Text('  Безопасность и связь', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildMenuCard([
                    _menuItem(Icons.lock_outline, 'Изменить пароль', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                    }),
                    _menuItem(Icons.notifications_none, 'Настройки уведомлений', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                    }),
                    _menuItem(Icons.info_outline, 'О приложении', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen()));
                    }),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // КНОПКА ВЫХОДА
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton.icon(
                onPressed: () async {
                  await UserStorage.logout();
                  authState.logout();
                  setState(() => currentUser = null);
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

// Вспомогательные виджеты для профиля
  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepOrange),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}