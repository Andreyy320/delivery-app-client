import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ExpressOrderConfirmationScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final Set<String> options;
  final double totalCost;
  // Добавляем недостающие параметры:
  final double distanceKm;
  final int durationMin;

  const ExpressOrderConfirmationScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.options,
    required this.totalCost,
    required this.distanceKm,
    required this.durationMin,
  });

  @override
  State<ExpressOrderConfirmationScreen> createState() => _ExpressOrderConfirmationScreenState();
}

class _ExpressOrderConfirmationScreenState extends State<ExpressOrderConfirmationScreen> {
  List<LatLng> routePoints = [];
  bool isLoading = true;
  final MapController _mapController = MapController();

  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 50,
    'large': 100,
  };

  @override
  void initState() {
    super.initState();
    _getRoute();
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
          isLoading = false;
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
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Проверка заказа', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Column(
        children: [
          // КАРТА
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
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
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                        ),
                        if (routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                color: Colors.deepOrange,
                                strokeWidth: 5,
                                strokeCap: StrokeCap.round,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: widget.pickup,
                              width: 40, height: 40,
                              child: const Icon(Icons.circle, color: Colors.green, size: 18),
                            ),
                            Marker(
                              point: widget.dropoff,
                              width: 40, height: 40,
                              child: const Icon(Icons.location_on_rounded, color: Colors.deepOrange, size: 35),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isLoading)
                      Container(
                        color: Colors.white70,
                        child: const Center(child: CupertinoActivityIndicator(radius: 15)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ИНФОРМАЦИЯ
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text('ДЕТАЛИ ПУТИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildRouteInfoCard(),
                      const SizedBox(height: 24),
                      const Text('МАРШРУТ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildAddressCard(),
                      const SizedBox(height: 24),
                      const Text('УСЛУГИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: widget.options.isEmpty
                      ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('Стандартная экспресс-доставка', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600)),
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
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoColumn('РАССТОЯНИЕ', '${widget.distanceKm.toStringAsFixed(1)} км'),
          Container(width: 1, height: 30, color: Colors.blue.withOpacity(0.2)),
          _infoColumn('В ПУТИ', '~${widget.durationMin} мин'),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blue)),
    ]);
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        children: [
          _buildAddressRow(Icons.circle, Colors.green, 'ОТКУДА', widget.pickup, true),
          const SizedBox(height: 10),
          _buildAddressRow(Icons.location_on_rounded, Colors.deepOrange, 'КУДА', widget.dropoff, false),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String label, LatLng pos, bool showLine) {
    return Row(
      children: [
        Column(children: [
          Icon(icon, color: color, size: 16),
          if (showLine) Container(width: 2, height: 20, color: Colors.grey[100], margin: const EdgeInsets.symmetric(vertical: 4)),
        ]),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38)),
          Text('${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
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
        icon = Icons.inventory_2_rounded;
        break;
      case 'large':
        title = 'Крупные габариты';
        icon = Icons.straighten_rounded;
        break;
      default:
        title = optId;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.deepOrange),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Text('+$price Руб', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange)),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого к оплате', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              Text('${widget.totalCost.toInt()} Руб', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 65,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), elevation: 0),
              onPressed: isLoading ? null : () => Navigator.pop(context, true),
              child: const Text('ПОДТВЕРДИТЬ ЗАКАЗ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
