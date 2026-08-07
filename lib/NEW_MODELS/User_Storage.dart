import 'package:postgres/postgres.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class UserStorage {
  // Настройки подключения к твоему локальному PostgreSQL
  // Подставь свои данные (порт по умолчанию 5432, хост '10.0.2.2' для Android Emulator или 'localhost' для iOS/ПК)
  static const String _host = '10.0.2.2';
  static const int _port = 5432;
  static const String _databaseName = 'postgres'; // или твоя база delivery_service_db
  static const String _username = 'postgres';
  static const String _password = 'martyn999'; // Укажи пароль, который вводил при установке


  // Метод входа
  static Future<void> login({
    required String phone,
    required String password,
  }) async {
    // Хэшируем введенный пароль так же, при регистрации
    var bytes = utf8.encode(password);
    var hashedPassword = sha256.convert(bytes).toString();

    final connection = await Connection.open(
      Endpoint(
        host: _host,
        port: _port,
        database: _databaseName,
        username: _username,
        password: _password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    try {
      // Ищем пользователя по телефону и хэшу пароля
      final result = await connection.execute(
        Sql.named('SELECT id FROM users WHERE phone = @phone AND password_hash = @passwordHash'),
        parameters: {
          'phone': phone,
          'passwordHash': hashedPassword,
        },
      );

      if (result.isEmpty) {
        throw Exception('Неверный номер или пароль');
      }
    } finally {
      await connection.close();
    }
  }

  // Метод регистрации нового пользователя
  static Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    // 1. Создаем безопасный хэш пароля (вместо сохранения открытого текста "123456")
    var bytes = utf8.encode(password);
    var hashedPassword = sha256.convert(bytes).toString();

    // 2. Открываем подключение к базе данных
    final connection = await Connection.open(
      Endpoint(
        host: _host,
        port: _port,
        database: _databaseName,
        username: _username,
        password: _password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    try {
      // 3. Проверяем, не занят ли email или телефон
      final checkResult = await connection.execute(
        Sql.named('SELECT id FROM users WHERE email = @email OR phone = @phone'),
        parameters: {'email': email, 'phone': phone},
      );

      if (checkResult.isNotEmpty) {
        throw Exception('Аккаунт с таким Email или телефоном уже существует !');
      }

      // 4. Вставляем нового пользователя в таблицу users
      await connection.execute(
        Sql.named('''
          INSERT INTO users (name, email, phone, password_hash, role, created_at)
          VALUES (@name, @email, @phone, @passwordHash, 'client', CURRENT_TIMESTAMP)
        '''),
        parameters: {
          'name': name,
          'email': email,
          'phone': phone,
          'passwordHash': hashedPassword,
        },
      );
    } finally {
      // 5. Обязательно закрываем соединение после выполнения
      await connection.close();
    }
  }
}