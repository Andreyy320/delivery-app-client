import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsStorage {
  static const _pushEnabled = 'push_enabled';
  static const _orderStatus = 'order_status_notifications';
  static const _promotions = 'promo_notifications';
  static const _news = 'news_notifications';

  static Future<Map<String, bool>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'push': prefs.getBool(_pushEnabled) ?? true,
      'order': prefs.getBool(_orderStatus) ?? true,
      'promo': prefs.getBool(_promotions) ?? true,
      'news': prefs.getBool(_news) ?? true,
    };
  }

  static Future<void> save({
    required bool push,
    required bool order,
    required bool promo,
    required bool news,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_pushEnabled, push);
    await prefs.setBool(_orderStatus, order);
    await prefs.setBool(_promotions, promo);
    await prefs.setBool(_news, news);
  }
}
