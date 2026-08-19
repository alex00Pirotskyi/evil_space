import 'package:flutter/foundation.dart';
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
      'home_subtitle': 'COWORKING',
      'menu_feed': 'LIVE FEED',
      'menu_desk': 'DEDICATED DESK',
      'menu_office': 'PRIVATE OFFICE',
      'menu_studio': 'PODCAST/VIDEO STUDIO',
      'menu_gallery': 'PIXEL GALLERY',
      'menu_contact': 'CONTACT US',
      'feed_title': 'LIVE FEED',
      'feed_community': 'PREMIUM COWORKING IN NHA TRANG',
      'feed_workspace': 'DEDICATED DESKS AND PRIVATE OFFICES',
      'feed_studio': 'PODCAST/VIDEO STUDIO AVAILABLE',
      'desk_title': 'DEDICATED DESK\nPRICES IN VND',
      'desk_day': 'DAY PASS',
      'desk_week': 'WEEK',
      'desk_hot': 'HOT DESK',
      'desk_private': 'PRIVATE DESK',
      'office_title': 'PRIVATE OFFICE',
      'office_message': 'FLEXIBLE PRIVATE SPACE\nCONTACT US FOR DETAILS',
      'studio_title': 'PODCAST/VIDEO STUDIO',
      'studio_message': 'PODCAST AND VIDEO STUDIO\nCONTACT US FOR DETAILS',
      'gallery_title': 'PIXEL GALLERY',
      'gallery_hint': 'DROP IMAGES INTO\nASSETS/SLIDESHOW',
      'gallery_semantics': 'Evil Space RGB565 pixel image slideshow',
      'contact_title': 'CONTACT US',
      'contact_location': 'NHA TRANG VIETNAM',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'MAP',
      'contact_messenger': 'MESSENGER',
      'contact_zalo': 'ZALO',
      'contact_phone': 'PHONE',
    },
    'ru': {
      'brand_title': 'EVIL SPACE',
      'home_subtitle': 'КОВОРКИНГ',
      'menu_feed': 'НОВОСТИ',
      'menu_desk': 'РАБОЧИЕ МЕСТА',
      'menu_office': 'ЛИЧНЫЙ ОФИС',
      'menu_studio': 'ПОДКАСТ/ВИДЕО СТУДИЯ',
      'menu_gallery': 'ПИКСЕЛЬ ГАЛЕРЕЯ',
      'menu_contact': 'КОНТАКТЫ',
      'feed_title': 'НОВОСТИ',
      'feed_community': 'ПРЕМИУМ КОВОРКИНГ В НЯЧАНГЕ',
      'feed_workspace': 'РАБОЧИЕ МЕСТА И ЛИЧНЫЕ ОФИСЫ',
      'feed_studio': 'ПОДКАСТ/ВИДЕО СТУДИЯ ДОСТУПНА',
      'desk_title': 'РАБОЧИЕ МЕСТА\nЦЕНЫ В VND',
      'desk_day': 'ДЕНЬ',
      'desk_week': 'НЕДЕЛЯ',
      'desk_hot': 'ХОТ-ДЕСК',
      'desk_private': 'ЛИЧНЫЙ СТОЛ',
      'office_title': 'ЛИЧНЫЙ ОФИС',
      'office_message': 'ГИБКОЕ ЛИЧНОЕ ПРОСТРАНСТВО\nСВЯЖИТЕСЬ С НАМИ',
      'studio_title': 'ПОДКАСТ/ВИДЕО СТУДИЯ',
      'studio_message': 'СТУДИЯ ДЛЯ ПОДКАСТОВ И ВИДЕО\nСВЯЖИТЕСЬ С НАМИ',
      'gallery_title': 'ПИКСЕЛЬ ГАЛЕРЕЯ',
      'gallery_hint': 'ДОБАВЬТЕ ФОТО В\nASSETS/SLIDESHOW',
      'gallery_semantics': 'RGB565 пиксельное слайд-шоу Evil Space',
      'contact_title': 'КОНТАКТЫ',
      'contact_location': 'НЯЧАНГ ВЬЕТНАМ',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'КАРТА',
      'contact_messenger': 'MESSENGER',
      'contact_zalo': 'ZALO',
      'contact_phone': 'ТЕЛЕФОН',
    },
    'vi': {
      'brand_title': 'EVIL SPACE',
      'home_subtitle': 'KHÔNG GIAN LÀM VIỆC',
      'menu_feed': 'TIN MỚI',
      'menu_desk': 'BÀN LÀM VIỆC',
      'menu_office': 'VĂN PHÒNG RIÊNG',
      'menu_studio': 'STUDIO PODCAST/VIDEO',
      'menu_gallery': 'THƯ VIỆN PIXEL',
      'menu_contact': 'LIÊN HỆ',
      'feed_title': 'TIN MỚI',
      'feed_community': 'COWORKING CAO CẤP TẠI NHA TRANG',
      'feed_workspace': 'BÀN RIÊNG VÀ VĂN PHÒNG RIÊNG',
      'feed_studio': 'STUDIO PODCAST/VIDEO SẴN SÀNG',
      'desk_title': 'BÀN LÀM VIỆC\nGIÁ VND',
      'desk_day': 'VÉ NGÀY',
      'desk_week': 'THEO TUẦN',
      'desk_hot': 'BÀN LINH HOẠT',
      'desk_private': 'BÀN RIÊNG',
      'office_title': 'VĂN PHÒNG RIÊNG',
      'office_message': 'KHÔNG GIAN RIÊNG LINH HOẠT\nLIÊN HỆ ĐỂ BIẾT CHI TIẾT',
      'studio_title': 'STUDIO PODCAST/VIDEO',
      'studio_message': 'STUDIO PODCAST VÀ VIDEO\nLIÊN HỆ ĐỂ BIẾT CHI TIẾT',
      'gallery_title': 'THƯ VIỆN PIXEL',
      'gallery_hint': 'THẢ ẢNH VÀO\nASSETS/SLIDESHOW',
      'gallery_semantics': 'Trình chiếu ảnh pixel RGB565 của Evil Space',
      'contact_title': 'LIÊN HỆ',
      'contact_location': 'NHA TRANG VIỆT NAM',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'BẢN ĐỒ',
      'contact_messenger': 'MESSENGER',
      'contact_zalo': 'ZALO',
      'contact_phone': 'ĐIỆN THOẠI',
    },
  };
}
