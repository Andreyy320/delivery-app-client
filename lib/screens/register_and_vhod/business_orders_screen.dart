import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BusinessOrdersScreen extends StatelessWidget {
  final String shopId;

  const BusinessOrdersScreen({super.key, required this.shopId});

  // --- ЛОГИКА СОХРАНЕНИЯ В ИСТОРИЮ ЗАВЕДЕНИЯ ---
  Future<void> _syncToShopHistory(String orderId, Map<String, dynamic> updateData) async {
    final shopHistoryRef = FirebaseFirestore.instance
        .collection('categories')
        .doc(shopId)
        .collection('ordersHistory')
        .doc(orderId);

    await shopHistoryRef.set({
      ...updateData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Получение категории для изменения текста кнопок (Сборка или Начать)
  Future<String> _getShopCategory() async {
    final doc = await FirebaseFirestore.instance
        .collection('categories')
        .doc(shopId)
        .get();
    return doc.data()?['category']?.toString().trim().toLowerCase() ?? 'restaurant';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("ПАНЕЛЬ УПРАВЛЕНИЯ",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: FutureBuilder<String>(
        future: _getShopCategory(),
        builder: (context, categorySnapshot) {
          final shopCategory = categorySnapshot.data ?? 'restaurant';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('orders')
                .where('shopId', isEqualTo: shopId)
                .where('status', whereIn: ['new', 'preparing', 'accepted', 'ready'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.black));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Активных заказов нет", style: TextStyle(color: Colors.grey)));
              }

              List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
              docs.sort((a, b) {
                Timestamp t1 = (a.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                Timestamp t2 = (b.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var orderDoc = docs[index];
                  var data = orderDoc.data() as Map<String, dynamic>;
                  return _buildOrderCard(context, data, orderDoc.reference, shopCategory);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> data, DocumentReference ref, String category) {
    String status = data['status'] ?? 'new';
    List items = data['items'] as List? ?? [];
    String orderId = ref.id;
    String clientComment = data['restaurantComment'] ?? '';
    String timeStr = data['createdAt'] != null
        ? DateFormat('HH:mm').format((data['createdAt'] as Timestamp).toDate())
        : "--:--";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ЗАКАЗ от $timeStr", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                    _statusBadge(status, category),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['clientName'] ?? "Клиент", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text("${data['total'] ?? 0} Руб", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ],
                ),

                _buildCourierSection(data),

                if (clientComment.isNotEmpty) _buildCommentBox(clientComment),

                const Divider(height: 24),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text("${item['quantity']}x ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      Expanded(child: Text("${item['name']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Text("${item['price']} Руб", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: _buildActionButtons(context, data, ref, category, orderId),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCourierSection(Map<String, dynamic> data) {
    if (data['courierId'] == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text("• Ожидание курьера", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          const Icon(Icons.delivery_dining, size: 16, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            "Курьер: ${data['courierName'] ?? 'Назначен'} (${data['courierPhone'] ?? ''})",
            style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBox(String comment) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("КОММЕНТАРИЙ:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 2),
          Text(comment, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, Map<String, dynamic> data, DocumentReference ref, String category, String orderId) {
    String status = data['status'] ?? 'new';
    bool isShop = ['svetok', 'apteka', 'product', 'electronika'].contains(category);

    String startText = isShop ? "СБОРКА" : "НАЧАТЬ";
    String readyText = isShop ? "ОТПРАВЛЕН" : "ГОТОВО";

    return [
      Expanded(
        child: _actionBtn("ОТМЕНА", Colors.redAccent, () async {
          final updateData = {'status': 'canceled', 'canceledAt': FieldValue.serverTimestamp(), 'statusUpdatedAt': FieldValue.serverTimestamp()};
          await ref.update(updateData);
          await _syncToShopHistory(orderId, {...data, ...updateData});
        }),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _actionBtn(
            startText,
            status == 'new' ? Colors.blue : Colors.blue.withOpacity(0.3),
            status == 'new' ? () => _showTimePicker(context, ref, orderId, data) : null
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _actionBtn(
            readyText,
            (status == 'preparing' || status == 'accepted') ? Colors.green : Colors.green.withOpacity(0.3),
            (status == 'preparing' || status == 'accepted') ? () async {
              final updateData = {'status': 'ready', 'readyAt': FieldValue.serverTimestamp(), 'statusUpdatedAt': FieldValue.serverTimestamp()};
              await ref.update(updateData);
              await _syncToShopHistory(orderId, {...data, ...updateData});
            } : null
        ),
      ),
    ];
  }

  void _showTimePicker(BuildContext context, DocumentReference ref, String orderId, Map<String, dynamic> currentData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('ЧЕРЕЗ СКОЛЬКО БУДЕТ ГОТОВО?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 24),
            Row(
              children: [15, 30, 45, 60].map((mins) => Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final estimatedTime = DateTime.now().add(Duration(minutes: mins));
                    final updateData = {
                      'status': 'preparing',
                      'startedAt': FieldValue.serverTimestamp(),
                      'estimatedReadyTime': Timestamp.fromDate(estimatedTime),
                      'statusUpdatedAt': FieldValue.serverTimestamp(),
                    };
                    await ref.update(updateData);
                    await _syncToShopHistory(orderId, {...currentData, ...updateData});
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text("$mins мин", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback? onTap) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
      ),
    );
  }

  Widget _statusBadge(String status, String category) {
    String text = "НОВЫЙ";
    Color col = Colors.orange;
    bool isShop = ['svetok', 'apteka', 'product', 'electronika'].contains(category);

    switch (status) {
      case 'preparing':
        text = isShop ? "СБОРКА" : "ГОТОВИТСЯ";
        col = Colors.blue;
        break;
      case 'accepted':
        text = "ПРИНЯТ";
        col = Colors.purple;
        break;
      case 'ready':
        text = "ГОТОВ";
        col = Colors.teal;
        break;
      case 'canceled':
        text = "ОТМЕНЕН";
        col = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}