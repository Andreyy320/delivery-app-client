import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class ExpressOrderConfirmationScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final Set<String> options;
  final double totalCost;
  final double distanceKm;
  final int durationMin;
  final String initialComment;
  final String initialReceiverName;
  final String initialReceiverPhone;
  final String subType; // Тип заказа (например: 'buy', 'pickup', 'task')
  final String transport; // Выбранный транспорт ('scooter', 'car')

  const ExpressOrderConfirmationScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.options,
    required this.totalCost,
    required this.distanceKm,
    required this.durationMin,
    this.initialComment = '',
    this.initialReceiverName = '',
    this.initialReceiverPhone = '',
    required this.subType,
    required this.transport,
  });

  @override
  State<ExpressOrderConfirmationScreen> createState() => _ExpressOrderConfirmationScreenState();
}

class _ExpressOrderConfirmationScreenState extends State<ExpressOrderConfirmationScreen> {
  List<LatLng> routePoints = [];
  bool isLoadingRoute = true;
  bool isSubmittingOrder = false;
  final MapController _mapController = MapController();

  late final TextEditingController _commentController;
  late final TextEditingController _receiverNameController;
  late final TextEditingController _receiverPhoneController;

  String _pickupAddress = 'Определяем адрес отправления...';
  String _dropoffAddress = 'Определяем адрес назначения...';
  bool _isLoadingAddresses = true;

  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 50,
    'large': 100,
  };

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.initialComment);
    _receiverNameController = TextEditingController(text: widget.initialReceiverName);
    _receiverPhoneController = TextEditingController(text: widget.initialReceiverPhone);

    _getRoute();
    _resolveAddresses();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    super.dispose();
  }

  Future<void> _getRoute() async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${widget.pickup.longitude},${widget.pickup.latitude};'
          '${widget.dropoff.longitude},${widget.dropoff.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          isLoadingRoute = false;
        });

        if (routePoints.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routePoints),
                padding: const EdgeInsets.all(50),
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка получения маршрута: $e");
      setState(() {
        routePoints = [widget.pickup, widget.dropoff];
        isLoadingRoute = false;
      });
    }
  }

  Future<String> _fetchAddress(LatLng latLng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=ru&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterAppDeliveryOrder/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          String road = address['road'] ?? address['pedestrian'] ?? address['street'] ?? address['path'] ?? '';
          String houseNumber = address['house_number'] ?? address['building'] ?? '';
          String suburb = address['suburb'] ?? address['neighbourhood'] ?? address['city_district'] ?? '';
          String city = address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'] ?? address['county'] ?? '';

          List<String> parts = [];
          if (road.isNotEmpty) {
            if (houseNumber.isNotEmpty) {
              parts.add('$road, $houseNumber');
            } else {
              parts.add(road);
            }
          } else if (suburb.isNotEmpty) {
            parts.add(suburb);
          }

          if (city.isNotEmpty && !parts.contains(city)) {
            parts.add(city);
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          } else {
            String rawName = data['display_name'] ?? '';
            List<String> splitName = rawName.split(', ');
            if (splitName.length > 3) splitName.removeLast();
            return splitName.isNotEmpty ? splitName.join(', ') : '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка геокодинга: $e');
    }
    return '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
  }

  Future<void> _resolveAddresses() async {
    final pickupRes = await _fetchAddress(widget.pickup);
    final dropoffRes = await _fetchAddress(widget.dropoff);

    if (mounted) {
      setState(() {
        _pickupAddress = pickupRes;
        _dropoffAddress = dropoffRes;
        _isLoadingAddresses = false;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (widget.options.contains('receiver_pay')) {
      if (_receiverNameController.text.trim().isEmpty || _receiverPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пожалуйста, укажите имя и номер телефона получателя'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      isSubmittingOrder = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'guest_user';

      String clientName = 'Не указано';
      String clientPhone = 'Не указано';

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          clientName = userData['name'] ??
              userData['fullName'] ??
              userData['userName'] ??
              userData['displayName'] ??
              user.displayName ??
              'Не указано';

          clientPhone = userData['phone'] ??
              userData['phoneNumber'] ??
              userData['tel'] ??
              userData['mobile'] ??
              user.phoneNumber ??
              'Не указано';
        }
      }

      final Map<String, dynamic> orderData = {
        'pickup': {
          'lat': widget.pickup.latitude,
          'lon': widget.pickup.longitude,
          'address': _pickupAddress,
        },
        'dropoff': {
          'lat': widget.dropoff.latitude,
          'lon': widget.dropoff.longitude,
          'address': _dropoffAddress,
        },
        'options': widget.options.toList(),
        'total_cost': widget.totalCost,
        'distance_km': widget.distanceKm,
        'duration_min': widget.durationMin,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'new',
        'userId': userId,
        'clientId': userId,
        'clientName': clientName,
        'name': clientName,
        'clientPhone': clientPhone,
        'phone': clientPhone,
        'type': 'delivery',
        'subType': widget.subType,
        'transport': widget.transport,
      };

      if (_receiverNameController.text.trim().isNotEmpty || _receiverPhoneController.text.trim().isNotEmpty) {
        orderData['receiver'] = {
          'name': _receiverNameController.text.trim(),
          'phone': _receiverPhoneController.text.trim(),
        };
        orderData['receiverName'] = _receiverNameController.text.trim();
        orderData['receiverPhone'] = _receiverPhoneController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('delivery_orders')
          .add(orderData);

      if (!mounted) return;
      _showSuccessAndNavigate();

    } catch (e) {
      debugPrint('Ошибка сохранения в Firestore: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось создать заказ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmittingOrder = false;
        });
      }
    }
  }

  void _showSuccessAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFF10B981),
              child: Icon(Icons.check, color: Colors.white, size: 36),
            ),
            SizedBox(height: 20),
            Text(
              'Заказ успешно создан!',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Курьер уже назначается на ваш заказ.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('На главную', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Проверка заказа',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.28,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: widget.pickup,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
                          ),
                          if (routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  color: const Color(0xFF6366F1),
                                  strokeWidth: 4.0,
                                  strokeCap: StrokeCap.round,
                                  strokeJoin: StrokeJoin.round,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.pickup,
                                width: 28,
                                height: 28,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Marker(
                                point: widget.dropoff,
                                width: 32,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isLoadingRoute)
                        Container(
                          color: Colors.white.withValues(alpha: 0.85),
                          child: const Center(
                            child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFD97706)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 8),
                        _buildSectionHeader('ДЕТАЛИ ПУТИ'),
                        const SizedBox(height: 12),
                        _buildRouteInfoCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('МАРШРУТ'),
                        const SizedBox(height: 12),
                        _buildAddressCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('ДАННЫЕ ПОЛУЧАТЕЛЯ'),
                        const SizedBox(height: 12),
                        _buildReceiverCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('ЧТО ВЕЗЕМ?'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: 2,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Добавьте комментарий для курьера или описание посылки...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 24),
                                child: Icon(Icons.inventory_2_outlined, color: Color(0xFFD97706), size: 22),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('ВЫБРАННЫЕ УСЛУГИ'),
                        const SizedBox(height: 12),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: widget.options.isEmpty
                        ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: Color(0xFF64748B), size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Стандартная доставка',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        : SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildOptionItem(widget.options.elementAt(index)),
                        childCount: widget.options.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
            _buildBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoColumn('РАССТОЯНИЕ', '${widget.distanceKm.toStringAsFixed(1)} км'),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
          _infoColumn('В ПУТИ', '~${widget.durationMin} мин.'),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAddressRow(
            Icons.my_location_rounded,
            const Color(0xFF0284C7),
            'ОТКУДА',
            _pickupAddress,
            true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildAddressRow(
            Icons.location_on_rounded,
            const Color(0xFFD97706),
            'КУДА',
            _dropoffAddress,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _receiverNameController,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Имя получателя',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFD97706), size: 22),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiverPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Номер телефона получателя',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFD97706), size: 22),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String label, String addressText, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              _isLoadingAddresses
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                ),
              )
                  : Text(
                addressText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionItem(String optId) {
    final price = optionPrices[optId] ?? 0;
    String title = '';
    IconData icon = Icons.check_circle_outline;

    switch (optId) {
      case 'receiver_pay':
        title = 'Оплатит получатель';
        icon = Icons.account_balance_wallet_rounded;
        break;
      case 'fragile':
        title = 'Хрупкий груз';
        icon = Icons.warning_amber_rounded;
        break;
      case 'large':
        title = 'Крупногабаритный груз';
        icon = Icons.local_shipping_rounded;
        break;
      default:
        title = optId;
        icon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (price > 0)
            Text(
              '+$price Руб',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFFD97706),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ИТОГО К ОПЛАТЕ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.totalCost.toStringAsFixed(0)} Руб',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    shadowColor: const Color(0xFFD97706).withValues(alpha: 0.4),
                  ),
                  onPressed: isSubmittingOrder ? null : _submitOrder,
                  child: isSubmittingOrder
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text(
                    'Заказать',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}