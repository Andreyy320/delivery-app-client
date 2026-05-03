import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/dish_model.dart';
import '../../models/cart_item.dart' hide cart;
import '../Menu/Cart_data.dart';
import '../Menu/cart_screen.dart';

class ElectronikaMenuScreen extends StatefulWidget {
  final String restaurantName;
  final String shopId;

  const ElectronikaMenuScreen({
    super.key,
    required this.restaurantName,
    required this.shopId,
  });

  @override
  State<ElectronikaMenuScreen> createState() => _ElectronikaMenuScreenState();
}

class _ElectronikaMenuScreenState extends State<ElectronikaMenuScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};

  String _activeCategory = '';
  String _searchQuery = '';
  List<String> _categories = [];
  bool _isManualScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isManualScrolling || _categories.isEmpty) return;
    for (var category in _categories) {
      final context = _categoryKeys[category]?.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero).dy;
        // Порог 220 оптимален для фиксации активной категории вверху
        if (offset >= 0 && offset < 220) {
          if (_activeCategory != category) {
            setState(() => _activeCategory = category);
            _autoScrollCategoryMenu(category);
          }
          break;
        }
      }
    }
  }

  void _autoScrollCategoryMenu(String category) {
    final index = _categories.indexOf(category);
    if (index != -1 && _categoryScrollController.hasClients) {
      _categoryScrollController.animateTo(
        index * 100.0 - 40,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _scrollToCategory(String category) async {
    final context = _categoryKeys[category]?.currentContext;
    if (context != null) {
      setState(() {
        _isManualScrolling = true;
        _activeCategory = category;
      });
      await Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart);
      setState(() => _isManualScrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(widget.restaurantName,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: getCart(userId, widget.shopId),
            builder: (context, cartItems, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, size: 28),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CartScreen(shopId: widget.shopId, restaurantName: widget.restaurantName))),
                  ),
                  if (cartItems.isNotEmpty)
                    PositionByRelative(cartItems.length.toString()),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .doc(widget.shopId)
            .collection('menu')
            .where('isAvailable', isEqualTo: true) // <--- ДОБАВЬТЕ ЭТУ СТРОКУ
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Ошибка загрузки')); // Рекомендую добавить обработку ошибки
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));

          final allItems = snapshot.data!.docs.map((doc) => Dish.fromFirestore(doc)).toList();
          // ... остальной код без изменений
        final filteredItems = allItems.where((item) =>
          item.name.toLowerCase().contains(_searchQuery) ||
              item.category.toLowerCase().contains(_searchQuery)).toList();

          final currentCategories = filteredItems.map((e) => e.category).toSet().toList();
          if (_categories.join() != currentCategories.join()) {
            _categories = currentCategories;
            for (var cat in _categories) {
              _categoryKeys.putIfAbsent(cat, () => GlobalKey());
            }
            if (_categories.isNotEmpty && _activeCategory.isEmpty) _activeCategory = _categories.first;
          }

          return Column(
            children: [
              // Поиск
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Поиск товаров...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.black54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // Категории
              Container(
                height: 60,
                color: Colors.white,
                child: ListView.builder(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isActive = _activeCategory == cat;
                    return GestureDetector(
                      onTap: () => _scrollToCategory(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isActive
                              ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                        ),
                        alignment: Alignment.center,
                        child: Text(cat, style: TextStyle(
                            color: isActive ? Colors.white : Colors.black87,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),
              // Список товаров
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final itemsInCategory = filteredItems.where((i) => i.category == category).toList();

                    return Column(
                      key: _categoryKeys[category],
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
                          child: Text(category, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: itemsInCategory.length,
                          itemBuilder: (context, i) => DishCardWithStatus(
                            dish: itemsInCategory[i],
                            shopId: widget.shopId,
                            userId: userId,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DishCardWithStatus extends StatelessWidget {
  final Dish dish;
  final String shopId;
  final String userId;

  const DishCardWithStatus({
    required this.dish,
    required this.shopId,
    required this.userId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: getCart(userId, shopId),
      builder: (context, cart, _) {
        final added = cart.any((item) => item.dish.name == dish.name);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Center(
                          child: Image.network(
                            dish.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(Icons.laptop_mac, color: Colors.grey, size: 40),
                          ),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
                            child: Text("${dish.price.toInt()} MDL", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(dish.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(dish.description, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.black38, height: 1.1)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: GestureDetector(
                  onTap: () => addToCartItem(userId, shopId, dish, context: context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 40,
                    decoration: BoxDecoration(
                      color: added ? Colors.black : Colors.deepOrange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: added ? [] : [BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Center(
                      child: Text(added ? "В КОРЗИНЕ" : "ДОБАВИТЬ",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

Widget PositionByRelative(String count) {
  return Positioned(
    right: 4, top: 10,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Text(count, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    ),
  );
}