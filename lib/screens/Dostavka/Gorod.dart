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
      backgroundColor: Colors.transparent, // Чтобы было видно скругление углов
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 420, // Немного увеличили для комфорта
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // 1. ИНДИКАТОР СВЕРХУ (Symmetry handle)
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Выберите время',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 20, color: Colors.black),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 2. ВЫБОР ВРЕМЕНИ (Cupertino Style)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          // Дни (даем больше места через Expanded flex)
                          Expanded(
                            flex: 2, // 🎯 Занимает 50% ширины ряда
                            child: _buildPicker(
                              initialItem: selectedDayIndex,
                              items: days.map((d) => d).toList(),
                              onChanged: (index) {
                                setModalState(() => selectedDayIndex = index);
                                setState(() => timeSelected = true);
                              },
                            ),
                          ),
                          // Часы
                          Expanded(
                            flex: 1, // 🎯 Занимает 25%
                            child: _buildPicker(
                              initialItem: selectedHour,
                              items: List.generate(24, (i) => '$i ч'),
                              onChanged: (index) {
                                setModalState(() => selectedHour = index);
                                setState(() => timeSelected = true);
                              },
                            ),
                          ),
                          // Минуты
                          Expanded(
                            flex: 1, // 🎯 Занимает 25%
                            child: _buildPicker(
                              initialItem: selectedMinute,
                              items: List.generate(60, (i) => '${i.toString().padLeft(2, '0')} м'), // Сократил "мин" до "м" для экономии места
                              onChanged: (index) {
                                setModalState(() => selectedMinute = index);
                                setState(() => timeSelected = true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Текущий выбор
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Выбрано: ${days[selectedDayIndex]}, ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. ТА САМАЯ КНОПКА
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ГОТОВО',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
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

// Вспомогательный метод для чистого кода пикера
  Widget _buildPicker({
    required int initialItem,
    required List<String> items,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 40,
      onSelectedItemChanged: onChanged,
      children: items.map((item) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox( // 🎯 Сжимает текст "Послезавтра", если он всё равно не влез
            fit: BoxFit.scaleDown,
            child: Text(
              item,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.deepOrange,
          elevation: 0,
          centerTitle: true,
          // Делаем иконку "Назад" белой
          iconTheme: const IconThemeData(color: Colors.black),
          title: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7, // Ограничиваем ширину, чтобы не наезжать на иконки
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Грузоперевозка по городу',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20, // Базовый размер, который будет сжиматься
                ),
              ),
            ),
          ),
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
                          'Детали подачи',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 22),
                        _AddressField(
                          label: 'Откуда',
                          controller: fromController,
                          onTap: () => _openMap(fromController),
                        ),
                        const SizedBox(height: 16),
                        _AddressField(
                          label: 'Куда',
                          controller: toController,
                          onTap: () => _openMap(toController),
                        ),
                        const SizedBox(height: 24),

                        // Блок времени
                        InkWell(
                          onTap: _showTimePickerSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: timeSelected ? Colors.orange.withOpacity(0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, color: timeSelected ? Colors.deepOrange : Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    timeSelected
                                        ? 'Время: ${days[selectedDayIndex]}, ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}'
                                        : 'Заказать ко времени',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: timeSelected ? FontWeight.bold : FontWeight.normal,
                                        color: timeSelected ? Colors.black : Colors.grey[700]
                                    ),
                                  ),
                                ),
                                if (timeSelected)
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                    onPressed: () => setState(() => timeSelected = false),
                                  )
                                else
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======= КРАСИВАЯ НИЖНЯЯ ПАНЕЛЬ =======
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), // Увеличен отступ снизу
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Итого к оплате:',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    Text(
                      '${_calculatePrice()} ₽',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
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
                              totalPrice: _calculatePrice(),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'ЗАКАЗАТЬ МАШИНУ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
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

  Widget _sectionWithCounter({
    required String title,
    required int value,
    required Function(int) onChanged
  }) {
    return Row(
      children: [
        // 🎯 Исправленная часть:
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown, // Сжимает текст, если он не влезает
            alignment: Alignment.centerLeft, // Прижимает к левому краю
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),

        const SizedBox(width: 8), // Небольшой зазор между текстом и кнопками

        // Твой блок с кнопками (0, 1, 2)
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
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }}

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
      appBar: AppBar(
        title: const Text('Выберите адрес',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        // Стрелочка назад теперь белая
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. КАРТА
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(46.8410, 29.6470),
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
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50,
                        shadows: [
                          Shadow(color: Colors.white, blurRadius: 10)
                        ], // Чтобы маркер выделялся
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. ПОДСКАЗКА СВЕРХУ (появляется, если адрес не выбран)
          if (selectedLatLng == null)
            Positioned(
              top: 20,
              left: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 10)
                  ],
                ),
                child: const Text(
                  'Нажмите на карту, чтобы выбрать место',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),

          // 3. ТА САМАЯ КНОПКА (появляется после тапа)
          if (selectedLatLng != null)
            Positioned(
              bottom: 30, // Чуть выше от края для удобства
              left: 20,
              right: 20,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white, // БЕЛЫЙ ТЕКСТ
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, selectedLatLng);
                  },
                  child: const Text(
                    'ПОДТВЕРДИТЬ ЭТОТ АДРЕС',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1
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
