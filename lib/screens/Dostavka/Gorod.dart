import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'gorod_conf.dart';

class CityCargoDetailsScreen extends StatefulWidget {
  const CityCargoDetailsScreen({super.key});

  @override
  State<CityCargoDetailsScreen> createState() => _CityCargoDetailsScreenState();
}

class _CityCargoDetailsScreenState extends State<CityCargoDetailsScreen> {
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
    'S': 'Компактный кузов\nДо 300 кг • 2-3 коробки',
    'M': 'Средний кузов\nДо 700 кг • Диван + техника',
    'L': 'Грузовой стандарт\nДо 1400 кг • Квартирный переезд',
    'XL': 'Большой кузов\nДо 2000 кг • Стройматериалы',
    'XXL': 'Максимальный объем\nДо 4000 кг • Офисный переезд',
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

  // ======= РАСЧЕТ ЦЕН (Для БД) =======

  int _getBasePrice() {
    int price = 0;
    switch (selectedBody) {
      case 'S': price = 300; break;
      case 'M': price = 450; break;
      case 'L': price = 600; break;
      case 'XL': price = 800; break;
      case 'XXL': price = 1100; break;
    }
    price += loaders * 150;
    if (escort > 0) price += 200;
    if (timeSelected) price += 100;
    return price;
  }

  int _getRoutePrice() {
    double kmRate = 12.0;
    switch (selectedBody) {
      case 'S': kmRate = 8; break;
      case 'M': kmRate = 10; break;
      case 'L': kmRate = 12; break;
      case 'XL': kmRate = 15; break;
      case 'XXL': kmRate = 20; break;
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
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Когда приехать?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('ПОДТВЕРДИТЬ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      itemExtent: 45,
      selectionOverlay: Container(decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.withOpacity(0.2))))),
      onSelectedItemChanged: onChanged,
      children: items.map((item) => Center(child: Text(item, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Детали заказа', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _vehicleCard(),
                  const SizedBox(height: 20),
                  _containerBlock(
                    child: Column(
                      children: [
                        _sectionWithOptions(title: 'Класс авто', options: bodySizes, selected: selectedBody, onSelect: (v) => setState(() => selectedBody = v)),
                        _divider(),
                        _sectionWithCounter(title: 'Грузчики', value: loaders, onChanged: (v) => setState(() => loaders = v)),
                        _divider(),
                        _sectionWithCounter(title: 'Сопровождение', value: escort, onChanged: (v) => setState(() => escort = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _containerBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Маршрут и время', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        _AddressField(label: 'Откуда', controller: fromController, onTap: () => _openMap(fromController), icon: Icons.circle_outlined, iconColor: Colors.blue),
                        const SizedBox(height: 8),
                        _AddressField(label: 'Куда', controller: toController, onTap: () => _openMap(toController), icon: Icons.location_on, iconColor: Colors.deepOrange),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _showTimePickerSheet,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.deepOrange.withOpacity(0.1))),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: Colors.deepOrange, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  timeSelected ? '${days[selectedDayIndex]}, ${selectedHour}:${selectedMinute.toString().padLeft(2, '0')}' : 'Как можно скорее',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.deepOrange),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.deepOrange),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, -10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rawDistanceKm > 0) ...[
            _priceRow('Тариф + услуги', '$base ₽'),
            const SizedBox(height: 6),
            _priceRow('Маршрут (${_rawDistanceKm.toStringAsFixed(1)} км)', '$route ₽'),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ИТОГО', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                  Text('$total Руб', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: Colors.deepOrange.withOpacity(0.4),
                ),
                onPressed: () {
                  if (fromLatLng == null || toLatLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите маршрут на карте')));
                    return;
                  }

                  DateTime? finalTime;
                  if (timeSelected) {
                    final now = DateTime.now();
                    finalTime = DateTime(now.add(Duration(days: selectedDayIndex)).year, now.add(Duration(days: selectedDayIndex)).month, now.add(Duration(days: selectedDayIndex)).day, selectedHour, selectedMinute);
                  }

                  Navigator.push(context, MaterialPageRoute(builder: (_) => GorodOrderConfirmationScreen(
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
                child: const Text('ГОТОВО', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _vehicleCard() {
    return Container(
      width: double.infinity,
      decoration: _boxDecoration(),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[50],
              child: Image.asset(bodyImages[selectedBody]!, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(bodyDescriptions[selectedBody]!.split('\n')[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(bodyDescriptions[selectedBody]!.split('\n')[1], style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _containerBlock({required Widget child}) => Container(padding: const EdgeInsets.all(20), decoration: _boxDecoration(), child: child);

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
  );

  Widget _divider() => Divider(height: 32, color: Colors.grey[100], thickness: 1);

  Widget _sectionWithOptions({required String title, required List<String> options, required String selected, required Function(String) onSelect}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onSelect(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w800)),
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
          child: Row(
            children: List.generate(3, (i) => GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: value == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: value == i ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
                ),
                child: Text(i == 0 ? '0' : i.toString(), style: TextStyle(color: value == i ? Colors.black : Colors.grey, fontWeight: FontWeight.w900)),
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
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                controller.text.isEmpty ? label : controller.text,
                style: TextStyle(color: controller.text.isEmpty ? Colors.grey : Colors.black, fontWeight: FontWeight.w700, fontSize: 15),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.map_outlined, size: 18, color: Colors.grey),
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: const LatLng(46.8410, 29.6470), initialZoom: 14, onTap: (_, latLng) => setState(() => selectedLatLng = latLng)),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
              if (selectedLatLng != null) MarkerLayer(markers: [Marker(point: selectedLatLng!, width: 80, height: 80, child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 45))]),
            ],
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: selectedLatLng == null ? 0 : 1,
              child: ElevatedButton(
                onPressed: selectedLatLng == null ? null : () => Navigator.pop(context, selectedLatLng),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 65), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('ПОДТВЕРДИТЬ ТОЧКУ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
