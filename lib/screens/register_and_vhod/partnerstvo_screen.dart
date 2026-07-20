import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  };

  final Map<String, IconData> _categoryIcons = {
    'Еда': Icons.restaurant_rounded,
    'Продукты': Icons.shopping_bag_rounded,
    'Аптека': Icons.medical_services_rounded,
    'Цветы': Icons.local_florist_rounded,
    'Электроника': Icons.devices_other_rounded,
  };

  String _selectedCategoryName = 'Еда';
  bool isLoading = false;

  Future<void> _pickLocation() async {
    HapticFeedback.lightImpact();
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _SelectLocationScreen()),
    );

    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
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
    } catch (e) { return null; }
  }

  Future<void> _sendApplication() async {
    HapticFeedback.heavyImpact();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showError("Пожалуйста, выберите фото логотипа");
      return;
    }
    if (_lat == null || _lng == null) {
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

  // --- 1. ПАРТНЕРСКИЙ ДАШБОРД (PREMIUM LIGHT) ---
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
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWhiteCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 8, spreadRadius: 1)
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "PARTNER VERIFIED",
                                  style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: 1.2, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text("Терминал подключен", style: TextStyle(fontSize: 16, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text("УПРАВЛЕНИЕ БИЗНЕСОМ", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildActionCard(
                        title: "ЗАКАЗЫ",
                        subtitle: "Активные тикеты",
                        icon: Icons.shopping_bag_outlined,
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessOrdersScreen(shopId: docId))),
                      ),
                      const SizedBox(width: 14),
                      _buildActionCard(
                        title: "СТОП-ЛИСТ",
                        subtitle: "Стоп-товары",
                        icon: Icons.block_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessStopListScreen(shopId: docId))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFullWidthActionCard(
                    title: "ВЕБ-ПАНЕЛЬ МЕНЕДЖЕРА",
                    subtitle: "Редактирование меню, цен и аналитики",
                    icon: Icons.dashboard_customize_rounded,
                    onTap: _openWebPanel,
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF64748B)),
                      label: const Text("Выйти в клиентское меню", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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

  // --- 2. ЭКРАН СТАТУСА РАССМОТРЕНИЯ ---
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
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
                      boxShadow: [BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 25, spreadRadius: 2)],
                    ),
                    child: Icon(isRejected ? Icons.close_rounded : Icons.hourglass_empty_rounded, size: 64, color: statusColor),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isRejected ? "Заявка отклонена" : "На рассмотрении",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRejected ? (data['reason'] ?? "Заявка не прошла модерацию.") : "Ваша заявка уже проверяется администрацией. Обычно процесс занимает до 24 часов.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 40),
                  if (isRejected) ...[
                    OutlinedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('business_requests').doc(docId).delete(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text("ПОДАТЬ ЗАНОВО", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildGlowButton(
                    text: "ПОНЯТНО",
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

  // --- 3. ФОРМА РЕГИСТРАЦИИ (LIGHT PREMIER) ---
  Widget _buildRegistrationForm() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _buildBackButton(),
        title: const Text('Партнерство', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            'Подключите ваш\nбизнес 🚀',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: Color(0xFF0F172A),
                              letterSpacing: -1.0,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Присоединяйтесь к единой платформе доставки нового поколения.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Секция 1: Брендинг
                    _buildFormCard(
                      title: "О БИЗНЕСЕ",
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _selectedImage != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                                boxShadow: [
                                  if (_selectedImage != null)
                                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.2), blurRadius: 15, spreadRadius: 1)
                                ],
                              ),
                              child: _selectedImage != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover),
                              )
                                  : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: Color(0xFF10B981), size: 32),
                                  SizedBox(height: 6),
                                  Text("Логотип", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("ВЫБЕРИТЕ КАТЕГОРИЮ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        _buildCategoryChips(),
                        const SizedBox(height: 20),
                        _buildCustomField(_nameController, 'Название заведения', Icons.storefront_rounded),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Секция 2: Контакты
                    _buildFormCard(
                      title: "КОНТАКТЫ",
                      children: [
                        _buildCustomField(_emailController, 'Email для связи', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildCustomField(_phoneController, 'Номер телефона', Icons.phone_android_rounded, prefix: '+373 ', keyboardType: TextInputType.phone),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Секция 3: Локация
                    _buildFormCard(
                      title: "ЛОКАЦИЯ И ГРАФИК",
                      children: [
                        _buildCustomField(_addressController, 'Адрес заведения', Icons.location_on_rounded),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _pickLocation,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: _lat != null ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _lat != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _lat != null ? const Color(0xFF10B981).withOpacity(0.15) : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.map_rounded, color: _lat != null ? const Color(0xFF059669) : const Color(0xFF64748B), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _lat != null ? 'Точка установлена ✓' : 'Указать точку на карте',
                                        style: TextStyle(
                                          color: _lat != null ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _lat != null ? '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}' : 'Обязательно для курьеров',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                        _buildCustomField(_timeController, 'Режим работы (например: 09:00 - 23:00)', Icons.access_time_filled_rounded),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Кнопка действия
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

  // --- UI ЭЛЕМЕНТЫ В СВЕТЛОМ СТИЛЕ ---

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categoryKeys.keys.map((catName) {
          bool isSelected = _selectedCategoryName == catName;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(_categoryIcons[catName], size: 18, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              label: Text(catName),
              selected: isSelected,
              selectedColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFFF1F5F9),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0))),
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategoryName = catName);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCustomField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, String? prefix}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 15),
      validator: (v) => v == null || v.trim().isEmpty ? 'Заполните поле' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      ),
    );
  }

  Widget _buildFormCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGlowButton({required String text, required VoidCallback? onPressed, bool isLoading = false}) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
        boxShadow: [
          if (!isLoading)
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
            : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0)),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Gradient gradient, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthActionCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: const Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.08),
            ),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90), child: Container()),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6).withOpacity(0.06),
            ),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
          ),
        ),
      ],
    );
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Заявка успешно отправлена!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _SelectLocationScreen extends StatelessWidget {
  const _SelectLocationScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите точку')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, const LatLng(46.8480, 29.6331)),
          child: const Text('Подтвердить координаты'),
        ),
      ),
    );
  }
}