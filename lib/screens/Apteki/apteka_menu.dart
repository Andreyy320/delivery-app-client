import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dish_model.dart';
import '../Menu/Cart_data.dart';
import '../Menu/cart_screen.dart';
import '../../models/cart_item.dart' hide cart;

class AptekaMenuScreen extends StatefulWidget {
  final String restaurantName;
  final List<Dish> menu;
  final String shopId;
  final void Function(Dish, String) addToCart;

  const AptekaMenuScreen({
    super.key,
    required this.restaurantName,
    required this.menu,
    required this.shopId,
    required this.addToCart,
  });

  @override
  State<AptekaMenuScreen> createState() => _AptekaMenuScreenState();
}

class _AptekaMenuScreenState extends State<AptekaMenuScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String _activeCategory = '';
  String _searchQuery = '';
  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = widget.menu.map((e) => e.category).toSet().toList();
    for (final c in _categories) {
      _categoryKeys[c] = GlobalKey();
    }
    _activeCategory = _categories.first;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    for (final cat in _categories) {
      final ctx = _categoryKeys[cat]?.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox;
        final pos = box.localToGlobal(Offset.zero).dy;
        if (pos >= 0) {
          if (_activeCategory != cat) {
            setState(() => _activeCategory = cat);
            _scrollCategoryIntoView(cat);
          }
          break;
        }
      }
    }
  }

  void _scrollCategoryIntoView(String category) {
    final index = _categories.indexOf(category);
    if (index == -1) return;

    const itemWidth = 110.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = index * itemWidth - screenWidth / 2 + itemWidth / 2;

    _categoryScrollController.animateTo(
      offset.clamp(
        _categoryScrollController.position.minScrollExtent,
        _categoryScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToCategory(String category) {
    final ctx = _categoryKeys[category]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CartScreen(shopId: widget.shopId,restaurantName: widget.restaurantName)),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Поиск лекарств',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          // Категории
          SizedBox(
            height: 48,
            child: ListView.builder(
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = cat == _activeCategory;
                return GestureDetector(
                  onTap: () => _scrollToCategory(cat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? Colors.deepOrange : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Список товаров
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: _categories.map((category) {
                  final items = widget.menu.where((e) {
                    return e.category == category &&
                        e.name.toLowerCase().contains(_searchQuery);
                  }).toList();
                  if (items.isEmpty) return const SizedBox.shrink();

                  return Column(
                    key: _categoryKeys[category],
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          category,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.63,
                            crossAxisSpacing: 5,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (_, i) => DishCardWithStatus(
                            dish: items[i],
                            shopId: widget.shopId,
                            addToCart: widget.addToCart,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DishCardWithStatus extends StatelessWidget {
  final Dish dish;
  final String shopId;
  final void Function(Dish, String) addToCart;

  const DishCardWithStatus({
    required this.dish,
    required this.shopId,
    required this.addToCart,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final cartNotifier = getCart(userId, shopId); // 🔹 корзина привязана к userId + shopId

    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        final addedToCart = cart.any((item) => item.dish.name == dish.name);

        return ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.asset(
                    dish.imagePath,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dish.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dish.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: addedToCart
                        ? const Center(
                      child: Text(
                        'В корзине',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${dish.price.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => addToCart(dish, shopId),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
