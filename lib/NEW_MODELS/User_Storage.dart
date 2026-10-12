import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';
import '../screens/Dostavka/DeliveryOrder.dart';

class UserStorage {
  // Базовый адрес твоего сервера
  static const String _baseUrl = 'http://194.156.66.100:3100/api';

  static String get baseUrl => _baseUrl;

  // --- ВХОД ---
  static Future<void> login({
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/login');
    print('=== [LOGIN] Отправка запроса ===');
    print('URL: $url');
    print('Body: ${jsonEncode({'phone': phone, 'password': password})}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    print('=== [LOGIN] Ответ от сервера ===');
    print('StatusCode: ${response.statusCode}');
    print('ResponseBody: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Ошибка входа');
    }

    final prefs = await SharedPreferences.getInstance();

    // Сохраняем JWT-токен
    if (data['token'] != null) {
      await prefs.setString('token', data['token']);
      print('[LOGIN] Токен успешно сохранен');
    }

    // Сохраняем объект пользователя целиком
    if (data['user'] != null) {
      final userJson = jsonEncode(data['user']);
      await prefs.setString('user_data', userJson);
      print('[LOGIN] Данные юзера сохранены в user_data: $userJson');
    } else {
      print('[LOGIN] ВНИМАНИЕ: Сервер не прислал поле "user" в ответе!');
    }
  }

  // --- РЕГИСТРАЦИЯ ---
  static Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'client',
  }) async {
    final url = Uri.parse('$_baseUrl/register');
    print('=== [REGISTER] Отправка запроса ===');
    print('URL: $url');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      }),
    );

    print('=== [REGISTER] Ответ от сервера ===');
    print('StatusCode: ${response.statusCode}');
    print('ResponseBody: ${response.body}');

    final data = jsonDecode(response.body);

    if ((response.statusCode != 200 && response.statusCode != 201) || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Ошибка регистрации');
    }

    final prefs = await SharedPreferences.getInstance();

    if (data['token'] != null) {
      await prefs.setString('token', data['token']);
    }

    // Если бэкенд возвращает созданного юзера при регистрации — сохраняем
    if (data['user'] != null) {
      final userJson = jsonEncode(data['user']);
      await prefs.setString('user_data', userJson);
      print('[REGISTER] Данные юзера сохранены: $userJson');
    }
  }

  // --- ПОЛУЧИТЬ ТЕКУЩЕГО ЮЗЕРА ---
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_data');

    print('[getCurrentUser] Строка из SharedPreferences: $userStr');

    if (userStr == null) return null;

    try {
      return jsonDecode(userStr) as Map<String, dynamic>;
    } catch (e) {
      print('[getCurrentUser] Ошибка декодирования JSON: $e');
      return null;
    }
  }

  // --- ПОЛУЧИТЬ ТОКЕН (для будущих запросов) ---
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // --- ВЫХОД ---
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('token');
    print('[LOGOUT] Данные сессии удалены');
  }

  // --- ПОЛУЧИТЬ СПИСОК ЗАВЕДЕНИЙ ---
  static Future<List<Map<String, dynamic>>> getShops() async {
    final url = Uri.parse('$_baseUrl/shops');
    print('=== [GET SHOPS] Отправка запроса ===');
    print('URL: $url');

    final token = await getToken();

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    print('=== [GET SHOPS] Ответ от сервера ===');
    print('StatusCode: ${response.statusCode}');
    print('ResponseBody: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки заведений (код ${response.statusCode})');
    }

    final dynamic decoded = jsonDecode(response.body);

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['shops'] is List) {
      list = decoded['shops'];
    } else {
      list = [];
    }

    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  // --- ПОЛУЧИТЬ МЕНЮ ЗАВЕДЕНИЯ ---
  static Future<List<Map<String, dynamic>>> getMenu(String shopId) async {
    final url = Uri.parse('$_baseUrl/shops/$shopId/menu');
    print('=== [GET MENU] Отправка запроса ===');
    print('URL: $url');

    final token = await getToken();

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    print('=== [GET MENU] Ответ от сервера ===');
    print('StatusCode: ${response.statusCode}');
    print('ResponseBody: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки меню (код ${response.statusCode})');
    }

    final dynamic decoded = jsonDecode(response.body);

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['menu'] is List) {
      list = decoded['menu'];
    } else if (decoded is Map && decoded['dishes'] is List) {
      list = decoded['dishes'];
    } else {
      list = [];
    }

    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  // 🔹 Смена пароля через бэкенд
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/auth/change-password');
      print('=== [CHANGE PASSWORD] Отправка запроса ===');
      print('URL: $url');

      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Требуется авторизация'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      print('=== [CHANGE PASSWORD] Ответ от сервера ===');
      print('StatusCode: ${response.statusCode}');
      print('ResponseBody: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Пароль успешно изменён'};
      } else {
        return {'success': false, 'message': data['error'] ?? data['message'] ?? 'Ошибка смены пароля'};
      }
    } catch (e) {
      print('=== [CHANGE PASSWORD EXCEPTION] === $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // --- СОЗДАНИЕ ЗАКАЗА (С автоматической подстраховкой ключей картинки) ---
  static Future<bool> createOrder(Map<String, dynamic> orderData) async {
    try {
      final url = Uri.parse('$_baseUrl/orders');

      // Страховка: гарантируем, что бэкенд получит ключи и в snake_case, и в camelCase,
      // чтобы картинка заведения точно записалась в PostgreSQL без изменения вашей логики во Flutter.
      final fixedData = Map<String, dynamic>.from(orderData);
      final img = fixedData['restaurant_image'] ?? fixedData['restaurantImage'] ?? fixedData['logo_url'] ?? '';
      fixedData['restaurant_image'] = img;
      fixedData['restaurantImage'] = img;

      print('=== [CREATE ORDER] Отправка запроса ===');
      print('URL: $url');
      print('Body: ${jsonEncode(fixedData)}');

      final token = await getToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(fixedData),
      );

      print('=== [CREATE ORDER] Ответ от сервера ===');
      print('StatusCode: ${response.statusCode}');
      print('ResponseBody: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == false) {
          return false;
        }
        return true;
      }
      return false;
    } catch (e) {
      print('=== [CREATE ORDER EXCEPTION] === $e');
      return false;
    }
  }



  // --- СОЗДАНИЕ ИНДИВИДУАЛЬНОЙ ДОСТАВКИ (таблица individual_deliveries) ---
  static Future<bool> createIndividualOrder(Map<String, dynamic> orderData) async {
    try {
      // Отдельный эндпоинт на сервере для индивидуальных доставок
      final url = Uri.parse('$_baseUrl/individual-orders');

      print('=== [CREATE INDIVIDUAL ORDER] Отправка запроса ===');
      print('URL: $url');
      print('Body: ${jsonEncode(orderData)}');

      final token = await getToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );

      print('=== [CREATE INDIVIDUAL ORDER] Ответ от сервера ===');
      print('StatusCode: ${response.statusCode}');
      print('ResponseBody: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == false) {
          return false;
        }
        return true;
      }
      return false;
    } catch (e) {
      print('=== [CREATE INDIVIDUAL ORDER EXCEPTION] === $e');
      return false;
    }
  }


  // --- ПОЛУЧЕНИЕ ИСТОРИИ ИНДИВИДУАЛЬНЫХ ДОСТАВОК ---
  static Future<List<DeliveryOrder>> getIndividualOrders() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) return [];

      final userId = currentUser['id'];
      final url = Uri.parse('$_baseUrl/individual-orders?user_id=$userId');

      final token = await getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Преобразуем каждую запись из таблицы individual_deliveries в модель DeliveryOrder
        return data.map((json) => DeliveryOrder.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('💥 Error fetching individual orders: $e');
      return [];
    }
  }




  static Future<List<Order>> fetchUserOrders(dynamic userId) async {
    try {
      // 💡 Безопасно извлекаем ID, даже если в userId передали Map (объект пользователя) целиком
      String finalUserId;
      if (userId is Map) {
        finalUserId = userId['id']?.toString() ?? '';
      } else {
        finalUserId = userId.toString();
      }

      if (finalUserId.isEmpty) {
        print('=== [FETCH ORDERS ERROR] ID пользователя пуст ===');
        return [];
      }

      final url = Uri.parse('$_baseUrl/orders/user/$finalUserId');
      print('=== [FETCH ORDERS] Запрос по адресу: $url ===');

      final token = await getToken();

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      print('=== [FETCH ORDERS] Статус ответа: ${response.statusCode} ===');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('=== [FETCH ORDERS] Тело ответа успешно раскодировано ===');

        if (data['success'] == true && data['orders'] != null) {
          List<dynamic> ordersJson = data['orders'];
          print('=== [FETCH ORDERS] Найдено заказов: ${ordersJson.length} ===');

          return ordersJson.map((json) {
            final mapJson = json as Map<String, dynamic>;
            final String orderId = mapJson['id'] != null ? mapJson['id'].toString() : '';

            print('--- Парсим заказ ID: $orderId ---');
            return Order.fromJson(orderId, mapJson);
          }).toList();
        } else {
          print('=== [FETCH ORDERS] Поле success не true или orders равно null ===');
        }
      } else {
        print('=== [FETCH ORDERS] Ошибка сервера: ${response.body} ===');
      }
      return [];
    } catch (e) {
      print('=== [LOAD ORDERS ERROR] Ошибка загрузки заказов: $e ===');
      return [];
    }
  }

  // --- ПОЛУЧИТЬ ОБЫЧНЫЕ ЗАКАЗЫ (Еда, аптека, продукты и т.д.) ---
  static Future<List<Order>> getOrders() async {
    try {
      // 1. Получаем текущего пользователя из локального хранилища
      final user = await getCurrentUser();
      if (user == null || user['id'] == null) {
        print('=== [GET ORDERS] Ошибка: Пользователь не авторизован или нет ID ===');
        return [];
      }

      final userId = user['id'];

      // 2. Формируем URL точно под ваш серверный роут /api/orders/user/:userId
      final url = Uri.parse('$_baseUrl/orders/user/$userId');
      print('=== [GET ORDERS] Отправка запроса ===');
      print('URL: $url');

      final token = await getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('=== [GET ORDERS] Ответ от сервера ===');
      print('StatusCode: ${response.statusCode}');
      print('ResponseBody: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки заказов (код ${response.statusCode})');
      }

      final dynamic decoded = jsonDecode(response.body);
      List<dynamic> list = [];

      // Сервер возвращает { success: true, orders: [...] }
      if (decoded is Map && decoded['orders'] is List) {
        list = decoded['orders'];
      } else if (decoded is List) {
        list = decoded;
      }

      // Превращаем каждый элемент JSON в вашу модель Order
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final idStr = map['id']?.toString() ?? '';
        return Order.fromJson(idStr, map);
      }).toList();
    } catch (e) {
      print('=== [GET ORDERS EXCEPTION] === $e');
      return [];
    }
  }


  // --- УДАЛЕНИЕ ЗАКАЗА ИЛИ ДОСТАВКИ ---
  static Future<bool> deleteOrderById(String type, int orderId) async {
    try {
      // type может быть 'orders' или 'delivery_orders' в зависимости от таблицы
      final endpoint = type == 'orders' ? 'orders' : 'delivery-orders';
      final url = Uri.parse('$_baseUrl/$endpoint/$orderId');

      print('=== [DELETE ORDER] Отправка запроса ===');
      print('URL: $url');

      final token = await getToken();
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('=== [DELETE ORDER] Ответ: ${response.statusCode} ===');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('=== [DELETE ORDER EXCEPTION] === $e');
      return false;
    }
  }


}