class User {
  final String name;
  final String phone;
  final String email;
  final String password;

  User({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
    );
  }
}
