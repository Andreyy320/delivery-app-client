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
  final int routePrice;
  final int basePrice;

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
    required this.routePrice,
    required this.basePrice,
  });

  @override
  State<GorodOrderConfirmationScreen> createState() => _GorodOrderConfirmationScreenState();
}

class _GorodOrderConfirmationScreenState extends State<GorodOrderConfirmationScreen> {
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
        'type': 'city',
      };

      final orderRef = await FirebaseFirestore.instance.collection('orders').add(orderData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cityOrders')
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
      builder: (BuildContext dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Заказ оформлен!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Мы получили ваши данные.\nВодитель скоро свяжется с вами.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'ОТЛИЧНО',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Проверка заказа',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
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
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Карта
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(widget.pickup['lat']!, widget.pickup['lng']!),
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                          if (routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  color: const Color(0xFFD97706),
                                  strokeWidth: 4.5,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(widget.pickup['lat']!, widget.pickup['lng']!),
                                width: 32,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                  ),
                                  child: const Icon(Icons.circle, color: Colors.white, size: 10),
                                ),
                              ),
                              Marker(
                                point: LatLng(widget.dropoff['lat']!, widget.dropoff['lng']!),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD97706).withOpacity(0.4),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isLoadingRoute)
                        Container(
                          color: Colors.white.withOpacity(0.6),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Блок маршрута
              _containerWrapper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'МАРШРУТ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildRouteItem(Icons.circle_outlined, const Color(0xFF0F172A), 'ОТКУДА', widget.fromAddress),
                    Padding(
                      padding: const EdgeInsets.only(left: 17),
                      child: Container(
                        height: 18,
                        width: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    _buildRouteItem(Icons.location_on_rounded, const Color(0xFFD97706), 'КУДА', widget.toAddress),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Блок деталей
              _containerWrapper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ДЕТАЛИ ДОСТАВКИ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildDetailRow(Icons.local_shipping_outlined, 'Тип кузова', 'Класс ${widget.bodySize}'),
                    _divider(),
                    _buildDetailRow(Icons.groups_outlined, 'Грузчики', widget.loaders == 0 ? "Не нужны" : '${widget.loaders} чел.'),
                    _divider(),
                    _buildDetailRow(Icons.access_time_rounded, 'Время подачи', _formatTime()),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Итоговая стоимость
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'К ОПЛАТЕ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Итоговая цена',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.totalPrice} Руб',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF78350F),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка подтверждения
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                    shadowColor: const Color(0xFFD97706).withOpacity(0.35),
                  ),
                  onPressed: isSubmitting ? null : () async {
                    try {
                      await _saveOrderToFirestore();
                      if (mounted) _showSuccessDialog();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка: $e', style: const TextStyle(fontWeight: FontWeight.w700)),
                            backgroundColor: const Color(0xFF0F172A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ПОДТВЕРДИТЬ ЗАКАЗ',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _containerWrapper({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
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
      ),
      child: child,
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
  );

  Widget _buildRouteItem(IconData icon, Color color, String label, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              const SizedBox(height: 1),
              Text(
                text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 14),
        ),
      ],
    );
  }
}