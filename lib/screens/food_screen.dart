import 'package:flutter/material.dart';
import 'food_menu.dart';
import '../NEW_MODELS/User_Storage.dart'; // 👈 Путь к вашему файлу с UserStorage

class FoodRestaurantsScreen extends StatefulWidget {
  final String? shopId;
  final String? shopName;
  final String? categoryKey;

  const FoodRestaurantsScreen({
    super.key,
    this.shopId,
    this.shopName,
    this.categoryKey,
  });

  @override
  State<FoodRestaurantsScreen> createState() => _FoodRestaurantsScreenState();
}

class _FoodRestaurantsScreenState extends State<FoodRestaurantsScreen> {
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _restaurantsFuture;

  // 👈 Переменная для хранения реального ID пользователя (по умолчанию 'local_user' на случай сбоя)
  String _userId = 'local_user';

  @override
  void initState() {
    super.initState();
    _restaurantsFuture = _loadDataAndUser();
  }

  // 👈 Загружаем и заведения, и актуальный ID пользователя одновременно
  Future<List<Map<String, dynamic>>> _loadDataAndUser() async {
    try {
      // Получаем данные текущего юзера из SharedPreferences
      final currentUser = await UserStorage.getCurrentUser();
      if (currentUser != null && currentUser['id'] != null) {
        setState(() {
          _userId = currentUser['id'].toString();
        });
      }

      final shops = await UserStorage.getShops();

      // Фильтрация по категории, если она передана и не равна 'all'
      if (widget.categoryKey != null && widget.categoryKey != 'all') {
        return shops.where((shop) => shop['category'] == widget.categoryKey).toList();
      }

      return shops;
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
      throw Exception('Не удалось загрузить заведения');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.shopName ?? 'Заведения и магазины';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          titleText,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Поиск по названию...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = "");
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
            ),
          ),

          // Загрузка данных через FutureBuilder
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _restaurantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'В базе данных пока нет активных заведений',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _restaurantsFuture = _loadDataAndUser();
                            });
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }

                // Локальная фильтрация по строке поиска (используем ключ 'title', который отдает бэкенд)
                final restaurants = snapshot.data!.where((item) {
                  final name = (item['title'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (restaurants.isEmpty) {
                  return const Center(
                    child: Text(
                      'Ничего не найдено по вашему запросу',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final data = restaurants[index];

                    // Соответствие ключей вашего бэкенда (/api/shops)
                    final docId = data['id']?.toString() ?? '';
                    final name = data['title'] ?? 'Без названия';
                    final logoUrl = data['image_url'] ?? data['imageUrl'] ?? '';

                    // 🔍 ДОБАВЛЯЕМ ЛОГ ДЛЯ ПРОВЕРКИ
                    print('📌 [DEBUG RESTAURANTS] Заведение: "$name" | image_url: "${data['image_url']}" | imageUrl: "${data['imageUrl']}" | Итог logoUrl: "$logoUrl"');

                    final time = data['time'] ?? '9:00 - 23:00';
                    final description = data['category'] ?? 'Экспресс доставка';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RestaurantMenuScreen(
                                  shopId: docId,
                                  restaurantName: name,
                                  restaurantImageUrl: logoUrl,
                                  userId: _userId, // 👈 Передаем динамический userId (например, '4')
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Логотип заведения
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: logoUrl.isNotEmpty
                                      ? Image.network(
                                    logoUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.store_rounded, color: Color(0xFF94A3B8)),
                                    ),
                                  )
                                      : Container(
                                    width: 64,
                                    height: 64,
                                    color: const Color(0xFFF1F5F9),
                                    child: const Icon(Icons.store_rounded, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Информация о заведении
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            time,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}