import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BusinessStopListScreen extends StatelessWidget {
  final String shopId;

  const BusinessStopListScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("СТОП-ЛИСТ",
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .doc(shopId)
            .collection('menu')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("В меню пока нет товаров",
                    style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var itemDoc = snapshot.data!.docs[index];
              var data = itemDoc.data() as Map<String, dynamic>;

              bool isAvailable = data['isAvailable'] ?? true;
              String title = data['title'] ?? 'Без названия';
              String image = data['imagePath'] ?? '';
              int price = data['price'] ?? 0;
              String weight = data['weight'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12), // Внутренний отступ вместо ListTile
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.white : Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                  border: isAvailable
                      ? null
                      : Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    // КАРТИНКА (фикс размер)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                        image: image.isNotEmpty
                            ? DecorationImage(
                            image: NetworkImage(image), fit: BoxFit.cover)
                            : null,
                      ),
                      child: image.isEmpty
                          ? const Icon(Icons.fastfood, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // ИНФОРМАЦИЯ (занимает всё свободное место)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1, // Ограничение в 1 строку
                            overflow: TextOverflow.ellipsis, // Троеточие при переполнении
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isAvailable ? Colors.black : Colors.grey[600],
                              decoration: isAvailable ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$price Руб • $weight",
                            style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    // УПРАВЛЕНИЕ
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.8, // Немного уменьшаем свитч, чтобы влез
                          child: Switch.adaptive(
                            value: isAvailable,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              itemDoc.reference.update({'isAvailable': val});
                            },
                          ),
                        ),
                        Text(
                          isAvailable ? "ВКЛ" : "ВЫКЛ",
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}