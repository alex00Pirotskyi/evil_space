import 'package:flutter/widgets.dart';

enum AppLanguage {
  en('en'),
  ru('ru'),
  vi('vi');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromLocale(Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    return AppLanguage.values.firstWhere(
      (language) => language.code == languageCode,
      orElse: () => AppLanguage.en,
    );
  }
}

class LocalizationController extends ChangeNotifier {
  LocalizationController([this._language = AppLanguage.en]);

  factory LocalizationController.fromPlatform() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return LocalizationController(AppLanguage.fromLocale(locale));
  }

  AppLanguage _language;

  AppLanguage get language => _language;

  void setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();
  }

  String t(String key) {
    return strings[_language.code]?[key] ?? strings['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> strings = {
    'en': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'NHA TRANG / COWORKING',
      'desk_free': 'DESK FREE',
      'desks_free': 'DESKS FREE',
      'occupied': 'OCCUPIED',
      'updated_today': 'UPDATED TODAY',
      'updated': 'UPDATED',
      'local_data': 'LOCAL STATUS',
      'availability_kicker': 'TODAY AT EVIL SPACE',
      'availability_action': 'GET A DESK TODAY',
      'message_zalo': 'MESSAGE ZALO',
      'prices_title': 'TWO SIMPLE PRICES',
      'price_day_pass': 'DAY PASS',
      'price_month': 'ONE MONTH',
      'opening_title': 'OPENING 20 OCTOBER',
      'opening_studio': 'PODCAST / STUDIO ROOM',
      'opening_lecture': 'LECTURE ROOM',
      'coming_soon': 'COMING SOON',
      'now_open': 'NOW OPEN',
      'notes_title': "TODAY'S NOTE",
      'visit_title': 'FIND EVIL SPACE',
      'visit_copy':
          'PHOTOS STAY ON INSTAGRAM AND GOOGLE MAPS. THIS PAGE STAYS QUIET.',
      'contact_location': '60 CAO VĂN BÉ / BẮC NHA TRANG / KHÁNH HÒA',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'PHOTOS & REVIEWS',
      'contact_directions': 'DIRECTIONS',
      'contact_zalo': 'MESSAGE ZALO',
      'contact_phone': 'CALL',
      'page_one': 'PAGE 1 OF 1',
    },
    'ru': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'НЯЧАНГ / КОВОРКИНГ',
      'desk_free': 'СВОБОДНЫЙ СТОЛ',
      'desks_free': 'СВОБОДНЫХ СТОЛОВ',
      'occupied': 'ЗАНЯТО',
      'updated_today': 'ОБНОВЛЕНО СЕГОДНЯ',
      'updated': 'ОБНОВЛЕНО',
      'local_data': 'ЛОКАЛЬНЫЙ СТАТУС',
      'availability_kicker': 'СЕГОДНЯ В EVIL SPACE',
      'availability_action': 'ЗАБРОНИРОВАТЬ СТОЛ',
      'message_zalo': 'НАПИСАТЬ В ZALO',
      'prices_title': 'ДВЕ ПРОСТЫЕ ЦЕНЫ',
      'price_day_pass': 'ДЕНЬ',
      'price_month': 'ОДИН МЕСЯЦ',
      'opening_title': 'ОТКРЫТИЕ 20 ОКТЯБРЯ',
      'opening_studio': 'ПОДКАСТ / СТУДИЯ',
      'opening_lecture': 'ЛЕКЦИОННЫЙ ЗАЛ',
      'coming_soon': 'СКОРО',
      'now_open': 'УЖЕ ОТКРЫТО',
      'notes_title': 'ЗАМЕТКА НА СЕГОДНЯ',
      'visit_title': 'НАЙТИ EVIL SPACE',
      'visit_copy': 'ФОТО — В INSTAGRAM И GOOGLE MAPS. ЗДЕСЬ ОСТАЁТСЯ ТИШИНА.',
      'contact_location': '60 CAO VĂN BÉ / СЕВЕРНЫЙ НЯЧАНГ / KHÁNH HÒA',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'ФОТО И ОТЗЫВЫ',
      'contact_directions': 'МАРШРУТ',
      'contact_zalo': 'НАПИСАТЬ В ZALO',
      'contact_phone': 'ПОЗВОНИТЬ',
      'page_one': 'СТРАНИЦА 1 ИЗ 1',
    },
    'vi': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'NHA TRANG / COWORKING',
      'desk_free': 'BÀN TRỐNG',
      'desks_free': 'BÀN TRỐNG',
      'occupied': 'ĐANG DÙNG',
      'updated_today': 'CẬP NHẬT HÔM NAY',
      'updated': 'CẬP NHẬT',
      'local_data': 'TRẠNG THÁI NỘI BỘ',
      'availability_kicker': 'HÔM NAY TẠI EVIL SPACE',
      'availability_action': 'ĐẶT BÀN HÔM NAY',
      'message_zalo': 'NHẮN ZALO',
      'prices_title': 'HAI MỨC GIÁ ĐƠN GIẢN',
      'price_day_pass': 'VÉ NGÀY',
      'price_month': 'MỘT THÁNG',
      'opening_title': 'KHAI TRƯƠNG 20 THÁNG 10',
      'opening_studio': 'PHÒNG PODCAST / STUDIO',
      'opening_lecture': 'PHÒNG HỘI THẢO',
      'coming_soon': 'SẮP RA MẮT',
      'now_open': 'ĐÃ MỞ CỬA',
      'notes_title': 'GHI CHÚ HÔM NAY',
      'visit_title': 'TÌM EVIL SPACE',
      'visit_copy': 'ẢNH Ở INSTAGRAM VÀ GOOGLE MAPS. TRANG NÀY LUÔN YÊN TĨNH.',
      'contact_location': '60 CAO VĂN BÉ / BẮC NHA TRANG / KHÁNH HÒA',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'ẢNH & ĐÁNH GIÁ',
      'contact_directions': 'CHỈ ĐƯỜNG',
      'contact_zalo': 'NHẮN ZALO',
      'contact_phone': 'GỌI',
      'page_one': 'TRANG 1 / 1',
    },
  };
}
