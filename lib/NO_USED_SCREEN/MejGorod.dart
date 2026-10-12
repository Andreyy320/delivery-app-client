import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Импорт экрана подтверждения межгорода
import 'mejgorod_conf.dart';

class MejCityCargoDetailsScreen extends StatefulWidget {
  const MejCityCargoDetailsScreen({super.key});

  @override
  State<MejCityCargoDetailsScreen> createState() => _MejCityCargoDetailsScreenState();
}

class _MejCityCargoDetailsScreenState extends State<MejCityCargoDetailsScreen> {
  // ======= СОСТОЯНИЕ =======
  String selectedBody = 'L';
  int loaders = 0;
  int escort = 0;

  bool timeSelected = false;
  final List<String> days = ['Сегодня', 'Завтра', 'Послезавтра'];
  int selectedDayIndex = 0;
  int selectedHour = 12;
  int selectedMinute = 0;

  double _rawDistanceKm = 0.0;
  int _rawDurationMin = 0;
  bool _isCalculatingRoute = false;

  final List<String> bodySizes = ['S', 'M', 'L', 'XL', 'XXL'];
  final Map<String, String> bodyImages = {
    'S': 'assets/images/Dostavka/mashina1.jpg',
    'M': 'assets/images/Dostavka/mashina2.jpg',
    'L': 'assets/images/Dostavka/mashina3.jpg',
    'XL': 'assets/images/Dostavka/mashina4.jpg',
    'XXL': 'assets/images/Dostavka/mashina5.jpg',
  };
  final Map<String, String> bodyDescriptions = {
    'S': 'Малогабаритный межгород\nДо 300 кг • Личные вещи',
    'M': 'Средний борт\nДо 700 кг • Мебель и техника',
    'L': 'Междугородний стандарт\nДо 1400 кг • Переезд квартиры',
    'XL': 'Тяжелый груз\nДо 2000 кг • Оборудование',
    'XXL': 'Фура / Макси\nДо 4000 кг • Огромный объем',
  };

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  LatLng? fromLatLng;
  LatLng? toLatLng;

  // ======= ЛОГИКА МАРШРУТА =======

  Future<void> _getRouteMetrics() async {
    if (fromLatLng == null || toLatLng == null) return;
    setState(() => _isCalculatingRoute = true);

    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${fromLatLng!.longitude},${fromLatLng!.latitude};'
            '${toLatLng!.longitude},${toLatLng!.latitude}?overview=false');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          setState(() {
            _rawDistanceKm = route['distance'] / 1000.0;
            _rawDurationMin = (route['duration'] / 60.0).round();
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка маршрута: $e");
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  // ======= РАСЧЕТ ЦЕН (Межгород) =======

  int _getBasePrice() {
    int price = 0;
    switch (selectedBody) {
      case 'S': price = 2000; break;
      case 'M': price = 3000; break;
      case 'L': price = 4500; break;
      case 'XL': price = 6500; break;
      case 'XXL': price = 9000; break;
    }
    price += loaders * 500;
    if (escort > 0) price += 1000;
    if (timeSelected) price += 300;
    return price;
  }

  // ЧИСТАЯ ЦЕНА ЗА ДОРОГУ
  int _getRoutePrice() {
    if (_rawDistanceKm == 0) return 0;
    double kmRate = 35.0;
    switch (selectedBody) {
      case 'S': kmRate = 25; break;
      case 'M': kmRate = 30; break;
      case 'L': kmRate = 35; break;
      case 'XL': kmRate = 45; break;
      case 'XXL': kmRate = 60; break;
    }
    return (_rawDistanceKm * kmRate).round();
  }

  int _calculateTotalPrice() => _getBasePrice() + _getRoutePrice();

  Future<void> _openMap(TextEditingController controller) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );

    if (result != null) {
      setState(() {
        if (controller == fromController) fromLatLng = result;
        else toLatLng = result;
        controller.text = 'Выбрано на карте';
      });
      _getRouteMetrics();
    }
  }

  // ======= UI ШИТЫ =======

  void _showTimePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 420,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 30,
              offset: Offset(0, -10),
            )
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Дата отправления',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildPicker(initialItem: selectedDayIndex, items: days, onChanged: (i) => setState(() { selectedDayIndex = i; timeSelected = true; }))),
                  Expanded(child: _buildPicker(initialItem: selectedHour, items: List.generate(24, (i) => '$i ч'), onChanged: (i) => setState(() { selectedHour = i; timeSelected = true; }))),
                  Expanded(child: _buildPicker(initialItem: selectedMinute, items: List.generate(60, (i) => '${i.toString().padLeft(2, '0')} м'), onChanged: (i) => setState(() { selectedMinute = i; timeSelected = true; }))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ПОДТВЕРДИТЬ ВРЕМЯ',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker({required int initialItem, required List<String> items, required ValueChanged<int> onChanged}) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 44,
      selectionOverlay: Container(
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
          ),
        ),
      ),
      onSelectedItemChanged: onChanged,
      children: items.map((item) => Center(
        child: Text(
          item,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Межгород',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _vehicleCard(),
                  const SizedBox(height: 16),
                  _containerBlock(
                    child: Column(
                      children: [
                        _sectionWithOptions(title: 'Класс перевозки', options: bodySizes, selected: selectedBody, onSelect: (v) => setState(() => selectedBody = v)),
                        _divider(),
                        _sectionWithCounter(title: 'Грузчики', value: loaders, onChanged: (v) => setState(() => loaders = v)),
                        _divider(),
                        _sectionWithCounter(title: 'Сопровождение', value: escort, onChanged: (v) => setState(() => escort = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _containerBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'МАРШРУТ МЕЖГОРОД',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AddressField(label: 'Откуда', controller: fromController, onTap: () => _openMap(fromController), icon: Icons.circle_outlined, iconColor: const Color(0xFF0F172A)),
                        const SizedBox(height: 10),
                        _AddressField(label: 'Куда (Другой город)', controller: toController, onTap: () => _openMap(toController), icon: Icons.location_on_rounded, iconColor: const Color(0xFFD97706)),

                        if (_rawDistanceKm > 0) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.speed_rounded, color: Color(0xFFD97706), size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Путь: ${_rawDistanceKm.toStringAsFixed(1)} км • Время: ~${(_rawDurationMin / 60).toStringAsFixed(1)} ч.',
                                    style: const TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _showTimePickerSheet,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFD97706), size: 18),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    timeSelected ? '${days[selectedDayIndex]}, ${selectedHour}:${selectedMinute.toString().padLeft(2, '0')}' : 'Как можно быстрее',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF78350F), fontSize: 14),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD97706)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _bottomPricePanel(),
        ],
      ),
    );
  }

  // ======= КОМПОНЕНТЫ ДИЗАЙНА =======

  Widget _bottomPricePanel() {
    final base = _getBasePrice();
    final route = _getRoutePrice();
    final total = base + route;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding > 0 ? bottomPadding + 8 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rawDistanceKm > 0) ...[
            _priceRow('База + Доп. услуги', '$base Руб'),
            const SizedBox(height: 6),
            _priceRow('Дорога (${_rawDistanceKm.toStringAsFixed(1)} км)', '$route Руб'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFF1F5F9), height: 1),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'К ОПЛАТЕ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total Руб',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: const Color(0xFFD97706).withOpacity(0.3),
                ),
                onPressed: _isCalculatingRoute ? null : () {
                  if (fromLatLng == null || toLatLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Укажите маршрут на карте', style: TextStyle(fontWeight: FontWeight.w700)),
                        backgroundColor: const Color(0xFF0F172A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  DateTime? finalTime;
                  if (timeSelected) {
                    final now = DateTime.now();
                    finalTime = DateTime(
                      now.add(Duration(days: selectedDayIndex)).year,
                      now.add(Duration(days: selectedDayIndex)).month,
                      now.add(Duration(days: selectedDayIndex)).day,
                      selectedHour,
                      selectedMinute,
                    );
                  }

                  Navigator.push(context, MaterialPageRoute(builder: (_) => MejGorodOrderConfirmationScreen(
                    fromAddress: fromController.text,
                    toAddress: toController.text,
                    pickup: {'lat': fromLatLng!.latitude, 'lng': fromLatLng!.longitude},
                    dropoff: {'lat': toLatLng!.latitude, 'lng': toLatLng!.longitude},
                    bodySize: selectedBody,
                    loaders: loaders,
                    escort: escort,
                    timeSelected: timeSelected,
                    scheduledTime: finalTime,
                    basePrice: base,
                    routePrice: route,
                    totalPrice: total,
                  )));
                },
                child: _isCalculatingRoute
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                  children: [
                    Text('ГОТОВО', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _vehicleCard() {
    return Container(
      width: double.infinity,
      decoration: _boxDecoration(),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.asset(bodyImages[selectedBody]!, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  bodyDescriptions[selectedBody]!.split('\n')[0],
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  bodyDescriptions[selectedBody]!.split('\n')[1],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _containerBlock({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _boxDecoration(),
    child: child,
  );

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.02),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
  );

  Widget _sectionWithOptions({required String title, required List<String> options, required String selected, required Function(String) onSelect}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onSelect(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  Widget _sectionWithCounter({required String title, required int value, required Function(int) onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: List.generate(3, (i) => GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: value == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: value == i
                      ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  i == 0 ? '0' : i.toString(),
                  style: TextStyle(
                    color: value == i ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            )),
          ),
        )
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;

  const _AddressField({required this.label, required this.controller, required this.onTap, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.text.isEmpty ? label : controller.text,
                style: TextStyle(
                  color: controller.text.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.map_outlined, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});
  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  LatLng? selectedLatLng;
  final MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
              initialZoom: 14,
              onTap: (_, latLng) => setState(() => selectedLatLng = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: selectedLatLng == null ? 0 : 1,
              child: ElevatedButton(
                onPressed: selectedLatLng == null ? null : () => Navigator.pop(context, selectedLatLng),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: const Color(0xFF0F172A).withOpacity(0.3),
                ),
                child: const Text('ПОДТВЕРДИТЬ ТОЧКУ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}