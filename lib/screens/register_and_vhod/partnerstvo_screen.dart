import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

import 'business_orders_screen.dart';
import 'business_stop_list_screen.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() => _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState extends State<BusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final String _imgBBKey = "19b9ece492b6e9cf40bd22859665516b";

  final _nameController = TextEditingController();
  final _addressController = TextEditingController(); // Скрытое поле, куда сохраняется адрес с карты
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _timeController = TextEditingController();

  double? _lat;
  double? _lng;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final Map<String, String> _categoryKeys = {
    'Еда': 'restaurant',
    'Продукты': 'product',
    'Аптека': 'apteka',
    'Цветы': 'svetok',
    'Электроника': 'electronika',
    'Одежда': 'odejda',
    'Строймагазин': 'stroimaterial'
  };

  final Map<String, IconData> _categoryIcons = {
    'Еда': Icons.restaurant_rounded,
    'Продукты': Icons.shopping_bag_rounded,
    'Аптека': Icons.medical_services_rounded,
    'Цветы': Icons.local_florist_rounded,
    'Электроника': Icons.devices_other_rounded,
    'Одежда': Icons.checkroom_rounded,
    'Строймагазин': Icons.home_repair_service_rounded
  };

  String _selectedCategoryName = 'Еда';
  bool isLoading = false;

  Future<void> _pickLocation() async {
    HapticFeedback.lightImpact();
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _SelectLocationScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        _lat = result['latLng']?.latitude;
        _lng = result['latLng']?.longitude;
        if (result['address'] != null) {
          _addressController.text = result['address'];
        }
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _openWebPanel() async {
    HapticFeedback.mediumImpact();
    final Uri url = Uri.parse('https://food-delivery-categor.web.app');
    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (!launched) _showError("Не удалось открыть ссылку");
    } catch (e) {
      debugPrint("URL Launch Error: $e");
      _showError("Ошибка запуска: $e");
    }
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image != null) setState(() => _selectedImage = File(image.path));
    } catch (e) {
      _showError("Ошибка доступа к галерее: $e");
    }
  }

  Future<String?> _uploadToImgBB(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$_imgBBKey'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['data']['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text("Заявка успешно отправлена!", style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _sendApplication() async {
    HapticFeedback.heavyImpact();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showError("Пожалуйста, загрузите логотип");
      return;
    }
    if (_lat == null || _lng == null || _addressController.text.isEmpty) {
      _showError("Пожалуйста, укажите точку на карте");
      return;
    }

    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      String? imageUrl = await _uploadToImgBB(_selectedImage!);
      if (imageUrl == null) throw Exception("Ошибка загрузки фото на сервер");

      await FirebaseFirestore.instance.collection('business_requests').add({
        'userId': user?.uid,
        'contactEmail': _emailController.text.trim(),
        'businessName': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': '+373 ${_phoneController.text.trim()}',
        'time': _timeController.text.trim(),
        'logoUrl': imageUrl,
        'categoryKey': _categoryKeys[_selectedCategoryName],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isOpen': true,
        'lat': _lat,
        'lng': _lng,
      });

      _showSuccess();
    } catch (e) {
      _showError("Ошибка: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF10B981),
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('business_requests').where('userId', isEqualTo: user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildRegistrationForm();
            var requestData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            String status = requestData['status'] ?? 'pending';
            String docId = snapshot.data!.docs.first.id;
            if (status == 'approved') return _buildPartnerDashboard(requestData, docId);
            return _buildStatusScreen(requestData, docId);
          },
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildIconButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.05), shape: BoxShape.circle))),
        Positioned(bottom: -150, left: -100, child: Container(width: 350, height: 350, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.05), shape: BoxShape.circle))),
      ],
    );
  }

  Widget _buildGlassCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color accentColor, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthActionCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowButton({required String text, required VoidCallback? onPressed, bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: onPressed,
          child: isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8)),
        ),
      ),
    );
  }

  // --- 1. ВАУ-ПАРТНЕРСКИЙ ДАШБОРД ---
  Widget _buildPartnerDashboard(Map<String, dynamic> data, String docId) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _buildBackButton(),
        title: Text(
          data['businessName'] ?? 'Кабинет',
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildIconButton(
              icon: Icons.language_rounded,
              color: const Color(0xFF0284C7),
              onTap: _openWebPanel,
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
                                    SizedBox(width: 6),
                                    Text(
                                      "PARTNER VERIFIED",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399), fontSize: 10, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text("Терминал подключен", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text("Прием заказов работает в штатном режиме", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text("УПРАВЛЕНИЕ БИЗНЕСОМ", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionCard(
                        title: "ЗАКАЗЫ",
                        subtitle: "Активные тикеты",
                        icon: Icons.receipt_long_rounded,
                        accentColor: const Color(0xFF3B82F6),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessOrdersScreen(shopId: docId))),
                      ),
                      const SizedBox(width: 14),
                      _buildActionCard(
                        title: "СТОП-ЛИСТ",
                        subtitle: "Управление меню",
                        icon: Icons.block_rounded,
                        accentColor: const Color(0xFFF59E0B),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessStopListScreen(shopId: docId))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFullWidthActionCard(
                    title: "ВЕБ-ПАНЕЛЬ МЕНЕДЖЕРА",
                    subtitle: "Редактирование меню, цен и аналитика",
                    icon: Icons.space_dashboard_rounded,
                    onTap: _openWebPanel,
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Colors.red.shade400),
                            const SizedBox(width: 8),
                            Text("Выйти в клиентское меню", style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. ЭКРАН СТАТУСА ---
  Widget _buildStatusScreen(Map<String, dynamic> data, String docId) {
    bool isRejected = (data['status'] ?? 'pending') == 'rejected';
    Color statusColor = isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 5)],
                    ),
                    child: Icon(isRejected ? Icons.close_rounded : Icons.hourglass_top_rounded, size: 56, color: statusColor),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isRejected ? "Заявка отклонена" : "Заявка в обработке",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRejected
                        ? (data['reason'] ?? "К сожалению, заявка не прошла модерацию.")
                        : "Мы проверяем данные вашего заведения. Обычно это занимает не более 24 часов.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 40),
                  if (isRejected) ...[
                    ElevatedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('business_requests').doc(docId).delete(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text("ПОДАТЬ ЗАНОВО", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildGlowButton(
                    text: "ВЕРНУТЬСЯ",
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. ВАУ-ФОРМА РЕГИСТРАЦИИ ---
  Widget _buildRegistrationForm() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _buildBackButton(),
        title: const Text('Заявка на подключение', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Развивайте бизнес\nвместе с нами 🚀',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Заполните форму, чтобы получить доступ к панели управления и курьерской доставке.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Секция 1: Брендинг
                    _buildGlassCard(
                      title: "О БИЗНЕСЕ",
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: _selectedImage != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _selectedImage != null ? const Color(0xFF10B981).withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: _selectedImage != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover),
                              )
                                  : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFECFDF5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF10B981), size: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text("Загрузить лого", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text("КАТЕГОРИЯ ЗАВЕДЕНИЯ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        _buildCategoryChips(),
                        const SizedBox(height: 20),
                        _buildModernField(_nameController, 'Название заведения', Icons.storefront_rounded),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Секция 2: Контакты
                    _buildGlassCard(
                      title: "КОНТАКТНЫЕ ДАННЫЕ",
                      children: [
                        _buildModernField(_emailController, 'Email для связи', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildModernField(_phoneController, 'Номер телефона', Icons.phone_android_rounded, prefix: '+373 ', keyboardType: TextInputType.phone),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Секция 3: Локация
                    _buildGlassCard(
                      title: "ЛОКАЦИЯ И ГРАФИК",
                      children: [
                        InkWell(
                          onTap: _pickLocation,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: _lat != null ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _lat != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                width: _lat != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _lat != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.map_rounded, color: _lat != null ? Colors.white : const Color(0xFF64748B), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _lat != null ? 'Точка установлена' : 'Указать на карте',
                                        style: TextStyle(
                                          color: _lat != null ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _addressController.text.isNotEmpty ? _addressController.text : 'Обязательно для работы курьеров',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _lat != null ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                                  color: _lat != null ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildModernField(_timeController, 'Режим работы (например: 09:00 - 23:00)', Icons.access_time_filled_rounded),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Кнопка
                    _buildGlowButton(
                      text: "ОТПРАВИТЬ ЗАЯВКУ",
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _sendApplication,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categoryKeys.keys.map((catName) {
          bool isSelected = _selectedCategoryName == catName;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ChoiceChip(
                showCheckmark: false,
                elevation: isSelected ? 4 : 0,
                shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                avatar: Icon(_categoryIcons[catName], size: 18, color: isSelected ? Colors.white : const Color(0xFF64748B)),
                label: Text(catName),
                selected: isSelected,
                selectedColor: const Color(0xFF10B981),
                backgroundColor: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.transparent),
                ),
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategoryName = catName);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, String? prefix}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 15),
      validator: (v) => v == null || v.trim().isEmpty ? 'Заполните поле' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      ),
    );
  }
}

// --- ЕДИНЫЙ ПРЕМИАЛЬНЫЙ ЭКРАН ВЫБОРА КООРДИНАТ НА КАРТЕ ---
class _SelectLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const _SelectLocationScreen({this.initialLocation});

  @override
  State<_SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<_SelectLocationScreen> {
  final MapController _mapController = MapController();

  late LatLng _currentCenterCoord;
  String? _resolvedAddress;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentCenterCoord = widget.initialLocation ?? const LatLng(46.8410, 29.6470);
    _onMapPositionChanged(_currentCenterCoord, true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onMapPositionChanged(LatLng center, bool isInitial) {
    setState(() {
      _currentCenterCoord = center;
      if (!isInitial) {
        _isLoadingAddress = true;
        _resolvedAddress = 'Определяем точный адрес...';
      }
    });

    if (isInitial) {
      _fetchAddressFromCoordinates(center);
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchAddressFromCoordinates(center);
      });
    }
  }

  Future<void> _fetchAddressFromCoordinates(LatLng latLng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=ru&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterAppBusinessOrder/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          String road = address['road'] ?? address['pedestrian'] ?? address['street'] ?? address['path'] ?? '';
          String houseNumber = address['house_number'] ?? address['building'] ?? '';
          String suburb = address['suburb'] ?? address['neighbourhood'] ?? address['city_district'] ?? '';
          String city = address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'] ?? address['county'] ?? '';

          List<String> parts = [];
          if (road.isNotEmpty) {
            if (houseNumber.isNotEmpty) {
              parts.add('$road, $houseNumber');
            } else {
              parts.add(road);
            }
          } else if (suburb.isNotEmpty) {
            parts.add(suburb);
          }

          if (city.isNotEmpty && !parts.contains(city)) {
            parts.add(city);
          }

          if (mounted) {
            setState(() {
              if (parts.isNotEmpty) {
                _resolvedAddress = parts.join(', ');
              } else {
                String rawName = data['display_name'] ?? '';
                List<String> splitName = rawName.split(', ');
                if (splitName.length > 3) splitName.removeLast();
                _resolvedAddress = splitName.isNotEmpty ? splitName.join(', ') : 'Координаты: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
              }
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _resolvedAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _resolvedAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)} (Лимит)';
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка геокодинга: $e');
      if (mounted) {
        setState(() {
          _resolvedAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Укажите заведение на карте',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Stack(
        children: [
          // Карта с кастомными тайлами
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenterCoord,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  _onMapPositionChanged(position.center!, false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
              ),
            ],
          ),

          // Роскошная зеленая булавка строго по центру экрана
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 38),
              child: Icon(
                Icons.location_on_rounded,
                color: Color(0xFF10B981),
                size: 52,
              ),
            ),
          ),

          // Премиальная плашка с отображением найденного адреса сверху карты
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.place_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _resolvedAddress ?? 'Переместите карту для выбора...',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isLoadingAddress) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Кнопка подтверждения точки с передачей Map (координаты + адрес)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: SizedBox(
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      // Возвращаем Map, как и ожидает основной экран регистрации
                      Navigator.pop(context, {
                        'latLng': _currentCenterCoord,
                        'address': _resolvedAddress ?? '',
                      });
                    },
                    child: const Text(
                      'ПОДТВЕРДИТЬ ТОЧКУ ЗАВЕДЕНИЯ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}