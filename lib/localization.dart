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
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  String t(String key) {
    return strings[_language.code]?[key] ?? strings['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> strings = {
    'en': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'NHA TRANG / COWORKING / OPEN DAILY 11:00–23:00',
      'desk_free': 'DESK FREE',
      'desks_free': 'DESKS FREE',
      'occupied': 'OCCUPIED',
      'updated_today': 'UPDATED TODAY',
      'updated': 'UPDATED',
      'local_data': 'LOCAL STATUS',
      'availability_kicker': 'TODAY AT EVIL SPACE',
      'availability_action': 'GET A DESK TODAY',
      'booking_title': 'GET A DESK TODAY',
      'booking_name': 'NAME',
      'booking_phone': 'PHONE',
      'booking_telegram': 'TELEGRAM',
      'booking_contact': 'CONTACT',
      'booking_send': 'SEND REQUEST',
      'booking_sent': 'REQUEST SENT TO EVIL SPACE',
      'booking_pending': 'YOUR REQUEST IS PENDING',
      'booking_accepted': 'YOU HAVE A BOOKING TODAY',
      'booking_delete': 'DELETE REQUEST',
      'booking_deleted': 'REQUEST DELETED',
      'booking_save_title': 'SAVE FOR NEXT TIME?',
      'booking_save_copy': 'Save this contact only on this device for one-click booking next time.',
      'booking_save': 'SAVE',
      'booking_not_now': 'NOT NOW',
      'booking_saved': 'ONE-CLICK CONTACT SAVED',
      'booking_forget': 'FORGET',
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
      'visit_copy': 'PHOTOS STAY ON INSTAGRAM AND GOOGLE MAPS. THIS PAGE STAYS QUIET.',
      'contact_location': '60 CAO VĂN BÉ / BẮC NHA TRANG / KHÁNH HÒA',
      'contact_instagram': 'INSTAGRAM',
      'contact_map': 'PHOTOS & REVIEWS',
      'contact_directions': 'DIRECTIONS',
      'contact_zalo': 'MESSAGE ZALO',
      'contact_telegram': 'TELEGRAM',
      'contact_phone': 'CALL',
      'page_one': 'PAGE 1 OF 1',
    },
    'ru': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'НЯЧАНГ / КОВОРКИНГ / ЕЖЕДНЕВНО 11:00–23:00',
      'desk_free': 'СВОБОДНЫЙ СТОЛ',
      'desks_free': 'СВОБОДНЫХ СТОЛОВ',
      'occupied': 'ЗАНЯТО',
      'updated_today': 'ОБНОВЛЕНО СЕГОДНЯ',
      'updated': 'ОБНОВЛЕНО',
      'local_data': 'ЛОКАЛЬНЫЙ СТАТУС',
      'availability_kicker': 'СЕГОДНЯ В EVIL SPACE',
      'availability_action': 'ЗАБРОНИРОВАТЬ СТОЛ',
      'booking_title': 'ЗАБРОНИРОВАТЬ СТОЛ',
      'booking_name': 'ИМЯ',
      'booking_phone': 'ТЕЛЕФОН',
      'booking_telegram': 'TELEGRAM',
      'booking_contact': 'КОНТАКТ',
      'booking_send': 'ОТПРАВИТЬ',
      'booking_sent': 'ЗАПРОС ОТПРАВЛЕН В EVIL SPACE',
      'booking_pending': 'ВАШ ЗАПРОС ОЖИДАЕТ ПОДТВЕРЖДЕНИЯ',
      'booking_accepted': 'У ВАС ЕСТЬ БРОНЬ НА СЕГОДНЯ',
      'booking_delete': 'УДАЛИТЬ ЗАПРОС',
      'booking_deleted': 'ЗАПРОС УДАЛЁН',
      'booking_save_title': 'СОХРАНИТЬ НА БУДУЩЕЕ?',
      'booking_save_copy': 'Сохранить контакт только на этом устройстве для бронирования в один клик в следующий раз.',
      'booking_save': 'СОХРАНИТЬ',
      'booking_not_now': 'НЕ СЕЙЧАС',
      'booking_saved': 'КОНТАКТ СОХРАНЁН ДЛЯ 1 КЛИКА',
      'booking_forget': 'ЗАБЫТЬ',
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
      'contact_telegram': 'TELEGRAM',
      'contact_phone': 'ПОЗВОНИТЬ',
      'page_one': 'СТРАНИЦА 1 ИЗ 1',
    },
    'vi': {
      'brand_daily': 'EVIL SPACE / DAILY',
      'hero_kicker': 'NHA TRANG / COWORKING / MỞ CỬA HẰNG NGÀY 11:00–23:00',
      'desk_free': 'BÀN TRỐNG',
      'desks_free': 'BÀN TRỐNG',
      'occupied': 'ĐANG DÙNG',
      'updated_today': 'CẬP NHẬT HÔM NAY',
      'updated': 'CẬP NHẬT',
      'local_data': 'TRẠNG THÁI NỘI BỘ',
      'availability_kicker': 'HÔM NAY TẠI EVIL SPACE',
      'availability_action': 'ĐẶT BÀN HÔM NAY',
      'booking_title': 'ĐẶT BÀN HÔM NAY',
      'booking_name': 'TÊN',
      'booking_phone': 'ĐIỆN THOẠI',
      'booking_telegram': 'TELEGRAM',
      'booking_contact': 'LIÊN HỆ',
      'booking_send': 'GỬI YÊU CẦU',
      'booking_sent': 'ĐÃ GỬI YÊU CẦU ĐẾN EVIL SPACE',
      'booking_pending': 'YÊU CẦU CỦA BẠN ĐANG CHỜ XÁC NHẬN',
      'booking_accepted': 'BẠN ĐÃ CÓ BÀN HÔM NAY',
      'booking_delete': 'XOÁ YÊU CẦU',
      'booking_deleted': 'ĐÃ XOÁ YÊU CẦU',
      'booking_save_title': 'LƯU CHO LẦN SAU?',
      'booking_save_copy': 'Chỉ lưu liên hệ trên thiết bị này để đặt bàn một chạm lần sau.',
      'booking_save': 'LƯU',
      'booking_not_now': 'KHÔNG LÚC NÀY',
      'booking_saved': 'ĐÃ LƯU LIÊN HỆ MỘT CHẠM',
      'booking_forget': 'XOÁ',
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
      'contact_telegram': 'TELEGRAM',
      'contact_phone': 'GỌI',
      'page_one': 'TRANG 1 / 1',
    },
  };
}
