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
      const SnackBar(content: Text('Настройки сохранены')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          _buildSwitch(
            title: 'Push-уведомления',
            subtitle: 'Разрешить все уведомления',
            value: push,
            onChanged: (v) {
              setState(() => push = v);
              _save();
            },
          ),
          const Divider(),

          _buildSwitch(
            title: 'Статус заказа',
            subtitle: 'Изменения по заказам',
            value: order,
            onChanged: push
                ? (v) {
              setState(() => order = v);
              _save();
            }
                : null,
          ),
          const Divider(),

          _buildSwitch(
            title: 'Акции и скидки',
            subtitle: 'Специальные предложения',
            value: promo,
            onChanged: push
                ? (v) {
              setState(() => promo = v);
              _save();
            }
                : null,
          ),
          const Divider(),

          _buildSwitch(
            title: 'Новости и обновления',
            subtitle: 'Новые функции приложения',
            value: news,
            onChanged: push
                ? (v) {
              setState(() => news = v);
              _save();
            }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepOrange,
    );
  }
}
