import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GorodOrderConfirmationScreen extends StatefulWidget {
  final String fromAddress;
  final String toAddress;
  final Map<String, double> pickup;
  final Map<String, double> dropoff;
  final String bodySize;
  final int loaders;
  final int escort;
  final bool timeSelected;
  final DateTime? scheduledTime;
  final int totalPrice;

  const GorodOrderConfirmationScreen({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.pickup,
    required this.dropoff,
    required this.bodySize,
    required this.loaders,
    required this.escort,
    required this.timeSelected,
    required this.scheduledTime,
    required this.totalPrice,
  });

  @override
  State<GorodOrderConfirmationScreen> createState() => _GorodOrderConfirmationScreenState();
}

class _GorodOrderConfirmationScreenState extends State<GorodOrderConfirmationScreen> {
  final MapController _mapController = MapController();
  List<LatLng> routePoints = [];
  bool isLoadingRoute = true;
  // Твой ключ OpenRouteService
  final String orsKey = '5b3ce3597851110001cf6248bf7b24ca801246a5913cae76ef354218';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildRoute());
  }

  Future<void> _buildRoute() async {
    setState(() => isLoadingRoute = true);

    final start = LatLng(widget.pickup['lat']!, widget.pickup['lng']!);
    final end = LatLng(widget.dropoff['lat']!, widget.dropoff['lng']!);

    bool success = await _fetchORS(start, end);
    if (!success) await _fetchOSRM(start, end);

    if (mounted) {
      setState(() => isLoadingRoute = false);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([start, end]),
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  Future<bool> _fetchORS(LatLng start, LatLng end) async {
    final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
    try {
      final r = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'GorodApp/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final coords = json.decode(r.body)['features'][0]['geometry']['coordinates'] as List;
        setState(() => routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList());
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<void> _fetchOSRM(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    try {
      final r = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'GorodApp/1.0'},
      );
      if (r.statusCode == 200) {
        final coords = json.decode(r.body)['routes'][0]['geometry']['coordinates'] as List;
        setState(() => routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList());
      }
    } catch (e) { debugPrint('$e'); }
  }

  Future<void> _saveOrderToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Пользователь не авторизован");

      // Получаем данные пользователя для формирования заказа
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final orderData = {
        'fromAddress': widget.fromAddress,
        'toAddress': widget.toAddress,
        'pickup': widget.pickup,
        'dropoff': widget.dropoff,
        'bodySize': widget.bodySize,
        'loaders': widget.loaders,
        'escort': widget.escort,
        'timeSelected': widget.timeSelected,
        'scheduledTime': widget.scheduledTime != null
            ? Timestamp.fromDate(widget.scheduledTime!)
            : null,
        'totalPrice': widget.totalPrice,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'new',
        'clientName': userData?['name'] ?? 'Без имени',
        'clientPhone': userData?['phone'] ?? '-',
        'userId': user.uid,
        'type': 'city',
      };

      // Сохраняем ТОЛЬКО в подколлекцию пользователя
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cityOrders')
          .add(orderData);

      print("Заказ успешно сохранен в профиль пользователя");
    } catch (e) {
      print("Ошибка при сохранении заказа: $e");
      // Здесь можно выкинуть ошибку дальше, чтобы показать SnackBar в UI
      rethrow;
    }
  }

  // Функция для красивого отображения времени
  String _formatTime() {
    if (!widget.timeSelected || widget.scheduledTime == null) {
      return 'Как можно быстрее';
    }

    final st = widget.scheduledTime!;
    final String hour = st.hour.toString().padLeft(2, '0');
    final String minute = st.minute.toString().padLeft(2, '0');
    final now = DateTime.now();

    String dayText = "${st.day.toString().padLeft(2, '0')}.${st.month.toString().padLeft(2, '0')}";

    // Сравниваем только даты
    DateTime onlyDateST = DateTime(st.year, st.month, st.day);
    DateTime onlyDateNow = DateTime(now.year, now.month, now.day);
    int diff = onlyDateST.difference(onlyDateNow).inDays;

    if (diff == 0) dayText = "Сегодня";
    else if (diff == 1) dayText = "Завтра";
    else if (diff == 2) dayText = "Послезавтра";

    return '$dayText, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Проверка заказа', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(widget.pickup['lat']!, widget.pickup['lng']!),
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.example.gorod_app',
                          ),
                          if (routePoints.isNotEmpty)
                            PolylineLayer(polylines: [
                              Polyline(
                                points: routePoints,
                                color: Colors.deepOrange,
                                strokeWidth: 5.0,
                              )
                            ]),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(widget.pickup['lat']!, widget.pickup['lng']!),
                              width: 30, height: 30,
                              child: const Icon(Icons.radio_button_checked, color: Colors.green, size: 25),
                            ),
                            Marker(
                              point: LatLng(widget.dropoff['lat']!, widget.dropoff['lng']!),
                              width: 30, height: 30,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                            ),
                          ]),
                        ],
                      ),
                      if (isLoadingRoute)
                        Container(
                          color: Colors.white.withOpacity(0.5),
                          child: const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  children: [
                    _buildRouteItem(Icons.radio_button_checked, Colors.green, 'ОТКУДА', widget.fromAddress),
                    Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Align(alignment: Alignment.centerLeft, child: Container(width: 1.5, height: 20, color: Colors.grey[100])),
                    ),
                    _buildRouteItem(Icons.location_on, Colors.deepOrange, 'КУДА', widget.toAddress),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              const Text('  Детали перевозки', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.local_shipping, 'Кузов', widget.bodySize),
                    _divider(),
                    _buildDetailRow(Icons.groups, 'Грузчики', widget.loaders == 0 ? "Нет" : '${widget.loaders} чел.'),
                    _divider(),
                    _buildDetailRow(Icons.watch_later, 'Время', _formatTime()), // Используем новую функцию
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итоговая цена', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('${widget.totalPrice} ₽', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                    shadowColor: Colors.deepOrange.withOpacity(0.4),
                  ),
                  onPressed: () async {
                    try {
                      await _saveOrderToFirestore();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                    }
                  },
                  child: const Text('ПОДТВЕРДИТЬ ЗАКАЗ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 20, color: Colors.grey[200]);

  Widget _buildRouteItem(IconData icon, Color color, String label, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepOrange),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}
