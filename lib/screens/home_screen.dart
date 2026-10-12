import 'package:flutter/material.dart';
import 'categories_page.dart';

class HomeScreen extends StatelessWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return RestaurantsPage(userId: userId);
  }
}