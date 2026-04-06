import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dish_model.dart';
import '../../models/cart_item.dart';
import '../Menu/Cart_data.dart';
import '../Menu/cart_screen.dart';
import 'Buket_md.dart';
import 'Mir_svetov.dart';
import 'Svetok_sentr.dart';

// Модель цветочного магазина
class Floare {
  final String name;
  final String description;
  final double rating;
  final String time;
  final String imagePath;
  final String shopId;

  Floare({
    required this.name,
    required this.description,
    required this.rating,
    required this.time,
    required this.imagePath,
    required this.shopId,
  });
}

// Пример данных
final floarele = [
  Floare(
    name: 'Мир цветов',
    description: 'Свежие цветы, букеты и композиции на любой повод',
    rating: 4.8,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/mir.png',
    shopId: 'mir_svetov',
  ),
  Floare(
    name: 'Цветочный центр',
    description: 'Букеты, комнатные растения и праздничное оформление',
    rating: 4.7,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/flower.jpg',
    shopId: 'svetok_sentr',
  ),
  Floare(
    name: 'Buket.md',
    description: 'Авторские букеты',
    rating: 4.9,
    time: '8:00 – 21:00',
    imagePath: 'assets/images/bucket.jpg',
    shopId: 'buket_md',
  ),
];

class FloareScreen extends StatelessWidget {
  final void Function(Dish, String) addToCart;

  const FloareScreen({super.key, required this.addToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Цветы'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: floarele.length,
        itemBuilder: (context, index) {
          final floare = floarele[index];

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              // Меню по shopId
              List<Dish> menu;
              switch (floare.shopId) {
                case 'mir_svetov':
                  menu = mir_svetov;
                  break;
                case 'svetok_sentr':
                  menu = svetok_sentr;
                  break;
                case 'buket_md':
                  menu = buket_menu;
                  break;
                default:
                  menu = [];
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FloareMenuScreen(
                    restaurantName: floare.name,
                    menu: menu,
                    shopId: floare.shopId,
                    addToCart: addToCart,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.asset(
                      floare.imagePath,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(floare.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(floare.description),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(floare.rating.toString()),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(floare.time),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FloareMenuScreen extends StatefulWidget {
  final String restaurantName;
  final List<Dish> menu;
  final String shopId;
  final void Function(Dish, String) addToCart;

  const FloareMenuScreen({
    super.key,
    required this.restaurantName,
    required this.menu,
    required this.shopId,
    required this.addToCart,
  });

  @override
  State<FloareMenuScreen> createState() => _FloareMenuScreenState();
}

class _FloareMenuScreenState extends State<FloareMenuScreen> {
  String _searchQuery = '';
  late final User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Войдите в аккаунт'));

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
                MaterialPageRoute(
                  builder: (_) => CartScreen(
                    shopId: widget.shopId,
                    restaurantName: widget.restaurantName,
                  ),
                ),
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
                hintText: 'Поиск цветов',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.menu.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.63,
                crossAxisSpacing: 5,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                final dish = widget.menu[i];
                if (!dish.name.toLowerCase().contains(_searchQuery)) return const SizedBox.shrink();

                return DishCardWithStatus(
                  dish: dish,
                  shopId: widget.shopId,
                  userId: user!.uid,
                  addToCart: widget.addToCart,
                );
              },
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
  final String userId;
  final void Function(Dish, String) addToCart;

  const DishCardWithStatus({
    required this.dish,
    required this.shopId,
    required this.userId,
    required this.addToCart,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: getCart(userId, shopId),
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
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${dish.price.toStringAsFixed(0)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
