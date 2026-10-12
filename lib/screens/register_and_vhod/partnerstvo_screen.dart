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
import 'package:geolocator/geolocator.dart';

import '../../Api_Servicess.dart';
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
  final _addressController = TextEditingController();
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
            const SizedBox(width: 10),
            Text("Заявка успешно отправлена!", style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
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
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('business_requests').where('userId', isEqualTo: user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
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
        Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.05), shape: BoxShape.circle))),
        Positioned(bottom: -150, left: -100, child: Container(width: 350, height: 350, decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.05), shape: BoxShape.circle))),
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
              decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
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
          gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
          boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
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

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, String? prefix}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      ),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Поле обязательно для заполнения' : null,
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
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategoryName = catName);
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(_categoryIcons[catName], size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(catName, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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
              color: const Color(0xFF2563EB),
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
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF60A5FA)),
                                    SizedBox(width: 6),
                                    Text(
                                      "PARTNER VERIFIED",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF93C5FD), fontSize: 10, letterSpacing: 1),
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
                            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)
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
                                  color: _selectedImage != null ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _selectedImage != null ? const Color(0xFF2563EB).withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
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
                                      color: Color(0xFFEFF6FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF2563EB), size: 24),
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
                    _buildGlassCard(
                      title: "КОНТАКТНЫЕ ДАННЫЕ",
                      children: [
                        _buildModernField(_emailController, 'Email для связи', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildModernField(_phoneController, 'Номер телефона', Icons.phone_android_rounded, prefix: '+373 ', keyboardType: TextInputType.phone),
                        const SizedBox(height: 14),
                        _buildModernField(_timeController, 'График работы (например: 09:00 - 22:00)', Icons.access_time_rounded),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                              color: _lat != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _lat != null ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: _lat != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _lat != null ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
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
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: _lat != null ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _lat != null ? _addressController.text : 'Нажмите, чтобы выбрать адрес',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: _lat != null ? const Color(0xFF1D4ED8) : const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: _lat != null ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildGlowButton(
                      text: "ОТПРАВИТЬ ЗАЯВКУ",
                      onPressed: _sendApplication,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Ускоренный экран выбора точки на карте ---
class _SelectLocationScreen extends StatefulWidget {
  const _SelectLocationScreen();

  @override
  State<_SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<_SelectLocationScreen> {
  final MapController _mapController = MapController();
  LatLng _pickedLocation = const LatLng(46.9856, 28.8585); // Мгновенный старт (дефолтные координаты)
  bool _isLoadingAddress = false;
  String _addressText = "Переместите карту для выбора адреса";

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Запускаем геопозицию АСИНХРОННО в фоне после отрисовки экрана,
    // чтобы открытие окна вообще не задерживалось.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineInitialPositionFast();
    });
  }

  Future<void> _determineInitialPositionFast() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // Быстрый запрос последней известной позиции (без ожидания спутников)
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 2),
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _pickedLocation = currentLatLng;
        });
        _mapController.move(currentLatLng, 15.0);
        _getAddressFromApi(currentLatLng);
      }
    } catch (e) {
      debugPrint("Fast location error: $e");
    }
  }

  Future<void> _getAddressFromApi(LatLng latLng) async {
    setState(() => _isLoadingAddress = true);
    try {
      final result = await AddressApiService.locateAddress(latLng.latitude, latLng.longitude);

      if (mounted && result != null) {
        final addressName = result['name'] ?? result['address'] ?? result['display_name'] ?? 'Адрес найден';
        setState(() => _addressText = addressName.toString());
      } else if (mounted) {
        setState(() => _addressText = "Адрес не найден");
      }
    } catch (e) {
      if (mounted) setState(() => _addressText = "Ошибка определения адреса");
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  // Оптимизация: Запрос к API улетает только тогда, когда пользователь
  // перестал двигать карту (debounce 400мс), что полностью убирает лаги при скролле.
  // Обновленный метод для отслеживания движения камеры
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      final center = camera.center;
      setState(() {
        _pickedLocation = center;
      });

      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _getAddressFromApi(_pickedLocation);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: 15.0,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.food_delivery',
                // Дополнительные параметры для кэширования и скорости тайлов:
                tileProvider: NetworkTileProvider(),
              ),
            ],
          ),
          // Миниатюрная синяя точка по центру экрана
           Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          // Верхняя кнопка назад
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Нижняя панель с выбранным адресом
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Выбранный адрес:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLoadingAddress ? "Определение адреса..." : _addressText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context, {
                              'latLng': _pickedLocation,
                              'address': _addressText,
                            });
                          },
                          child: const Text("ПОДТВЕРДИТЬ ТОЧКУ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
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