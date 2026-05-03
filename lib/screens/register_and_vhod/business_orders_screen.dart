import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BusinessOrdersScreen extends StatelessWidget {
  final String shopId;

  const BusinessOrdersScreen({super.key, required this.shopId});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('orders')
            .where('shopId', isEqualTo: shopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Активных заказов нет", style: TextStyle(color: Colors.grey)));
          }

          // Сортировка на стороне клиента (свежие сверху)
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
              String status = data['status'] ?? 'new';

              // УДАЛЯЕМ ИЗ СПИСКА: Если статус "ready", "canceled", "delivered" или "completed"
              // Заказ исчезнет с экрана сразу после нажатия кнопки "ГОТОВО"
              if (status == 'ready' || status == 'canceled' || status == 'delivered' || status == 'completed') {
                return const SizedBox.shrink();
              }

              return _buildOrderCard(context, data, orderDoc.reference);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> data, DocumentReference ref) {
    String status = data['status'] ?? 'new';
    List items = data['items'] as List? ?? [];
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
                    _statusBadge(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(data['clientName'] ?? "Клиент", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Divider(height: 24),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text("${item['quantity']}x ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      Expanded(child: Text("${item['name']}", style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),

          // БЛОК С 3 КНОПКАМИ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // 1. КНОПКА ОТМЕНА -> ставит статус 'canceled' и время 'canceledAt'
                Expanded(
                  child: _actionBtn("ОТМЕНА", Colors.redAccent, () {
                    _updateOrder(ref, 'canceled', 'canceledAt');
                  }),
                ),
                const SizedBox(width: 8),

                // 2. КНОПКА НАЧАТЬ -> ставит статус 'preparing' и время 'startedAt'
                Expanded(
                  child: _actionBtn(
                      "НАЧАТЬ",
                      status == 'new' ? Colors.blue : Colors.blue.withOpacity(0.3),
                      status == 'new' ? () => _updateOrder(ref, 'preparing', 'startedAt') : null
                  ),
                ),
                const SizedBox(width: 8),

                // 3. КНОПКА ГОТОВО -> ставит статус 'ready' и время 'readyAt' (ЗАКАЗ УДАЛИТСЯ ИЗ СПИСКА)
                Expanded(
                  child: _actionBtn(
                      "ГОТОВО",
                      status == 'preparing' ? Colors.green : Colors.green.withOpacity(0.3),
                      status == 'preparing' ? () => _updateOrder(ref, 'ready', 'readyAt') : null
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Общая функция для обновления статуса и времени в Firestore
  void _updateOrder(DocumentReference ref, String status, String timeField) {
    ref.update({
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(), // Всегда обновляем общее время изменения
      timeField: FieldValue.serverTimestamp(),         // Обновляем конкретное время (startedAt/readyAt/canceledAt)
    });
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
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    );
  }

  Widget _statusBadge(String status) {
    String text = "НОВЫЙ";
    Color col = Colors.blue;
    if (status == 'preparing') { text = "ГОТОВИТСЯ"; col = Colors.orange; }
    if (status == 'ready') { text = "ГОТОВ"; col = Colors.green; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}