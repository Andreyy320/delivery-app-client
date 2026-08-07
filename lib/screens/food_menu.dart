import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dish_model.dart';
import 'package:untitled1/screens/Menu/cart_screen.dart';
import 'package:untitled1/screens/Menu/Cart_data.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final String restaurantName;
  final String shopId;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurantName,
    required this.shopId,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
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
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
      setState(() => _isManualScrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.restaurantName,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: getCart(userId, widget.shopId),
            builder: (context, cart, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined,
                        size: 26, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(
                          shopId: widget.shopId,
                          restaurantName: widget.restaurantName,
                        ),
                      ),
                    ),
                  ),
                  if (cart.isNotEmpty)
                    PositionByRelative(cart.length.toString()),
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
            .where('isAvailable', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Ошибка загрузки',
                  style: TextStyle(color: Color(0xFF64748B))),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0F172A), strokeWidth: 2.5),
            );
          }

          final allItems =
          snapshot.data!.docs.map((doc) => Dish.fromFirestore(doc)).toList();

          final filteredItems = allItems
              .where((item) =>
          item.name.toLowerCase().contains(_searchQuery) ||
              item.category.toLowerCase().contains(_searchQuery))
              .toList();

          final currentCategories =
          filteredItems.map((e) => e.category).toSet().toList();
          if (_categories.join() != currentCategories.join()) {
            _categories = currentCategories;
            for (var cat in _categories) {
              _categoryKeys.putIfAbsent(cat, () => GlobalKey());
            }
            if (_categories.isNotEmpty && _activeCategory.isEmpty) {
              _activeCategory = _categories.first;
            }
          }

          return Column(
            children: [
              // ПОЛЕ ПОИСКА БЛЮД
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Найдите любимое блюдо...',
                      hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Color(0xFF64748B), size: 22),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // ГОРИЗОНТАЛЬНОЕ МЕНЮ КАТЕГОРИЙ
              if (_categories.isNotEmpty)
                SizedBox(
                  height: 52,
                  child: ListView.builder(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isActive = _activeCategory == cat;
                      return GestureDetector(
                        onTap: () => _scrollToCategory(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? Colors.transparent
                                  : Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: isActive
                                ? [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                                : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // СПИСОК БЛЮД ПО КАТЕГОРИЯМ
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 30),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final itemsInCategory = filteredItems
                        .where((i) => i.category == category)
                        .toList();

                    if (itemsInCategory.isEmpty) return const SizedBox.shrink();

                    return Column(
                      key: _categoryKeys[category],
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.49,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: itemsInCategory.length,
                          itemBuilder: (context, i) => DishCardWithStatus(
                            dish: itemsInCategory[i],
                            shopId: widget.shopId,
                          ),
                        ),
                        const SizedBox(height: 12),
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

/// Стилизованная карточка блюда
class DishCardWithStatus extends StatefulWidget {
  final Dish dish;
  final String shopId;
  const DishCardWithStatus(
      {required this.dish, required this.shopId, super.key});

  @override
  State<DishCardWithStatus> createState() => _DishCardWithStatusState();
}

class _DishCardWithStatusState extends State<DishCardWithStatus> {
  bool _pressed = false;

  String getUnit(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('напитки') ||
        cat.contains('сок') ||
        cat.contains('вино') ||
        cat.contains('кофе') ||
        cat.contains('чай') ||
        cat.contains('коктейли')) {
      return "мл";
    }
    return "г";
  }

  void _openDetails(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailsBottomSheet(
        dish: widget.dish,
        shopId: widget.shopId,
        userId: userId,
        unit: getUnit(widget.dish.category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: getCart(userId, widget.shopId),
      builder: (context, cart, _) {
        final added = cart.any((item) => item.dish.name == widget.dish.name);

        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () => _openDetails(context, userId),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ИЗОБРАЖЕНИЕ БЛЮДА С ЦЕНОЙ
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                widget.dish.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                    Icons.restaurant_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 36),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                                child: Text(
                                  "${widget.dish.price.toInt()} Руб",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ИНФОРМАЦИЯ О БЛЮДЕ
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              widget.dish.name,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.3,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.dish.weight} ${getUnit(widget.dish.category)}",
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: Text(
                            widget.dish.description,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              height: 1.15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // КНОПКА ДОБАВЛЕНИЯ В КОРЗИНУ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    child: GestureDetector(
                      onTap: () => addToCartItem(userId, widget.shopId,
                          widget.dish, context: context),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 38,
                        decoration: BoxDecoration(
                          color: added
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: added
                              ? []
                              : [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (added) ...[
                              const Icon(Icons.check_rounded,
                                  size: 16, color: Color(0xFF0F172A)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              added ? "В КОРЗИНЕ" : "ДОБАВИТЬ",
                              style: TextStyle(
                                color: added
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}





/// Экран подробной информации о товаре (Модальное окно)
class ProductDetailsBottomSheet extends StatefulWidget {
  final Dish dish;
  final String shopId;
  final String userId;
  final String unit;

  const ProductDetailsBottomSheet({
    super.key,
    required this.dish,
    required this.shopId,
    required this.userId,
    required this.unit,
  });

  @override
  State<ProductDetailsBottomSheet> createState() => _ProductDetailsBottomSheetState();
}

class _ProductDetailsBottomSheetState extends State<ProductDetailsBottomSheet> {
  // Индекс выбранного размера (0 по умолчанию)
  int _selectedSizeIndex = 0;

  // Множество выбранных названий модификаторов (допов)
  final Set<String> _selectedModifiers = {};

  /// Базовая цена выбранного размера (или дефолтная цена товара без учета допов)
  double get _basePrice {
    return widget.dish.sizes.isNotEmpty
        ? widget.dish.sizes[_selectedSizeIndex].price
        : widget.dish.price;
  }

  /// Динамический расчет итоговой цены для отображения в кнопке (База + Допы)
  double get _calculatedPrice {
    double modifiersSum = 0;
    for (var modifier in widget.dish.modifiers) {
      if (_selectedModifiers.contains(modifier.name)) {
        modifiersSum += modifier.price;
      }
    }
    return _basePrice + modifiersSum;
  }

  /// Динамическое получение веса (из выбранного размера или дефолтного)
  String get _currentWeight {
    if (widget.dish.sizes.isNotEmpty) {
      return widget.dish.sizes[_selectedSizeIndex].weight;
    }
    return widget.dish.weight;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSizes = widget.dish.sizes.isNotEmpty;
    final bool hasModifiers = widget.dish.modifiers.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ручка свайпа
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Основной контент
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Фото товара
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: Image.network(
                          widget.dish.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.restaurant_rounded,
                            color: Color(0xFF94A3B8),
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Название товара
                  Text(
                    widget.dish.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Динамический вес
                  Text(
                    "$_currentWeight ${widget.unit}",
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Описание
                  const Text(
                    "Описание",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.dish.description.isNotEmpty
                        ? widget.dish.description
                        : "Подробное описание этого товара пока не добавлено.",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // БЛОК РАЗМЕРОВ (Рендерится только при их наличии)
                  if (hasSizes) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "Размер",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(widget.dish.sizes.length, (index) {
                        final sizeItem = widget.dish.sizes[index];
                        final isSelected = _selectedSizeIndex == index;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSizeIndex = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                right: index < widget.dish.sizes.length - 1 ? 10 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0F172A)
                                      : Colors.transparent,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${sizeItem.name}\n${sizeItem.price.toInt()} Руб",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],

                  // БЛОК МОДИФИКАТОРОВ (Рендерится только при их наличии)
                  if (hasModifiers) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "Добавить по вкусу",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: widget.dish.modifiers.map((modifier) {
                        final isChecked = _selectedModifiers.contains(modifier.name);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isChecked
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isChecked,
                            activeColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            title: Text(
                              modifier.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            secondary: Text(
                              "+${modifier.price.toInt()} Руб",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedModifiers.add(modifier.name);
                                } else {
                                  _selectedModifiers.remove(modifier.name);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Кнопка добавления в корзину с динамической итоговой ценой
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // 1. Нормализуем shopId
                    String? effectiveShopId = (widget.shopId == "" || widget.shopId == "null" || widget.shopId == "combined")
                        ? null
                        : widget.shopId;

                    // 2. Имя выбранного размера
                    String? sizeName = hasSizes ? widget.dish.sizes[_selectedSizeIndex].name : null;

                    // 3. Собираем список выбранных модификаторов
                    final chosenModifiers = widget.dish.modifiers
                        .where((m) => _selectedModifiers.contains(m.name))
                        .toList();

                    // 4. Передаем ЧИСТУЮ базовую цену товара/размера.
                    // Допы отправляются отдельно через параметр выбранных модификаторов.
                    final selectedDish = Dish(
                      name: widget.dish.name,
                      description: widget.dish.description,
                      price: _basePrice, // ЧИСТАЯ БАЗА (например, 110 руб вместо 140)
                      imagePath: widget.dish.imagePath,
                      category: widget.dish.category,
                      weight: _currentWeight,
                      sizes: hasSizes ? [widget.dish.sizes[_selectedSizeIndex]] : [],
                      modifiers: [],
                    );

                    // 5. Добавляем в корзину
                    addToCartItem(
                      widget.userId,
                      effectiveShopId ?? '',
                      selectedDish,
                      context: context,
                      selectedSize: sizeName,
                      selectedModifiers: chosenModifiers,
                    );

                    Navigator.pop(context);
                  },
                  child: Text(
                    "Добавить в корзину • ${_calculatedPrice.toInt()} Руб",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Иконка счетчика товаров в корзине
Widget PositionByRelative(String count) {
  return Positioned(
    right: 6,
    top: 8,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Text(
        count,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}