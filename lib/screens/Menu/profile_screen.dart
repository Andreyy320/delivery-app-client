import 'package:flutter/material.dart';
import '../../models/auth_state.dart';
import '../register_and_vhod/about_app_screen.dart';
import '../register_and_vhod/notification_settings_screen.dart';
import '../register_and_vhod/partnerstvo_screen.dart';
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
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => isLoading = true);
    final user = await UserStorage.getCurrentUser();
    if (mounted) {
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
        if (!isLoggedIn) return _buildAuthButtons();
        if (isLoading || currentUser == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)));
        }
        return _buildProfile();
      },
    );
  }

  Widget _buildAuthButtons() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(Icons.person_outline_rounded, size: 80, color: Colors.deepOrange),
              ),
              const SizedBox(height: 32),
              const Text(
                'Личный кабинет',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Войдите, чтобы отслеживать заказы и получать персональные скидки',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 50),
              _buildBigButton(
                label: 'ВОЙТИ',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ).then((_) => _loadUser()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                  ).then((_) => _loadUser()),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('СОЗДАТЬ АККАУНТ', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton({required String label, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildProfile() {
    final name = currentUser?['name'] ?? 'Гость';
    final phone = currentUser?['phone'] ?? 'Не указан';
    final email = currentUser?['email'] ?? 'Не указан';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.deepOrange.withOpacity(0.2), width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFFF8F9FB),
                      child: Icon(Icons.person_rounded, size: 55, color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(phone, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ЗАКАЗЫ'),
                  _buildMenuCard([
                    _menuItem(Icons.history_rounded, 'История заказов', () {
                      if (currentUser != null && currentUser!['uid'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(userId: currentUser!['uid'])));
                      }
                    }),
                    _menuItem(Icons.local_shipping_rounded, 'Текущий статус', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersStatusScreen()));
                    }),
                  ]),
                  const SizedBox(height: 25),
                  _buildSectionTitle('НАСТРОЙКИ'),
                  _buildMenuCard([
                    _menuItem(Icons.lock_person_rounded, 'Изменить пароль', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                    }),
                    _menuItem(Icons.storefront_rounded, 'Стать партнером', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessRegistrationScreen()));
                    }),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ВЫХОД
            TextButton.icon(
              onPressed: () async {
                await UserStorage.logout();
                authState.logout();
                setState(() => currentUser = null);
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              label: const Text('Выйти из аккаунта',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.deepOrange, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[300]),
      onTap: onTap,
    );
  }
}
