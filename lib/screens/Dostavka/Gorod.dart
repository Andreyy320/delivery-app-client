import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'gorod_conf.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Грузоперевозка',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const CityCargoDetailsScreen(),
    );
  }
}

class CityCargoDetailsScreen extends StatefulWidget {
  const CityCargoDetailsScreen({super.key});

  @override
  State<CityCargoDetailsScreen> createState() =>
      _CityCargoDetailsScreenState();
}

class _CityCargoDetailsScreenState extends State<CityCargoDetailsScreen> {
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

  // ======= РАСЧЁТ ЦЕНЫ =======
  int _calculatePrice() {
    int price = 0;

    switch (selectedBody) {
      case 'S':
        price = 300;
        break;
      case 'M':
        price = 450;
        break;
      case 'L':
        price = 600;
        break;
      case 'XL':
        price = 800;
        break;
      case 'XXL':
        price = 1100;
        break;
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
      controller.text =
      'Ш: ${result.latitude.toStringAsFixed(5)}, Д: ${result.longitude.toStringAsFixed(5)}';
    }
  }

  void _showTimePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 350,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Выберите время',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController:
                            FixedExtentScrollController(initialItem: selectedDayIndex),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedDayIndex = index);
                              setState(() => timeSelected = true);
                            },
                            children: days.map((d) => Center(child: Text(d))).toList(),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController:
                            FixedExtentScrollController(initialItem: selectedHour),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedHour = index);
                              setState(() => timeSelected = true);
                            },
                            children: List.generate(24, (index) => Center(child: Text('$index ч'))),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController:
                            FixedExtentScrollController(initialItem: selectedMinute),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedMinute = index);
                              setState(() => timeSelected = true);
                            },
                            children: List.generate(
                                60, (index) => Center(child: Text('$index мин'))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Выбрано: ${days[selectedDayIndex]}, ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ДАЛЕЕ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text(
          'Грузоперевозка по городу',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _vehicleCard(),
                  const SizedBox(height: 20),
                  _containerBlock(
                    child: Column(
                      children: [
                        _sectionWithOptions(
                          title: 'Кузов',
                          options: bodySizes,
                          selected: selectedBody,
                          onSelect: (v) => setState(() => selectedBody = v),
                        ),
                        _divider(),
                        _sectionWithCounter(
                          title: 'Грузчики',
                          value: loaders,
                          onChanged: (v) => setState(() => loaders = v),
                        ),
                        _divider(),
                        _sectionWithCounter(
                          title: 'Сопровождающий',
                          value: escort,
                          onChanged: (v) => setState(() => escort = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _containerBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Подача',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 22),
                        _AddressField(
                          label: 'Откуда',
                          controller: fromController,
                          onTap: () => _openMap(fromController),
                        ),
                        const SizedBox(height: 22),
                        _AddressField(
                          label: 'Куда',
                          controller: toController,
                          onTap: () => _openMap(toController),
                        ),
                        const SizedBox(height: 35),
                        GestureDetector(
                          onTap: _showTimePickerSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Заказать по времени',
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: timeSelected
                                      ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.deepOrange,
                                  )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (timeSelected)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                timeSelected = false;
                              });
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Отменить заказ по времени'),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          timeSelected
                              ? 'Выбрано: ${days[selectedDayIndex]}, ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}'
                              : 'Время не выбрано',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ======= БЛОК СТОИМОСТИ ВНИЗУ =======
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Стоимость',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_calculatePrice()} ₽',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // Формируем scheduledTime, если выбрано
              DateTime? scheduledTimeValue = timeSelected
                  ? DateTime.now()
                  .add(Duration(days: selectedDayIndex))
                  .copyWith(hour: selectedHour, minute: selectedMinute)
                  : null;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GorodOrderConfirmationScreen(
                    fromAddress: fromController.text,
                    toAddress: toController.text,
                    bodySize: selectedBody,
                    loaders: loaders,
                    escort: escort,
                    timeSelected: timeSelected,
                    scheduledTime: scheduledTimeValue,
                    totalPrice: _calculatePrice(), // <-- вот здесь добавили цену
                  ),
                ),
              );
            },
            child: const Text(
              'Заказать',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),


    );
  }

  // ======= ВИДЖЕТЫ =======
  Widget _vehicleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: AssetImage(bodyImages[selectedBody]!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            bodyDescriptions[selectedBody]!,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _containerBlock({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: child,
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        color: Colors.grey[300],
        thickness: 1,
      ),
    );
  }

  Widget _sectionWithOptions({
    required String title,
    required List<String> options,
    required String selected,
    required Function(String) onSelect,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        Row(
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepOrange : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _sectionWithCounter({required String title, required int value, required Function(int) onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        Row(
          children: List.generate(3, (index) {
            final isSelected = value == index;
            return GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepOrange : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  index == 0 ? 'НЕТ' : index.toString(),
                  style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ======= Экран выбора локации =======
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
      appBar: AppBar(title: const Text('Выберите адрес'), backgroundColor: Colors.deepOrange),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(46.8410, 29.6470),
              initialZoom: 16,
              onTap: (tapPosition, latLng) {
                setState(() {
                  selectedLatLng = latLng;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          if (selectedLatLng != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                onPressed: () {
                  Navigator.pop(context, selectedLatLng);
                },
                child: const Text('Выбрать этот адрес'),
              ),
            ),
        ],
      ),
    );
  }
}

// ======= Поле адреса =======
class _AddressField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _AddressField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: const Icon(Icons.location_on),
      ),
    );
  }
}
