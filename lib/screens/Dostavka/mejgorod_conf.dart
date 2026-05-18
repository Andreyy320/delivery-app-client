import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MejGorodOrderConfirmationScreen extends StatefulWidget {
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
  final int routePrice;
  final int basePrice;

  const MejGorodOrderConfirmationScreen({
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
    required this.routePrice,
    required this.basePrice,
  });

  @override
  State<MejGorodOrderConfirmationScreen> createState() => _MejGorodOrderConfirmationScreenState();
}

class _MejGorodOrderConfirmationScreenState extends State<MejGorodOrderConfirmationScreen> {
  final MapController _mapController = MapController();
  List<LatLng> routePoints = [];
  bool isLoadingRoute = true;
  bool isSubmitting = false;

  final String orsKey = '5b3ce3597851110001cf6248bf7b24ca801246a5913cae76ef354218';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildRoute());
  }

  Future<void> _buildRoute() async {
    if (!mounted) return;
    setState(() => isLoadingRoute = true);

    final start = LatLng(widget.pickup['lat']!, widget.pickup['lng']!);
    final end = LatLng(widget.dropoff['lat']!, widget.dropoff['lng']!);

    bool success = await _fetchORS(start, end);
    if (!success) await _fetchOSRM(start, end);

    if (mounted && routePoints.isNotEmpty) {
      setState(() => isLoadingRoute = false);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(routePoints),
          padding: const EdgeInsets.all(50),
        ),
      );
    } else {
      if (mounted) setState(() => isLoadingRoute = false);
    }
  }

  Future<bool> _fetchORS(LatLng start, LatLng end) async {
    final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        if (mounted) {
          setState(() {
            routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          });
        }
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<void> _fetchOSRM(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        if (mounted) {
          setState(() {
            routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          });
        }
      }
    } catch (e) { debugPrint('OSRM Error: $e'); }
  }

  Future<void> _saveOrderToFirestore() async {
    setState(() => isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Пользователь не авторизован");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final orderData = {
        'fromAddress': widget.fromAddress,
        'toAddress': widget.toAddress,
        'pickup': GeoPoint(widget.pickup['lat']!, widget.pickup['lng']!),
        'dropoff': GeoPoint(widget.dropoff['lat']!, widget.dropoff['lng']!),
        'bodySize': widget.bodySize,
        'loaders': widget.loaders,
        'escort': widget.escort,
        'timeSelected': widget.timeSelected,
        'scheduledTime': widget.scheduledTime != null
            ? Timestamp.fromDate(widget.scheduledTime!)
            : null,
        'totalPrice': widget.totalPrice,
        'routePrice': widget.routePrice,
        'basePrice': widget.basePrice,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'new',
        'clientName': userData?['name'] ?? 'Без имени',
        'clientPhone': userData?['phone'] ?? '-',
        'userId': user.uid,
        'type': 'mejgorod',
      };

      final orderRef = await FirebaseFirestore.instance.collection('orders').add(orderData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mejCityOrders')
          .doc(orderRef.id)
          .set(orderData);

    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _formatTime() {
    if (!widget.timeSelected || widget.scheduledTime == null) return 'Как можно быстрее';
    final st = widget.scheduledTime!;
    final String hour = st.hour.toString().padLeft(2, '0');
    final String minute = st.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledDate = DateTime(st.year, st.month, st.day);
    final diff = scheduledDate.difference(today).inDays;

    String dayText;
    if (diff == 0) dayText = "Сегодня";
    else if (diff == 1) dayText = "Завтра";
    else if (diff == 2) dayText = "Послезавтра";
    else dayText = "${st.day.toString().padLeft(2, '0')}.${st.month.toString().padLeft(2, '0')}";

    return '$dayText, $hour:$minute';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text('Принято!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Ваш межгородской заказ создан.\nВодитель скоро свяжется с вами.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('ОТЛИЧНО', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Проверка межгорода', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Блок карты
              Container(
                height: 240,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(widget.pickup['lat']!, widget.pickup['lng']!),
                          initialZoom: 10,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                          if (routePoints.isNotEmpty)
                            PolylineLayer(polylines: [
                              Polyline(points: routePoints, color: Colors.deepOrange, strokeWidth: 5.0),
                            ]),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(widget.pickup['lat']!, widget.pickup['lng']!),
                              child: const Icon(Icons.radio_button_checked, color: Colors.green, size: 24),
                            ),
                            Marker(
                              point: LatLng(widget.dropoff['lat']!, widget.dropoff['lng']!),
                              child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 30),
                            ),
                          ]),
                        ],
                      ),
                      if (isLoadingRoute)
                        const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Блок адресов
              _containerWrapper(
                child: Column(
                  children: [
                    _buildRouteItem(Icons.radio_button_checked, Colors.green, 'ОТКУДА', widget.fromAddress),
                    _lineDivider(),
                    _buildRouteItem(Icons.location_on, Colors.deepOrange, 'КУДА', widget.toAddress),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Детали заказа
              _containerWrapper(
                child: Column(
                  children: [
                    _buildDetailRow(Icons.local_shipping_outlined, 'Размер кузова', '${widget.bodySize}'),
                    _divider(),
                    _buildDetailRow(Icons.groups_outlined, 'Грузчики', widget.loaders == 0 ? "Не нужны" : '${widget.loaders} чел.'),
                    _divider(),
                    _buildDetailRow(Icons.person_pin_outlined, 'Сопровождение', widget.escort == 0 ? "Нет" : '1 чел.'),
                    _divider(),
                    _buildDetailRow(Icons.access_time, 'Время отправления', _formatTime()),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Итого
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итого к оплате', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('${widget.totalPrice} Руб', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 25),
              // Кнопка подтверждения
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    elevation: 10,
                    shadowColor: Colors.deepOrange.withOpacity(0.3),
                  ),
                  onPressed: isSubmitting ? null : () async {
                    try {
                      await _saveOrderToFirestore();
                      if (mounted) _showSuccessDialog();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                        );
                      }
                    }
                  },
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ОФОРМИТЬ МЕЖГОРОД', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _containerWrapper({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: child,
    );
  }

  Widget _lineDivider() => Container(margin: const EdgeInsets.only(left: 8), alignment: Alignment.centerLeft, child: Container(width: 2, height: 15, color: Colors.grey[100]));
  Widget _divider() => Divider(height: 24, color: Colors.grey[100], thickness: 1.5);

  Widget _buildRouteItem(IconData icon, Color color, String label, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900)),
              Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey[400]),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}