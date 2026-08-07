import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AddressApiService {
  static const String baseUrl = 'https://api.99993.ru';
  static String? _token;
  static const String _apiKey =
      'hKjt90C-0JKeJRSCS_ZWEakeq_dfSBEMWSowXn9dmRVhKUP7L0vZn0BBGKjx4Xsmx2SlG8msSK3oTQPBaqFSi1tl3Zd6lvf_NNPwW6wkagPToWsvWmfgvMYVmFtEseYQisOt9ko5FKmukR5f3U3X7z_v0W3h8l9OcJ2kR-4ImZo7Cry3WGA3aQUHD_0fmqeiWqmfobRz1C0taJlsSKJeoXlqHl6relGe4YDaLNiYI0ZUHRcVtFpGGVJZ1soGlMGs';

  /// 🔹 Публичный геттер для получения текущего токена авторизации
  static String? get authToken => _token;

  /// --- Авторизация ---
  static Future<bool> auth({String? key}) async {
    final authKey = key ?? _apiKey;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': authKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        debugPrint('🔑 [API] Токен успешно получен');
        return true;
      }
    } catch (e) {
      debugPrint('💥 Ошибка авторизации: $e');
    }
    return false;
  }

  /// 🔹 Метод для автоматической гарантированной авторизации (получения токена)
  static Future<String?> getToken() async {
    if (_token == null) {
      await auth();
    }
    return _token;
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'X-Api-Token': _token!,
    };
  }

  static Future<http.Response?> _post(
      String path, Map<String, dynamic> body) async {
    if (_token == null) {
      bool ok = await auth();
      if (!ok) return null;
    }

    Uri uri = Uri.parse('$baseUrl$path');
    try {
      var response = await http.post(uri,
          headers: _getHeaders(), body: jsonEncode(body));

      if (response.statusCode == 403) {
        debugPrint('🔄 Токен истёк. Обновляем...');
        bool reAuthOk = await auth();
        if (reAuthOk) {
          response = await http.post(uri,
              headers: _getHeaders(), body: jsonEncode(body));
        }
      }
      return response;
    } catch (e) {
      debugPrint('💥 Сетевая ошибка $path: $e');
      return null;
    }
  }

  // --- Работа с адресами и городами ---

  /// 🔹 Определение адреса по координатам (/v1/locateAddress)
  static Future<Map<String, dynamic>?> locateAddress(num lat, num lon, [String? token]) async {
    final int latE6 = (lat.abs() > 180) ? lat.round() : (lat * 1000000).round();
    final int lonE6 = (lon.abs() > 180) ? lon.round() : (lon * 1000000).round();

    debugPrint('📤 [API REQUEST] /v1/locateAddress payload: lat=$latE6, lon=$lonE6');

    final res = await _post('/v1/locateAddress', {
      'lat': latE6,
      'lon': lonE6,
    });

    if (res != null) {
      debugPrint('🔌 [API RESPONSE] Status: ${res.statusCode}');
      debugPrint('🔌 [API RESPONSE] Body: ${res.body}');
    }

    if (res != null && res.statusCode == 200 && res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    return null;
  }

  /// Поиск города по названию для выпадающего списка (/v1/searchTown)
  static Future<List<Map<String, dynamic>>> searchTown(String name) async {
    if (name.trim().isEmpty) return [];
    final res = await _post('/v1/searchTown', {'name': name});
    if (res != null && res.statusCode == 200) {
      List data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  /// Получение списка всех улиц города (/v1/getAllStreet)
  static Future<List<Map<String, dynamic>>> getAllStreets(int townId) async {
    final res = await _post('/v1/getAllStreet', {'townId': townId});
    if (res != null && res.statusCode == 200) {
      List data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  /// Получение списка городов (/v1/getTown)
  static Future<List<Map<String, dynamic>>> getTowns() async {
    final res = await _post('/v1/getTown', {});
    if (res != null && res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  /// Поиск адреса/улицы в реальном времени для автокомплита (/v1/searchAddress)
  static Future<List<Map<String, dynamic>>> searchAddress(
      String query, int townId) async {
    if (query.trim().isEmpty) return [];
    final res = await _post('/v1/searchAddress', {
      'name': query,
      'townId': townId,
      'short': true,
    });
    if (res != null && res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  /// Проверка адреса (/v1/checkAddress)
  static Future<Map<String, dynamic>?> checkAddress(
      String name, int townId) async {
    final res = await _post('/v1/checkAddress', {
      'name': name,
      'townId': townId,
    });
    if (res != null && res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Получение направлений поездки (/v1/getDestinations)
  static Future<List<Map<String, dynamic>>> getDestinations(int townId) async {
    final res = await _post('/v1/getDestinations', {'townId': townId});
    if (res != null && res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  /// Получение списка служб/групп (/v1/getGroups)
  static Future<List<Map<String, dynamic>>> getGroups({int id = 0}) async {
    final res = await _post('/v1/getGroups', {'id': id});
    if (res != null && res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  /// Список типов авто (/v1/getCarTypes)
  static Future<List<Map<String, dynamic>>> getCarTypes() async {
    final res = await _post('/v1/getCarTypes', {});
    if (res != null && res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  /// 🔹 Расчет маршрута и стоимости доставки (/v1/getRoute)
  /// С перебором известных групп доставки (328, 329), если переданная не подошла.
  static Future<Map<String, dynamic>?> getRoute({
    int groupId = 328,
    required List<int> addressIds,
    int time = 0,
  }) async {
    // Формируем очередь из группы по умолчанию (328) и резервной (329)
    final List<int> candidateGroups = {groupId, 328, 329}.toList();

    for (final currentGroup in candidateGroups) {
      debugPrint('📤 [API REQUEST] /v1/getRoute payload: groupId=$currentGroup, addressIds=$addressIds, time=$time');

      final res = await _post('/v1/getRoute', {
        'groupId': currentGroup,
        'addressIds': addressIds,
        'time': time,
      });

      if (res != null) {
        debugPrint('🔌 [API ROUTE RESPONSE] Status: ${res.statusCode}');
        debugPrint('🔌 [API ROUTE RESPONSE] Body: ${res.body}');
      }

      // 200 - Маршрут успешно построен
      if (res != null && res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      if (res != null && res.statusCode == 204) {
        debugPrint('⚠️ [API ROUTE] groupId=$currentGroup вернул 204 (маршрут не найден). Пробуем следующий...');
      }
    }

    return null;
  }

/// Оформление заказа (/v1/addOrder)
static Future<Map<String, dynamic>?> addOrder({
required int addressId,
int groupId = 328,
required String phone,
int? destinationId,
String? comment,
int? carType,
List<int>? carServices,
int? radugaId,
}) async {
final Map<String, dynamic> body = {
'addressId': addressId,
'groupId': groupId,
'phone': phone,
if (destinationId != null) 'destinationId': destinationId,
if (comment != null) 'comment': comment,
if (carType != null) 'carType': carType,
if (carServices != null) 'carServices': carServices,
if (radugaId != null) 'radugaId': radugaId,
};

debugPrint('📤 [API REQUEST] POST /v1/addOrder payload: $body');

final res = await _post('/v1/addOrder', body);

if (res != null) {
debugPrint('🔌 [API RESPONSE] Status Code: ${res.statusCode}');
debugPrint('🔌 [API RESPONSE] Body: ${res.body}');
} else {
debugPrint('❌ [API ERROR] Response is null for /v1/addOrder');
}

if (res != null && res.statusCode == 200 && res.body.isNotEmpty) {
try {
return jsonDecode(res.body) as Map<String, dynamic>;
} catch (e) {
debugPrint('💥 [API PARSE ERROR] Failed to decode JSON: $e');
}
}

return null;
 }
 }
