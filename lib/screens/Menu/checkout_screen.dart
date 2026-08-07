import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path; // 👈 Скрыли Path, чтобы не было конфликта
import '../../Api_Servicess.dart'; // Сервисный класс с API
import '../../models/Search_Address.dart';
import '../../models/order_model.dart';
import 'Cart_data.dart';

// ============================================================================
// ЭКРАН ОФОРМЛЕНИЯ ЗАКАЗА И ВЫБОРА АДРЕСА НА КАРТЕ
// ============================================================================
class CheckoutScreen extends StatefulWidget {
  final String shopId;
  final Function(Order)? onOrderPlaced;
  final String restaurantName;
  final String apiToken; // Токен для запросов к api.99993.ru
  final int groupId; // ID службы/груп группы доставки
  final double productsTotal;
  final List<CartItem> cartItems;
  // 🔹 КООРДИНАТЫ РЕСТОРАНА (поддерживаются как double 46.83, так и микроградусы int 46838444)
  final double restaurantLat;
  final double restaurantLng;

  const CheckoutScreen({
    super.key,
    required this.shopId,
    this.onOrderPlaced,
    required this.restaurantName,
    required this.apiToken,
    required this.cartItems,
    required this.productsTotal,
    required this.restaurantLat,
    required this.restaurantLng,
    this.groupId = 1,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

// ============================================================================
// СОСТОЯНИЕ ЭКРАНА С ЛОГИКОЙ КАРТЫ И АДРЕСНОГО СЕРВИСА
// ============================================================================
class _CheckoutScreenState extends State<CheckoutScreen> {
  // --- КОНТРОЛЛЕР КАРТЫ ---
  final MapController _mapController = MapController();

  // --- КООРДИНАТЫ ЦЕНТРА КАРТЫ (Адрес доставки) ---
  LatLng _currentCenter = const LatLng(46.8410, 29.6470);

  // --- ДАННЫЕ АДРЕСА РЕСТОРАНА ИЗ API ---
  int? _restaurantAddressId;
  bool _isLocatingRestaurant = true;

  // --- СОСТОЯНИЕ GPS И ОПРЕДЕЛЕНИЯ ГЕОПОЗИЦИИ ---
  bool _isGettingLocation = false;

  // --- ПОЗИЦИЯ МЕТКИ РЕСТОРАНА ДЛЯ КАРТЫ (стандартные double) ---
  late LatLng _restaurantMapLatLng;

  // --- СОСТОЯНИЕ АДРЕСА ДОСТАВКИ ИЗ МЕТКИ НА КАРТЕ ---
  Map<String, dynamic>? _mapAddressData;
  bool _isLoadingMapAddress = false;
  Timer? _mapDebounceTimer;

  // --- СОСТОЯНИЕ АДРЕСА ИЗ РУЧНОГО ПОИСКА ---
  Map<String, dynamic>? _selectedAddressData;

  // --- СОСТОЯНИЕ МАРШРУТА И СТОИМОСТИ ---
  List<LatLng> _routePoints = [];
  Map<String, dynamic>? _routeData;
  bool _isCalculatingRoute = false;

  // 🔹 --- ПОЛЯ ДЛЯ ПОДЪЕЗДА, ЭТАЖА И КВАРТИРЫ ---
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _intercomController = TextEditingController();

  // 🔹 --- ПОЛЕ ДЛЯ КОММЕНТАРИЯ К ЗАВЕДЕНИЮ ---
  final TextEditingController _commentController = TextEditingController();

  // 🔹 --- ВАРИАНТЫ И ВЫБРАННЫЙ СПОСОБ ОПЛАТЫ ---
  final List<Map<String, dynamic>> paymentOptions = [
    {'id': 'online', 'label': 'Онлайн', 'icon': Icons.payment_rounded},
    {'id': 'cash', 'label': 'Наличными', 'icon': Icons.payments_outlined},
    {'id': 'card', 'label': 'Клевер', 'icon': Icons.credit_card_rounded},
    {'id': 'qr', 'label': 'QR-код', 'icon': Icons.qr_code_scanner_rounded},
  ];
  String _selectedPaymentMethod = 'online';

  // --- ИНИЦИАЛИЗАЦИЯ СОСТОЯНИЯ ---
  @override
  void initState() {
    super.initState();

    // Преобразуем координаты ресторана для отображения маркерного знака на карте
    final double mapLat = widget.restaurantLat.abs() > 90
        ? widget.restaurantLat / 1000000.0
        : widget.restaurantLat;
    final double mapLng = widget.restaurantLng.abs() > 180
        ? widget.restaurantLng / 1000000.0
        : widget.restaurantLng;

    _restaurantMapLatLng = LatLng(mapLat, mapLng);

    debugPrint('=====================================================');
    debugPrint('🚀 [DEBUG CHECKOUT] Старт экрана оформления');
    debugPrint('📍 Сырые координаты ресторана из параметров: lat=${widget
        .restaurantLat}, lng=${widget.restaurantLng}');
    debugPrint('📍 Координаты ресторана для карты: $_restaurantMapLatLng');
    debugPrint('=====================================================');

    // ⚡ БЫСТРЫЙ ПАРАЛЛЕЛЬНЫЙ СТАРТ ИНИЦИАЛИЗАЦИИ
    _fastInitScreen();
  }

  // --- ОСВОБОЖДЕНИЕ РЕСУРСОВ ---
  @override
  void dispose() {
    _mapDebounceTimer?.cancel();
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _intercomController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // ============================================================================
  // ⚡ УСКОРЕННАЯ ИНИЦИАЛИЗАЦИЯ (Параллельные запросы + Fast GPS)
  // ============================================================================
  Future<void> _fastInitScreen() async {
    await Future.wait([
      _initRestaurantAddressOnly(),
      _determineFastPosition(),
    ]);

    if (mounted) {
      _fetchAddressFromCoordinates(_currentCenter);
    }
  }







  double _calculateDeliveryPrice() {
    double taximeterPrice = 0.0;
    if (_routeData != null) {
      if (_routeData!['price'] != null) {
        taximeterPrice = double.tryParse(_routeData!['price'].toString()) ?? 0.0;
      } else if (_routeData!['cost'] != null) {
        taximeterPrice = double.tryParse(_routeData!['cost'].toString()) ?? 0.0;
      } else if (_routeData!['distance'] != null) {
        final dist = _routeData!['distance'];
        double distanceKm = dist is int ? dist / 1000.0 : (dist is double ? dist : 0.0);
        taximeterPrice = 18.0 + (distanceKm * 6.15);
      }
    }

    double deliveryPrice = taximeterPrice < 45.0 ? 45.0 : taximeterPrice;

    int totalItemsCount = 0;
    for (var item in widget.cartItems) {
      totalItemsCount += item.quantity;
    }

    if (totalItemsCount > 3) {
      deliveryPrice += (totalItemsCount - 3) * 5.0;
    }

    if (_apartmentController.text.trim().isNotEmpty) {
      deliveryPrice += 5.0;
    }

    return deliveryPrice;
  }






  // ============================================================================
  // ЛОГИКА БЫСТРОГО ОПРЕДЕЛЕНИЯ GPS (Работает со спутниками телефона, не по IP!)
  // ============================================================================
  Future<void> _determineFastPosition() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // 1. Сначала пробуем взять кэш (последнюю известную позицию) для мгновенного отклика
      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final LatLng cachedLatLng = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentCenter = cachedLatLng;
          _selectedAddressData = null;
        });
        _mapController.move(cachedLatLng, 16.5);
        _fetchAddressFromCoordinates(cachedLatLng);
      }

      // 2. Параллельно запрашиваем точные свежие координаты со спутников (GPS / ГЛОНАСС)
      final Position freshPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );

      final LatLng freshLatLng = LatLng(freshPosition.latitude, freshPosition.longitude);

      if (mounted) {
        setState(() {
          _currentCenter = freshLatLng;
          _selectedAddressData = null; // Сбрасываем ручной ввод
        });
        _mapController.move(freshLatLng, 16.5);

        // ⚡ ЭТО ОБЯЗАТЕЛЬНО: отправляем свежий GPS на бэкенд, чтобы получить ID адреса и нарисовать маршрут!
        await _fetchAddressFromCoordinates(freshLatLng);
      }
    } catch (e) {
      debugPrint('💥 [DEBUG GPS] Ошибка при определении GPS: $e');
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  // ============================================================================
  // ТОЛЬКО ОПРЕДЕЛЕНИЕ ADDRESS_ID РЕСТОРАНА
  // ============================================================================
  Future<void> _initRestaurantAddressOnly() async {
    setState(() => _isLocatingRestaurant = true);

    try {
      final int latInt = widget.restaurantLat.abs() > 90
          ? widget.restaurantLat.toInt()
          : (widget.restaurantLat * 1000000).round();

      final int lonInt = widget.restaurantLng.abs() > 180
          ? widget.restaurantLng.toInt()
          : (widget.restaurantLng * 1000000).round();

      final restaurantData = await AddressApiService.locateAddress(
        latInt,
        lonInt,
        widget.apiToken,
      );

      if (mounted && restaurantData != null && restaurantData['id'] != null) {
        _restaurantAddressId = restaurantData['id'] is int
            ? restaurantData['id']
            : int.parse(restaurantData['id'].toString());
      }
    } catch (e) {
      debugPrint('💥 [DEBUG RESTAURANT] Ошибка поиска ресторана: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocatingRestaurant = false);
      }
    }
  }

  // ============================================================================
  // ЛОГИКА ОБРАБОТКИ ДВИЖЕНИЯ КАРТЫ И ТАЙМЕРА (ДЕБАУНС)
  // ============================================================================
  void _onMapPositionChanged(LatLng center, bool hasGesture) {
    if (!hasGesture) return;

    setState(() {
      _currentCenter = center;
      _isLoadingMapAddress = true;
      _selectedAddressData = null;
      _routePoints = [];
      _routeData = null;
    });

    _mapDebounceTimer?.cancel();
    _mapDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchAddressFromCoordinates(center);
    });
  }

  // ============================================================================
  // СЕТЕВОЙ ЗАПРОС К API ДЛЯ ОПРЕДЕЛЕНИЯ АДРЕСА ПО КООРДИНАТАМ КАРТЫ
  // ============================================================================
  Future<void> _fetchAddressFromCoordinates(LatLng latLng) async {
    try {
      final int mapLatInt = (latLng.latitude * 1000000).round();
      final int mapLonInt = (latLng.longitude * 1000000).round();

      final addressResult = await AddressApiService.locateAddress(
        mapLatInt,
        mapLonInt,
        widget.apiToken,
      );

      if (mounted) {
        setState(() {
          _mapAddressData = addressResult;
        });

        if (addressResult != null && addressResult['id'] != null) {
          final int destinationAddressId = addressResult['id'] is int
              ? addressResult['id']
              : int.parse(addressResult['id'].toString());

          if (_restaurantAddressId != null) {
            _calculateRoute(destinationAddressId);
          }
        }
      }
    } catch (e) {
      debugPrint('💥 [DEBUG MAP_POINT] Ошибка locateAddress: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMapAddress = false;
        });
      }
    }
  }

  // ============================================================================
  // СЕТЕВОЙ ЗАПРОС РАСЧЕТА МАРШРУТА (/v1/getRoute)
  // ============================================================================
  Future<void> _calculateRoute(int destinationAddressId) async {
    if (_restaurantAddressId == null) return;

    setState(() => _isCalculatingRoute = true);

    try {
      final List<int> addressPair = [
        _restaurantAddressId!,
        destinationAddressId
      ];

      final routeResult = await AddressApiService.getRoute(
        groupId: widget.groupId,
        addressIds: addressPair,
        time: 0,
      );

      if (mounted && routeResult != null) {
        final String? geometry = routeResult['geometry']?.toString();
        List<LatLng> points = [];

        if (geometry != null && geometry.isNotEmpty) {
          points = _decodePolyline(geometry);
        }

        setState(() {
          _routeData = routeResult;
          _routePoints = points;
        });
      }
    } catch (e) {
      debugPrint('💥 [DEBUG ROUTE] Ошибка getRoute: $e');
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  // ============================================================================
  // ДЕКОДЕР СТРОКИ GEOMETRY (Encoded Polyline)
  // ============================================================================
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0,
        len = encoded.length;
    int lat = 0,
        lng = 0;

    try {
      while (index < len) {
        int b,
            shift = 0,
            result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        double calcLat = lat / 1E5;
        double calcLng = lng / 1E5;

        while (calcLat.abs() > 90.0) {
          calcLat /= 10.0;
        }
        while (calcLng.abs() > 180.0) {
          calcLng /= 10.0;
        }

        points.add(LatLng(calcLat, calcLng));
      }
    } catch (e) {
      debugPrint('💥 Ошибка при декодировании polyline: $e');
    }
    return points;
  }

  // ============================================================================
  // ВСПОМОГАТЕЛЬНЫЙ МЕТОД ФОРМАТИРОВАНИЯ СТРОКИ АДРЕСА
  // ============================================================================
  String _formatAddressText(Map<String, dynamic>? addressData) {
    if (addressData == null) return '';

    final String name = addressData['name']?.toString() ?? '';
    final String town = addressData['town']?.toString() ?? '';

    if (town.isNotEmpty && name.isNotEmpty) {
      if (!name.toLowerCase().contains(town.toLowerCase())) {
        return '$town, $name';
      }
      return name;
    }

    return name.isNotEmpty ? name : town;
  }

  // ============================================================================
  // ПЕРЕХОД И ОБРАБОТКА ВОЗВРАТА С ЭКРАНА РУЧНОГО ПОИСКА
  // ============================================================================
  Future<void> _openSearchAddressScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SearchAddressScreen(
              shopId: widget.shopId,
              onOrderPlaced: widget.onOrderPlaced,
              restaurantName: widget.restaurantName,
            ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAddressData = result;
      });

      if (result['id'] != null) {
        final int targetId = result['id'] is int
            ? result['id']
            : int.parse(result['id'].toString());
        _calculateRoute(targetId);
      }

      if (result['lat'] != null && result['lon'] != null) {
        final double rawLat = double.tryParse(result['lat'].toString()) ?? 0.0;
        final double rawLon = double.tryParse(result['lon'].toString()) ?? 0.0;

        if (rawLat != 0.0 && rawLon != 0.0) {
          final realLat = rawLat.abs() > 90 ? rawLat / 1000000.0 : rawLat;
          final realLon = rawLon.abs() > 180 ? rawLon / 1000000.0 : rawLon;

          final target = LatLng(realLat, realLon);
          _mapController.move(target, 16.5);
          _currentCenter = target;
        }
      }
    }
  }

// ============================================================================
// ПОСТРОЕНИЕ ПОЛЬЗОВАТЕЛЬСКОГО ИНТЕРФЕЙСА (UI) — ФИКСИРОВАННАЯ КАРТА + ШТОРКА
// ============================================================================
  @override
  Widget build(BuildContext context) {
    final activeAddress = _selectedAddressData ?? _mapAddressData;
    final String formattedAddress = _formatAddressText(activeAddress);

    final String displayAddressText = formattedAddress.isNotEmpty
        ? formattedAddress
        : (_isLoadingMapAddress || _isLocatingRestaurant || _isGettingLocation
        ? 'Определяем адрес...'
        : 'Переместите карту для выбора');

    const double sheetHeight = 0.45; // Высота шторки в процентах от экрана

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(
          'Заказ: ${widget.restaurantName}',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
      ),
      body: Stack(
        children: [
// ------------------------------------------------------------------
// 1. БЛОК ИНТЕРАКТИВНОЙ КАРТЫ (ОГРАНИЧЕН ВИДИМОЙ ОБЛАСТЬЮ НАД ШТОРКОЙ)
// ------------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery
                .of(context)
                .size
                .height * sheetHeight,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 16.0,
                onPositionChanged: (position, hasGesture) {
                  if (position.center != null) {
                    _onMapPositionChanged(position.center!, hasGesture);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://map.99993.ru:1443/styles/openstreetmap/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),

// 🔹 МЕТКА САМОГО РЕСТОРАНА НА КАРТЕ
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _restaurantMapLatLng,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                            Icons.restaurant, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),

// 🔹 ОТРЕСОВКА СИНЕЙ ЛИНИИ МАРШРУТА НА КАРТЕ
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5.0,
                        color: const Color(0xFF2563EB),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
              ],
            ),
          ),

// ------------------------------------------------------------------
// СТРОГО ЦЕНТРАЛЬНЫЙ ПИН «А» (ПОВЕРХ ВСЕГО В ЦЕНТРЕ ВИДИМОЙ ЗОНЫ КАРТЫ)
// ------------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery
                .of(context)
                .size
                .height * sheetHeight,
            child: IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'А',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 10,
                      height: 8,
                      child: ClipPath(
                        clipper: _PinTailClipper(),
                        child: Container(
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

// ------------------------------------------------------------------
// 2. КНОПКА «МОЕ МЕСТОПОЛОЖЕНИЕ» (GPS)
// ------------------------------------------------------------------
          Positioned(
            bottom: MediaQuery
                .of(context)
                .size
                .height * sheetHeight + 16,
            right: 16,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.15),
              child: InkWell(
                onTap: _isGettingLocation ? null : _determineFastPosition,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: _isGettingLocation
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF111111)),
                  )
                      : const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF111111),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

// ------------------------------------------------------------------
// 3. НИЖНЯЯ ПАНЕЛЬ (ФИКСИРОВАННАЯ ШТОРКА С ПРОКРУТКОЙ)
// ------------------------------------------------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery
                    .of(context)
                    .size
                    .height * sheetHeight,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
// Индикатор шторки
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

// ==========================================
// СЕКЦИЯ «КУДА»
// ==========================================
                        const Text(
                          'Куда',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 1),
                          ),
                          child: Column(
                            children: [
// 1. Строка выбора / отображения адреса
                              InkWell(
                                onTap: _openSearchAddressScreen,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.home_rounded,
                                          color: Color(0xFF111111), size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          displayAddressText,
                                          style: const TextStyle(
                                            color: Color(0xFF111111),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Color(0xFF9CA3AF), size: 14),
                                    ],
                                  ),
                                ),
                              ),

// КНОПКА «Другой способ / Указать вручную» в строгом стиле интерфейса
                              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                              InkWell(
                                onTap: _openSearchAddressScreen,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text(
                                        'Другой способ (указать вручную)',
                                        style: TextStyle(
                                          color: Color(0xFF111111),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit_location_alt_outlined,
                                        color: Color(0xFF6B7280),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const Divider(height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF3F4F6)),

// 2. Строка полей ввода
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _entranceController,
                                        style: const TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111111)),
                                        decoration: const InputDecoration(
                                          labelText: 'Подъезд',
                                          labelStyle: TextStyle(fontSize: 12,
                                              color: Color(0xFF9CA3AF)),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                    Container(height: 24,
                                        width: 1,
                                        color: const Color(0xFFF3F4F6)),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8.0),
                                        child: TextField(
                                          controller: _floorController,
                                          style: const TextStyle(fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111111)),
                                          decoration: const InputDecoration(
                                            labelText: 'Этаж',
                                            labelStyle: TextStyle(fontSize: 12,
                                                color: Color(0xFF9CA3AF)),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets
                                                .symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(height: 24,
                                        width: 1,
                                        color: const Color(0xFFF3F4F6)),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: TextField(
                                          controller: _apartmentController,
                                          onChanged: (value) => setState(() {}), // 👈 ЭТА СТРОКА РЕШАЕТ ПРОБЛЕМУ
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111111),
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'Кв/Офис',
                                            labelStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(height: 24,
                                        width: 1,
                                        color: const Color(0xFFF3F4F6)),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8.0),
                                        child: TextField(
                                          controller: _intercomController,
                                          style: const TextStyle(fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111111)),
                                          decoration: const InputDecoration(
                                            labelText: 'Домофон',
                                            labelStyle: TextStyle(fontSize: 12,
                                                color: Color(0xFF9CA3AF)),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets
                                                .symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF3F4F6)),

// 3. Комментарий
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                child: TextField(
                                  controller: _commentController,
                                  maxLines: 2,
                                  minLines: 1,
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF111111)),
                                  decoration: const InputDecoration(
                                    hintText: 'Комментарий к заведению',
                                    hintStyle: TextStyle(
                                        fontSize: 13, color: Color(0xFF9CA3AF)),
                                    prefixIcon: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: Color(0xFF9CA3AF), size: 18),
                                    prefixIconConstraints: BoxConstraints(
                                        minWidth: 32),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

// ==========================================
// СЕКЦИЯ «ОПЛАТА»
// ==========================================
                        const Text(
                          'Оплата',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GridView.builder(
                          itemCount: paymentOptions.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.8,
                          ),
                          itemBuilder: (context, index) {
                            final option = paymentOptions[index];
                            final bool isSelected = _selectedPaymentMethod ==
                                option['id'];

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentMethod = option['id'];
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? const Color(
                                          0xFF111111) : const Color(0xFFE5E7EB),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        option['icon'] as IconData,
                                        color: isSelected ? const Color(
                                            0xFF111111) : const Color(
                                            0xFF4B5563),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          option['label'],
                                          style: TextStyle(
                                            color: isSelected ? const Color(
                                                0xFF111111) : const Color(
                                                0xFF374151),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

// ==========================================
// СЕКЦИЯ РАСЧЕТА И КНОПКА
// ==========================================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        // 1. Сумма за товары
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Товары',
                              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${widget.productsTotal.toInt()} руб.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF111111), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // 2. Стоимость доставки
                        if (_isCalculatingRoute || _isLocatingRestaurant) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)),
                                ),
                                SizedBox(width: 8),
                                Text('Расчет доставки...', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Доставка',
                                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${_calculateDeliveryPrice().toInt()} руб.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF111111), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                        ),

                        // 3. Итого (Товары + Доставка)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Всего',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111111),
                              ),
                            ),
                            Text(
                              '${(widget.productsTotal + _calculateDeliveryPrice()).toInt()} руб.',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Кнопка оплаты
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (activeAddress != null)
                                ? () {
                              final String baseAddress = displayAddressText;
                              final String entrance = _entranceController.text.trim();
                              final String floor = _floorController.text.trim();
                              final String apartment = _apartmentController.text.trim();
                              final String intercom = _intercomController.text.trim();

                              List<String> addressParts = [baseAddress];
                              if (entrance.isNotEmpty) addressParts.add('под. $entrance');
                              if (floor.isNotEmpty) addressParts.add('эт. $floor');
                              if (apartment.isNotEmpty) addressParts.add('кв. $apartment');

                              String finalFullAddress = addressParts.join(', ');
                              if (intercom.isNotEmpty) {
                                finalFullAddress += ' (домофон: $intercom)';
                              }

                              debugPrint('📦 ФИНАЛЬНЫЙ АДРЕС ДЛЯ КУРЬЕРА: $finalFullAddress');
                              debugPrint('💰 ИТОГОВАЯ СУММА К ОПЛАТЕ: ${widget.productsTotal + _calculateDeliveryPrice()} руб.');
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111111),
                              disabledBackgroundColor: const Color(0xFFE5E7EB),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF9CA3AF),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Оформить заказ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }}






// =================================================0===========================
// ВСПОМОГАТЕЛЬНЫЙ КЛИППЕР ДЛЯ ОРИГИНАЛЬНОГО УКАЗАТЕЛЯ ПИНА
// ============================================================================
class _PinTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}