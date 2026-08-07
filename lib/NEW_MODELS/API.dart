import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Выбери нужный адрес в зависимости от того, где запускаешь:
  // Для эмулятора Android: 'http://10.0.2.2:3000/api'
  // Для реального телефона (IP твоего компа): 'http://192.168.x.x:3000/api'
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // --- РЕГИСТРАЦИЯ ---
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'client',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        // Сохраняем JWT-токен локально
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Ошибка регистрации'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Нет связи с сервером: $e'};
    }
  }

  // --- ВХОД ---
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        // Сохраняем JWT-токен локально
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Ошибка входа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Нет связи с сервером: $e'};
    }
  }
}