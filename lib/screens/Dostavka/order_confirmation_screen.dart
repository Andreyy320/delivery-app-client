import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ExpressOrderConfirmationScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final Set<String> options;
  final double totalCost;

  const ExpressOrderConfirmationScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.options,
    required this.totalCost,
  });

  @override
  State<ExpressOrderConfirmationScreen> createState() => _ExpressOrderConfirmationScreenState();
}

class _ExpressOrderConfirmationScreenState extends State<ExpressOrderConfirmationScreen> {
  List<LatLng> routePoints = [];
  bool isLoading = true;

  final Map<String, int> optionPrices = {
    'receiver_pay': 0,
    'fragile': 20,
    'large': 30,
  };

  @override
  void initState() {
    super.initState();
    _getRoute(); // Загружаем маршрут по дорогам при старте
  }

  // ФУНКЦИЯ ПОЛУЧЕНИЯ МАРШРУТА ПО ДОРОГАМ (OSRM)
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
      }
    } catch (e) {
      debugPrint("Ошибка получения маршрута: $e");
      setState(() {
        routePoints = [widget.pickup, widget.dropoff]; // Если ошибка, рисуем прямую
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Проверка заказа', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // КАРТА
          Expanded(
            flex: 3,
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
                                // Красивое скругление углов
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
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
                        color: Colors.white60,
                        child: const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ИНФОРМАЦИЯ О ЗАКАЗЕ
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('МАРШРУТ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38)),
                  const SizedBox(height: 12),
                  _buildAddressCard(),
                  const SizedBox(height: 24),
                  const Text('УСЛУГИ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38)),
                  const SizedBox(height: 12),
                  Expanded(child: _buildOptionsList()),
                ],
              ),
            ),
          ),

          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          _buildRow(Icons.circle, Colors.green, 'ОТКУДА', widget.pickup, true),
          _buildRow(Icons.location_on_rounded, Colors.deepOrange, 'КУДА', widget.dropoff, false),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, Color color, String label, LatLng pos, bool line) {
    return Row(
      children: [
        Column(children: [
          Icon(icon, color: color, size: 14),
          if (line) Container(width: 1, height: 20, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 4)),
        ]),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38)),
          Text('${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ],
    );
  }

  Widget _buildOptionsList() {
    if (widget.options.isEmpty) {
      return const Center(
        child: Text(
          'Дополнительных услуг нет',
          style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: widget.options.map((optId) {
        final price = optionPrices[optId] ?? 0;
        String title = '';
        IconData icon = Icons.check_circle_outline;

        // Мапим английские ID на русский текст и иконки
        switch (optId) {
          case 'receiver_pay':
            title = 'Оплатит получатель';
            icon = Icons.payment_rounded;
            break;
          case 'fragile':
            title = 'Хрупкий груз';
            icon = Icons.auto_awesome_rounded;
            break;
          case 'large':
            title = 'Крупные габариты';
            icon = Icons.straighten_rounded;
            break;
          default:
            title = optId; // На случай, если появится новый ID
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: Colors.deepOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Text(
                '+$price ₽',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого к оплате', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              Text('${widget.totalCost.toInt()} ₽', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ЗАКАЗАТЬ КУРЬЕРА', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}