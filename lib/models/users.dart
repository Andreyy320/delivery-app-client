class User {
  final int? id; // 🔹 Добавили поле ID (может быть int или String в зависимости от бэкенда)
  final String name;
  final String phone;
  final String email;

  User({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      // 🔹 Безопасно парсим id, поддерживая разные возможные ключи
      id: map['id'] ?? map['user_id'] ?? map['_id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
    );
  }
}