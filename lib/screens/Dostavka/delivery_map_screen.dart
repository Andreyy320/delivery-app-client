import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CourierScreenOSM extends StatefulWidget {
  const CourierScreenOSM({Key? key}) : super(key: key);

  @override
  State<CourierScreenOSM> createState() => _CourierScreenOSMState();
}

class _CourierScreenOSMState extends State<CourierScreenOSM> {
  LatLng? pickup;
  LatLng? dropoff;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите маршрут')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(47.0104, 28.8638),
              initialZoom: 13,
              onTap: (tapPosition, latLng) {
                setState(() {
                  if (pickup == null) {
                    pickup = latLng;
                  } else if (dropoff == null) {
                    dropoff = latLng;
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  if (pickup != null)
                    Marker(
                      point: pickup!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                    ),
                  if (dropoff != null)
                    Marker(
                      point: dropoff!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: (pickup != null && dropoff != null)
                  ? () {
                Navigator.pop(context, {
                  'pickup': pickup,
                  'dropoff': dropoff,
                });
              }
                  : null,
              child: const Text('Подтвердить маршрут'),
            ),
          ),
        ],
      ),
    );
  }
}
