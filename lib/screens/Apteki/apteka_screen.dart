import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:untitled1/screens/Apteki/apteka_menu.dart';

class AptekaScreen extends StatefulWidget {
  const AptekaScreen({super.key});

  @override
  State<AptekaScreen> createState() => _AptekaScreenState();
}

class _AptekaScreenState extends State<AptekaScreen> {
  // Переменная для текста поиска
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Аптеки',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // ПОЛЕ ПОИСКА (в том же стиле, что и в ресторанах)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Найти аптеку...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ОСНОВНОЙ СПИСОК
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .where('category', isEqualTo: 'apteka')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Ошибка загрузки'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
                }

                // Фильтруем документы на лету
                final allDocs = snapshot.data!.docs;
                final docs = allDocs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_pharmacy_outlined, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty ? 'Аптеки пока не найдены' : 'Аптека не найдена',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String docId = docs[index].id;
                    final String? logoUrl = data['logoUrl'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AptekaMenuScreen(
                                restaurantName: data['name'] ?? 'Аптека',
                                shopId: docId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                                    child: logoUrl != null && logoUrl.isNotEmpty
                                        ? Image.network(
                                      logoUrl,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          height: 200,
                                          color: Colors.grey[100],
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        );
                                      },
                                      errorBuilder: (c, e, s) => Container(
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                                      ),
                                    )
                                        : Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.local_pharmacy_rounded, color: Colors.redAccent, size: 50),
                                    ),
                                  ),
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                                          const SizedBox(width: 4),
                                          Text(
                                            data['rating']?.toString() ?? '5.0',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name'] ?? 'Без названия',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (data['description'] != null)
                                      Text(
                                        data['description'],
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 16),
                                    _buildInfoTag(
                                      icon: Icons.access_time_filled_rounded,
                                      label: data['time'] ?? '8:00 - 21:00',
                                      color: Colors.blueGrey[50]!,
                                      iconColor: Colors.blueGrey,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: iconColor.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}