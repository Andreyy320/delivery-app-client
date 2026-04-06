import 'package:flutter/material.dart';

class AuthState extends ValueNotifier<bool> {
  AuthState() : super(false);

  bool get isLoggedIn => value;

  void login() {
    value = true;
    notifyListeners();
  }

  void logout() {
    value = false;
    notifyListeners();
  }
}

final authState = AuthState();
