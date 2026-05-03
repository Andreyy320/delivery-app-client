import 'package:flutter/material.dart';
import 'notification_settings_storage.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool push = true;
  bool order = true;
  bool promo = true;
  bool news = true;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await NotificationSettingsStorage.load();
    setState(() {
      push = data['push']!;
      order = data['order']!;
      promo = data['promo']!;
      news = data['news']!;
      isLoading = false;
    });
  }

  Future<void> _save() async {
    await NotificationSettingsStorage.save(
      push: push,
      order: order,
      promo: promo,
      news: news,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Настройки сохранены', style: TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Уведомления',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Центр оповещений ',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Выберите, какие уведомления вы хотите получать, чтобы всегда быть в курсе событий.',
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 30),

              // ГЛАВНЫЙ ПЕРЕКЛЮЧАТЕЛЬ
              Container(
                decoration: BoxDecoration(
                  color: push ? Colors.deepOrange.withOpacity(0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: push ? Colors.deepOrange.withOpacity(0.2) : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: _buildSwitch(
                  title: 'Push-уведомления',
                  subtitle: 'Общий контроль всех оповещений',
                  value: push,
                  icon: Icons.notifications_active_rounded,
                  onChanged: (v) {
                    setState(() => push = v);
                    _save();
                  },
                ),
              ),

              const SizedBox(height: 30),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'КАТЕГОРИИ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 12),

              // БЛОК С ДЕТАЛЬНЫМИ НАСТРОЙКАМИ
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  children: [
                    _buildSwitch(
                      title: 'Статус заказа',
                      subtitle: 'Оповещения о ходе доставки',
                      value: order,
                      icon: Icons.local_shipping_rounded,
                      onChanged: push ? (v) {
                        setState(() => order = v);
                        _save();
                      } : null,
                    ),
                    _divider(),
                    _buildSwitch(
                      title: 'Акции и скидки',
                      subtitle: 'Промокоды и подарки',
                      value: promo,
                      icon: Icons.confirmation_number_rounded,
                      onChanged: push ? (v) {
                        setState(() => promo = v);
                        _save();
                      } : null,
                    ),
                    _divider(),
                    _buildSwitch(
                      title: 'Новости',
                      subtitle: 'Обновления и новые функции',
                      value: news,
                      icon: Icons.auto_awesome_rounded,
                      onChanged: push ? (v) {
                        setState(() => news = v);
                        _save();
                      } : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey[200], indent: 60);

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool>? onChanged,
  }) {
    final bool isDisabled = onChanged == null;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: isDisabled ? Colors.grey[400] : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDisabled ? Colors.grey[300] : Colors.grey[500],
          fontWeight: FontWeight.w500,
        ),
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.grey[300] : Colors.deepOrange,
          size: 24,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepOrange,
      activeTrackColor: Colors.deepOrange.withOpacity(0.3),
    );
  }
}