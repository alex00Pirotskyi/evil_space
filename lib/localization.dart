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
      'hero_kicker': 'NHA TRANG / COWORKING / DAILY STATUS',
      'nav_prices': 'PRICES',
      'nav_notes': 'TODAY',
      'nav_visit': 'VISIT',
      'desk_free': 'DESK FREE',
      'desks_free': 'DESKS FREE',
      'occupied': 'OCCUPIED',
      'updated_today': 'UPDATED TODAY',
      'updated': 'UPDATED',
      'local_data': 'LOCAL STATUS',
      'day_pass_now': 'DAY PASS',
      'message_zalo': 'MESSAGE ZALO',
      'work_title': 'WORK HERE.',
      'work_intro': 'THE THINGS THAT MATTER WHEN YOU ACTUALLY HAVE TO WORK ALL DAY.',
      'feature_big_desks': 'BIG DESKS',
      'feature_good_chairs': 'GOOD CHAIRS',
      'feature_fast_wifi': 'FAST WI-FI',
      'feature_cold_ac': 'COLD AC',
      'prices_title': 'PRICE LIST',
      'price_day_pass': 'DAY PASS',
      'price_week': 'WEEK',
      'price_hot_desk': 'HOT DESK',
      'price_private_desk': 'PRIVATE DESK',
      'notes_title': "TODAY'S NOTE",
      'notes_intro': 'A SMALL BULLETIN FROM THE SPACE. NO FEED, NO NOISE.',
      'visit_title': 'VISITING?',
      'visit_copy': 'REAL PHOTOS LIVE ON INSTAGRAM. DIRECTIONS LIVE ON MAPS.',
      'contact_location': 'NHA TRANG, VIETNAM',
      'contact_instagram': 'SEE THE SPACE',
      'contact_map': 'OPEN MAP',
      'contact_zalo': 'ZALO',
      'contact_phone': 'CALL',
      'contact_messenger': 'MESSENGER',
      'page_one': 'PAGE 1 OF 1',
    },
    'ru': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'НЯЧАНГ / КОВОРКИНГ / СТАТУС',
      'nav_prices': 'ЦЕНЫ',
      'nav_notes': 'СЕГОДНЯ',
      'nav_visit': 'К НАМ',
      'desk_free': 'СВОБОДНЫЙ СТОЛ',
      'desks_free': 'СВОБОДНЫХ СТОЛОВ',
      'occupied': 'ЗАНЯТО',
      'updated_today': 'ОБНОВЛЕНО СЕГОДНЯ',
      'updated': 'ОБНОВЛЕНО',
      'local_data': 'ЛОКАЛЬНЫЙ СТАТУС',
      'day_pass_now': 'ДЕНЬ',
      'message_zalo': 'НАПИСАТЬ В ZALO',
      'work_title': 'РАБОТАЙ ЗДЕСЬ.',
      'work_intro': 'ТО, ЧТО ДЕЙСТВИТЕЛЬНО ВАЖНО, КОГДА РАБОТАЕШЬ ВЕСЬ ДЕНЬ.',
      'feature_big_desks': 'БОЛЬШИЕ СТОЛЫ',
      'feature_good_chairs': 'ХОРОШИЕ КРЕСЛА',
      'feature_fast_wifi': 'БЫСТРЫЙ WI-FI',
      'feature_cold_ac': 'ХОЛОДНЫЙ КОНДИЦИОНЕР',
      'prices_title': 'ЦЕНЫ',
      'price_day_pass': 'ДЕНЬ',
      'price_week': 'НЕДЕЛЯ',
      'price_hot_desk': 'ХОТ-ДЕСК',
      'price_private_desk': 'ЛИЧНЫЙ СТОЛ',
      'notes_title': 'ЗАМЕТКА НА СЕГОДНЯ',
      'notes_intro': 'КОРОТКО ИЗ EVIL SPACE. БЕЗ ЛЕНТЫ И ЛИШНЕГО ШУМА.',
      'visit_title': 'ЗАЙДЕШЬ?',
      'visit_copy': 'РЕАЛЬНЫЕ ФОТО — В INSTAGRAM. МАРШРУТ — В MAPS.',
      'contact_location': 'НЯЧАНГ, ВЬЕТНАМ',
      'contact_instagram': 'ПОСМОТРЕТЬ ПРОСТРАНСТВО',
      'contact_map': 'ОТКРЫТЬ КАРТУ',
      'contact_zalo': 'ZALO',
      'contact_phone': 'ПОЗВОНИТЬ',
      'contact_messenger': 'MESSENGER',
      'page_one': 'СТРАНИЦА 1 ИЗ 1',
    },
    'vi': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'NHA TRANG / COWORKING / TRẠNG THÁI HÔM NAY',
      'nav_prices': 'BẢNG GIÁ',
      'nav_notes': 'HÔM NAY',
      'nav_visit': 'GHÉ QUA',
      'desk_free': 'BÀN TRỐNG',
      'desks_free': 'BÀN TRỐNG',
      'occupied': 'ĐANG DÙNG',
      'updated_today': 'CẬP NHẬT HÔM NAY',
      'updated': 'CẬP NHẬT',
      'local_data': 'TRẠNG THÁI NỘI BỘ',
      'day_pass_now': 'VÉ NGÀY',
      'message_zalo': 'NHẮN ZALO',
      'work_title': 'LÀM VIỆC Ở ĐÂY.',
      'work_intro': 'NHỮNG THỨ THỰC SỰ QUAN TRỌNG KHI BẠN LÀM VIỆC CẢ NGÀY.',
      'feature_big_desks': 'BÀN RỘNG',
      'feature_good_chairs': 'GHẾ TỐT',
      'feature_fast_wifi': 'WI-FI NHANH',
      'feature_cold_ac': 'MÁY LẠNH MÁT',
      'prices_title': 'BẢNG GIÁ',
      'price_day_pass': 'VÉ NGÀY',
      'price_week': 'THEO TUẦN',
      'price_hot_desk': 'BÀN LINH HOẠT',
      'price_private_desk': 'BÀN RIÊNG',
      'notes_title': 'GHI CHÚ HÔM NAY',
      'notes_intro': 'MỘT BẢN TIN NGẮN TỪ EVIL SPACE. KHÔNG FEED, KHÔNG ỒN ÀO.',
      'visit_title': 'GHÉ QUA?',
      'visit_copy': 'ẢNH THẬT Ở INSTAGRAM. CHỈ ĐƯỜNG Ở MAPS.',
      'contact_location': 'NHA TRANG, VIỆT NAM',
      'contact_instagram': 'XEM KHÔNG GIAN',
      'contact_map': 'MỞ BẢN ĐỒ',
      'contact_zalo': 'ZALO',
      'contact_phone': 'GỌI',
      'contact_messenger': 'MESSENGER',
      'page_one': 'TRANG 1 / 1',
    },
  };
}
