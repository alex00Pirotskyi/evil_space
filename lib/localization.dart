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
      'brand_title': 'EVIL SPACE',
      'hero_title': 'COWORKING',
      'hero_city': 'NHA TRANG',
      'nav_prices': 'PRICES',
      'nav_now': 'NOW',
      'nav_contact': 'CONTACT',
      'today': 'TODAY',
      'occupied': 'TABLES OCCUPIED',
      'free': 'FREE',
      'prices_title': 'PRICES',
      'price_day_pass': 'DAY PASS',
      'price_week': 'WEEK',
      'price_hot_desk': 'HOT DESK',
      'price_private_desk': 'PRIVATE DESK',
      'prices_currency': 'VND',
      'now_title': 'NOW',
      'contact_title': 'CONTACT',
      'contact_location': 'NHA TRANG, VIETNAM',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'MAP',
      'contact_messenger': 'MESSENGER',
      'contact_zalo': 'ZALO',
      'contact_phone': 'PHONE',
      'photos_note': 'REAL EVIL SPACE PHOTOS / RGB565 PIXELS',
    },
    'ru': {
      'brand_title': 'EVIL SPACE',
      'hero_title': 'КОВОРКИНГ',
      'hero_city': 'НЯЧАНГ',
      'nav_prices': 'ЦЕНЫ',
      'nav_now': 'СЕЙЧАС',
      'nav_contact': 'КОНТАКТЫ',
      'today': 'СЕГОДНЯ',
      'occupied': 'СТОЛОВ ЗАНЯТО',
      'free': 'СВОБОДНО',
      'prices_title': 'ЦЕНЫ',
      'price_day_pass': 'ДЕНЬ',
      'price_week': 'НЕДЕЛЯ',
      'price_hot_desk': 'ХОТ-ДЕСК',
      'price_private_desk': 'ЛИЧНЫЙ СТОЛ',
      'prices_currency': 'VND',
      'now_title': 'СЕЙЧАС',
      'contact_title': 'КОНТАКТЫ',
      'contact_location': 'НЯЧАНГ, ВЬЕТНАМ',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'КАРТА',
      'contact_messenger': 'MESSENGER',
      'contact_zalo': 'ZALO',
      'contact_phone': 'ТЕЛЕФОН',
      'photos_note': 'РЕАЛЬНЫЕ ФОТО EVIL SPACE / RGB565 PIXELS',
    },
    'vi': {
      'brand_title': 'EVIL SPACE',
      'hero_title': 'KHÔNG GIAN LÀM VIỆC',
      'hero_city': 'NHA TRANG',
      'nav_prices': 'BẢNG GIÁ',
      'nav_now': 'HÔM NAY',
      'nav_contact': 'LIÊN HỆ',
      'today': 'HÔM NAY',
      'occupied': 'BÀN ĐANG ĐƯỢC DÙNG',
      'free': 'BÀN TRỐNG',
      'prices_title': 'BẢNG GIÁ',
      'price_day_pass': 'VÉ NGÀY',
      'price_week': 'THEO TUẦN',
      'price_hot_desk': 'BÀN LINH HOẠT',
      'price_private_desk': 'BÀN RIÊNG',
      'prices_currency': 'VND',
      'now_title': 'HÔM NAY',
      'contact_title': 'LIÊN HỆ',
      'contact_location': 'NHA TRANG, VIỆT NAM',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'BẢN ĐỒ',
      'contact_messenger': 'MESSENGER',
      'contact_zalo': 'ZALO',
      'contact_phone': 'ĐIỆN THOẠI',
      'photos_note': 'ẢNH THẬT EVIL SPACE / RGB565 PIXELS',
    },
  };
}
