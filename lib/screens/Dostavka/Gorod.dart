import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'gorod_conf.dart';

class CityCargoDetailsScreen extends StatefulWidget {
  const CityCargoDetailsScreen({super.key});

  @override
  State<CityCargoDetailsScreen> createState() =>
      _CityCargoDetailsScreenState();
}

class _CityCargoDetailsScreenState extends State<CityCargoDetailsScreen> {
  // ======= ЛОГИКА И СОСТОЯНИЕ (БЕЗ ИЗМЕНЕНИЙ) =======
  String selectedBody = 'L';
  int loaders = 0;
  int escort = 0;

  bool timeSelected = false;
  final List<String> days = ['Сегодня', 'Завтра', 'Послезавтра'];
  int selectedDayIndex = 0;
  int selectedHour = 2;
  int selectedMinute = 0;

  final List<String> bodySizes = ['S', 'M', 'L', 'XL', 'XXL'];
  final Map<String, String> bodyImages = {
    'S': 'assets/images/Dostavka/mashina1.jpg',
    'M': 'assets/images/Dostavka/mashina2.jpg',
    'L': 'assets/images/Dostavka/mashina3.jpg',
    'XL': 'assets/images/Dostavka/mashina4.jpg',
    'XXL': 'assets/images/Dostavka/mashina5.jpg',
  };
  final Map<String, String> bodyDescriptions = {
    'S': 'Подходит для нескольких коробок\nМаксимум 300 кг',
    'M': 'Увезет диван и стиральную машину\nМаксимум 700 кг',
    'L': 'Поможет переехать в новую квартиру\nМаксимум 1400 кг',
    'XL': 'Подойдет для стройматериалов\nМаксимум 2000 кг',
    'XXL': 'Подойдет, если не подошел XL\nМаксимум 4000 кг',
  };

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  LatLng? fromLatLng;
  LatLng? toLatLng;

  int _calculatePrice() {
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

  Future<void> _openMap(TextEditingController controller) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );

    if (result != null) {
      setState(() {
        if (controller == fromController) {
          fromLatLng = result;
        } else {
          toLatLng = result;
        }
        controller.text =
        'Ш: ${result.latitude.toStringAsFixed(5)}, Д: ${result.longitude.toStringAsFixed(5)}';
      });
    }
  }

  void _showTimePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 420,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16, top: 4),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Выберите время', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      IconButton(
                        icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.close, size: 20, color: Colors.black)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: _buildPicker(initialItem: selectedDayIndex, items: days, onChanged: (index) { setModalState(() => selectedDayIndex = index); setState(() => timeSelected = true); })),
                          Expanded(flex: 1, child: _buildPicker(initialItem: selectedHour, items: List.generate(24, (i) => '$i ч'), onChanged: (index) { setModalState(() => selectedHour = index); setState(() => timeSelected = true); })),
                          Expanded(flex: 1, child: _buildPicker(initialItem: selectedMinute, items: List.generate(60, (i) => '${i.toString().padLeft(2, '0')} м'), onChanged: (index) { setModalState(() => selectedMinute = index); setState(() => timeSelected = true); })),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Text('Выбрано: ${days[selectedDayIndex]}, ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity, height: 60,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ГОТОВО', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPicker({required int initialItem, required List<String> items, required ValueChanged<int> onChanged}) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 45,
      onSelectedItemChanged: onChanged,
      children: items.map((item) => Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FittedBox(fit: BoxFit.scaleDown, child: Text(item, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))))).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.black),
        title: SizedBox(width: MediaQuery.of(context).size.width * 0.7, child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Грузоперевозка по городу', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)))),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _vehicleCard(),
                  const SizedBox(height: 24),
                  _containerBlock(
                    child: Column(
                      children: [
                        _sectionWithOptions(title: 'Размер кузова', options: bodySizes, selected: selectedBody, onSelect: (v) => setState(() => selectedBody = v)),
                        _divider(),
                        _sectionWithCounter(title: 'Грузчики', value: loaders, onChanged: (v) => setState(() => loaders = v)),
                        _divider(),
                        _sectionWithCounter(title: 'Сопровождение', value: escort, onChanged: (v) => setState(() => escort = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _containerBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Детали подачи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 20),
                        _AddressField(label: 'Откуда', controller: fromController, onTap: () => _openMap(fromController)),
                        const SizedBox(height: 12),
                        _AddressField(label: 'Куда', controller: toController, onTap: () => _openMap(toController)),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: _showTimePickerSheet,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: timeSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: timeSelected ? Colors.deepOrange.withOpacity(0.2) : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_filled_rounded, color: timeSelected ? Colors.deepOrange : Colors.grey[600]),
                                const SizedBox(width: 12),
                                Expanded(child: Text(timeSelected ? 'Время: ${days[selectedDayIndex]}, ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}' : 'Заказать ко времени', style: TextStyle(fontSize: 15, fontWeight: timeSelected ? FontWeight.w800 : FontWeight.w600, color: timeSelected ? Colors.black : Colors.grey[700]))),
                                if (timeSelected) IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.cancel, color: Colors.grey, size: 20), onPressed: () => setState(() => timeSelected = false)) else const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
            decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, -5))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого к оплате:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey)),
                    Text('${_calculatePrice()} ₽', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 64,
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: () {
                        if (fromLatLng == null || toLatLng == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите адреса на карте')));
                          return;
                        }

                        DateTime? scheduledTimeValue = timeSelected
                            ? DateTime.now().add(Duration(days: selectedDayIndex)).copyWith(hour: selectedHour, minute: selectedMinute)
                            : null;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GorodOrderConfirmationScreen(
                              fromAddress: fromController.text,
                              toAddress: toController.text,
                              pickup: {'lat': fromLatLng!.latitude, 'lng': fromLatLng!.longitude},
                              dropoff: {'lat': toLatLng!.latitude, 'lng': toLatLng!.longitude},
                              bodySize: selectedBody,
                              loaders: loaders,
                              escort: escort,
                              timeSelected: timeSelected,
                              scheduledTime: scheduledTimeValue,
                              totalPrice: _calculatePrice(),
                            ),
                          ),
                        );
                      },
                      child: const Text('ЗАКАЗАТЬ МАШИНУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard() {
    return Container(
      decoration: _boxDecoration(),
      child: Column(
        children: [
          Container(
            height: 320,
            decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), image: DecorationImage(image: AssetImage(bodyImages[selectedBody]!), fit: BoxFit.contain)),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), child: Text(bodyDescriptions[selectedBody]!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
        ],
      ),
    );
  }

  Widget _containerBlock({required Widget child}) => Container(padding: const EdgeInsets.all(20), decoration: _boxDecoration(), child: child);
  BoxDecoration _boxDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))]);
  Widget _divider() => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.grey[100], thickness: 1.5));

  Widget _sectionWithOptions({required String title, required List<String> options, required String selected, required Function(String) onSelect}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
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
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(color: isSelected ? Colors.deepOrange : Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                  child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w900)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionWithCounter({required String title, required int value, required Function(int) onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Row(
          children: List.generate(3, (index) {
            final isSelected = value == index;
            return GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Text(index == 0 ? 'НЕТ' : index.toString(), style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w900)),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  final String label; final TextEditingController controller; final VoidCallback onTap;
  const _AddressField({required this.label, required this.controller, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          children: [
            Icon(label == 'Откуда' ? Icons.radio_button_checked_rounded : Icons.location_on_rounded, color: label == 'Откуда' ? Colors.green : Colors.deepOrange, size: 20),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(controller.text.isEmpty ? 'Выбрать на карте' : controller.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.map_rounded, color: Colors.grey, size: 20),
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
      appBar: AppBar(
        title: const Text('Выберите адрес', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
                initialCenter: const LatLng(46.8410, 29.6470),
                initialZoom: 16,
                onTap: (_, latLng) => setState(() => selectedLatLng = latLng)
            ),
            children: [
              // ======= ОБНОВЛЕННЫЙ СВЕТЛЫЙ СЛОЙ (БЕЛЫЙ) =======
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (selectedLatLng != null) MarkerLayer(markers: [Marker(point: selectedLatLng!, width: 60, height: 60, child: const Icon(Icons.location_on_rounded, color: Colors.deepOrange, size: 55))]),
            ],
          ),
          if (selectedLatLng == null) Positioned(top: 20, left: 40, right: 40, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: const Text('Нажмите на карту', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)))),
          if (selectedLatLng != null) Positioned(bottom: 40, left: 24, right: 24, child: SizedBox(height: 64, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () => Navigator.pop(context, selectedLatLng), child: const Text('ПОДТВЕРДИТЬ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))),
        ],
      ),
    );
  }
}
