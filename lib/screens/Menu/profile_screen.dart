import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Дизайн-система в едином стиле приложения (светлый фон + грифель + желтые акценты)
  static const Color _bgMain = Color(0xFFF4F5F7);
  static const Color _cardSurface = Colors.white;
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _accentYellow = Color(0xFFFCEE36);

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
        if (isLoading) {
          return const Scaffold(
            backgroundColor: _bgMain,
            body: Center(
              child: CircularProgressIndicator(
                color: _textMain,
                strokeWidth: 3,
              ),
            ),
          );
        }
        return _buildProfile();
      },
    );
  }

  Widget _buildAuthButtons() {
    return Scaffold(
      backgroundColor: _bgMain,
      body: SafeArea(
        child: Stack(
          children: [
            // Декоративные фоновые круги в стиле RestaurantsPage
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentYellow.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              top: 150,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _textMain.withValues(alpha: 0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _cardSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _textMain.withValues(alpha: 0.05),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 64,
                      color: _textMain,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Личный кабинет',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _textMain,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Войдите, чтобы управлять заказами и отслеживать доставку',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Кнопка ВОЙТИ
                  _buildBigButton(
                    label: 'ВОЙТИ',
                    isPrimary: true,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ).then((_) => _loadUser()),
                  ),
                  const SizedBox(height: 14),

                  // Кнопка СОЗДАТЬ АККАУНТ
                  _buildBigButton(
                    label: 'СОЗДАТЬ АККАУНТ',
                    isPrimary: false,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                    ).then((_) => _loadUser()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton({required String label, required bool isPrimary, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isPrimary ? _textMain : _cardSurface,
        border: isPrimary ? null : Border.all(color: _borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: _textMain.withValues(alpha: isPrimary ? 0.12 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : _textMain,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.5,
            color: isPrimary ? Colors.white : _textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    final name = currentUser?['name'] ?? 'Гость';
    final phone = currentUser?['phone'] ?? 'Не указан';

    return Scaffold(
      backgroundColor: _bgMain,
      body: SafeArea(
        child: Stack(
          children: [
            // Декоративные фоновые элементы
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
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ХЕДЕР ПРОФИЛЯ
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: _cardSurface,
                        boxShadow: [
                          BoxShadow(
                            color: _textMain.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _borderSubtle,
                                width: 2,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 38,
                              backgroundColor: Color(0xFFF1F5F9),
                              child: Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: _textMain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone_iphone_rounded,
                                  size: 13,
                                  color: _textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    color: _textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // СЕКЦИЯ: ЗАКАЗЫ
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'ЗАКАЗЫ',
                      style: TextStyle(
                        color: _textMuted.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildMenuCard([
                      _menuItem(Icons.history_rounded, 'История заказов', () {
                        if (currentUser != null && currentUser!['uid'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrdersScreen(userId: currentUser!['uid']),
                            ),
                          );
                        }
                      }),
                      _buildDivider(),
                      _menuItem(Icons.local_shipping_outlined, 'Текущий статус доставки', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrdersStatusScreen(),
                          ),
                        );
                      }),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // СЕКЦИЯ: НАСТРОЙКИ
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'НАСТРОЙКИ И СЕРВИС',
                      style: TextStyle(
                        color: _textMuted.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildMenuCard([
                      _menuItem(Icons.lock_outline_rounded, 'Изменить пароль', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      }),
                      _buildDivider(),
                      _menuItem(Icons.storefront_rounded, 'Стать партнером', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BusinessRegistrationScreen(),
                          ),
                        );
                      }),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // КНОПКА ВЫХОДА
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _cardSurface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await UserStorage.logout();
                            authState.logout();
                            setState(() => currentUser = null);
                          },
                          borderRadius: BorderRadius.circular(22),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 19,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Выйти из аккаунта',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _textMain.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _borderSubtle,
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: _textMain, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _borderSubtle,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Color(0xFFF1F5F9),
      ),
    );
  }
}