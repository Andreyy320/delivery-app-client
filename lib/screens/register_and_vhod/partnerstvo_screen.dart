import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
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

  // ПЕРЕМЕННЫЕ ДЛЯ КООРДИНАТ
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

  String _selectedCategoryName = 'Еда';
  bool isLoading = false;

  // ВЫБОР ЛОКАЦИИ НА КАРТЕ
  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _SelectLocationScreen()),
    );

    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  Future<void> _openWebPanel() async {
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
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
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
        'address': _addressController.text.trim(), // Текстовый адрес
        'phone': '+373 ${_phoneController.text.trim()}',
        'time': _timeController.text.trim(),
        'logoUrl': imageUrl,
        'categoryKey': _categoryKeys[_selectedCategoryName],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isOpen': true,
        // СОХРАНЯЕМ КООРДИНАТЫ ОТДЕЛЬНО
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('business_requests').where('userId', isEqualTo: user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildRegistrationForm();
        var requestData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String status = requestData['status'] ?? 'pending';
        String docId = snapshot.data!.docs.first.id;
        if (status == 'approved') return _buildPartnerDashboard(requestData, docId);
        return _buildStatusScreen(requestData, docId);
      },
    );
  }

  // Методы Dashboard и StatusScreen без изменений...
  Widget _buildPartnerDashboard(Map<String, dynamic> data, String docId) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(data['businessName'] ?? 'Кабинет', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.language, color: Colors.deepOrange), onPressed: _openWebPanel)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("ПАРТНЕР DELIVERY", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange)), Text("Сервис работает активно", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                  Icon(Icons.verified_user_rounded, color: Colors.green[400], size: 30),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("УПРАВЛЕНИЕ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            Row(children: [
              _dashboardButton("ЗАКАЗЫ", Icons.shopping_bag_outlined, Colors.blueAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessOrdersScreen(shopId: docId)));
              }),
              const SizedBox(width: 15),
              _dashboardButton("СТОП-ЛИСТ", Icons.block_flipped, Colors.orangeAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessStopListScreen(shopId: docId)));
              }),
            ]),
            const SizedBox(height: 15),
            _dashboardButton("МЕНЮ И НАСТРОЙКИ (WEB)", Icons.open_in_new_rounded, Colors.black, _openWebPanel, fullWidth: true),
            const SizedBox(height: 40),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Выйти в клиентское меню", style: TextStyle(color: Colors.grey))))
          ],
        ),
      ),
    );
  }

  Widget _dashboardButton(String title, IconData icon, Color color, VoidCallback onTap, {bool fullWidth = false}) {
    Widget button = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 25),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 30), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
    );
    return fullWidth ? GestureDetector(onTap: onTap, child: button) : Expanded(child: GestureDetector(onTap: onTap, child: button));
  }

  Widget _buildStatusScreen(Map<String, dynamic> data, String docId) {
    String status = data['status'] ?? 'pending';
    IconData statusIcon = status == 'rejected' ? Icons.cancel_rounded : Icons.access_time_rounded;
    Color statusColor = status == 'rejected' ? Colors.red : Colors.orange;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, size: 100, color: statusColor),
              const SizedBox(height: 24),
              Text(status == 'rejected' ? "Заявка отклонена" : "Заявка на рассмотрении", textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(status == 'rejected' ? (data['reason'] ?? "Отклонено.") : "Проверка до 24 часов.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),
              if (status == 'rejected') TextButton(onPressed: () => FirebaseFirestore.instance.collection('business_requests').doc(docId).delete(), child: const Text("Подать заново", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))),
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("ПОНЯТНО", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Партнерство', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Подключите ваш\nбизнес 🚀', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 30),
              Center(
                child: Column(children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25), border: Border.all(color: _selectedImage != null ? Colors.deepOrange : Colors.grey[300]!, width: 2)),
                      child: _selectedImage != null ? ClipRRect(borderRadius: BorderRadius.circular(23), child: Image.file(_selectedImage!, fit: BoxFit.cover)) : const Icon(Icons.add_a_photo_rounded, color: Colors.deepOrange, size: 40),
                    ),
                  ),
                  if (_selectedImage != null) TextButton(onPressed: _pickImage, child: const Text('Изменить фото', style: TextStyle(color: Colors.deepOrange))),
                ]),
              ),
              const SizedBox(height: 30),
              _sectionTitle('КАТЕГОРИЯ'),
              _buildTypeSelector(),
              const SizedBox(height: 25),
              _buildField(_emailController, 'Email для связи', Icons.email_outlined),
              const SizedBox(height: 15),
              _buildField(_phoneController, 'Телефон', Icons.phone_android, prefix: '+373 '),
              const SizedBox(height: 15),
              _buildField(_nameController, 'Название заведения', Icons.storefront),
              const SizedBox(height: 15),
              // ТЕКСТОВЫЙ АДРЕС
              _buildField(_addressController, 'Адрес (Улица, дом)', Icons.location_city_outlined),
              const SizedBox(height: 10),
              // КНОПКА КАРТЫ ДЛЯ КООРДИНАТ
              GestureDetector(
                onTap: _pickLocation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _lat != null ? Colors.green.withOpacity(0.1) : Colors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _lat != null ? Colors.green : Colors.deepOrange, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_rounded, color: _lat != null ? Colors.green : Colors.deepOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lat != null
                              ? 'Координаты установлены ✓'
                              : 'Указать точку на карте (обязательно)',
                          style: TextStyle(
                              color: _lat != null ? Colors.green[700] : Colors.deepOrange[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14
                          ),
                        ),
                      ),
                      if (_lat != null) Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildField(_timeController, 'Время работы (напр. 08:00 - 22:00)', Icons.access_time_rounded),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _sendApplication,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ОТПРАВИТЬ ЗАЯВКУ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess() { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка отправлена! 📩'), backgroundColor: Colors.green)); }
  void _showError(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)); }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)));

  Widget _buildTypeSelector() {
    return Wrap(spacing: 8, children: _categoryKeys.keys.map((name) {
      bool isSelected = _selectedCategoryName == name;
      return ChoiceChip(label: Text(name), selected: isSelected, onSelected: (val) => setState(() => _selectedCategoryName = name), selectedColor: Colors.deepOrange, labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black));
    }).toList());
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {String? prefix}) {
    return TextFormField(
      controller: controller,
      validator: (v) => v!.isEmpty ? 'Заполните поле' : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.deepOrange),
        prefixText: prefix,
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}

// ЭКРАН ВЫБОРА НА КАРТЕ
class _SelectLocationScreen extends StatefulWidget {
  const _SelectLocationScreen();
  @override
  State<_SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<_SelectLocationScreen> {
  LatLng? selectedLatLng;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Укажите заведение'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
              initialZoom: 15,
              onTap: (_, latLng) => setState(() => selectedLatLng = latLng),
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
              if (selectedLatLng != null)
                MarkerLayer(markers: [
                  Marker(point: selectedLatLng!, width: 50, height: 50, child: const Icon(Icons.location_on_rounded, color: Colors.deepOrange, size: 45))
                ]),
            ],
          ),
          if (selectedLatLng != null)
            Positioned(
              bottom: 30, left: 20, right: 20,
              child: SizedBox(height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () => Navigator.pop(context, selectedLatLng), child: const Text('ПОДТВЕРДИТЬ МЕСТО', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ),
        ],
      ),
    );
  }
}