class Localization {
  // Set your default language here ('en', 'ru', or 'vi')
  static String currentLang = 'en';

  // Helper method to get a string
  static String get(String key) {
    return strings[currentLang]?[key] ?? strings['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> strings = {
    // ==========================================
    // ENGLISH
    // ==========================================
    'en': {
      'brand_title': 'EVIL SPACE',
      'home_subtitle': 'COWORKING',

      // Menu / Navigation
      'menu_feed': 'LIVE FEED',
      'menu_desk': 'DEDICATED DESK',
      'menu_office': 'PRIVATE OFFICE',
      'menu_studio': 'PODCAST/VIDEO STUDIO',
      'menu_contact': 'CONTACT US',

      // Desk Page
      'desk_title': 'DEDICATED DESK\nPRICES IN VND',
      'desk_day': 'DAY PASS',
      'desk_week': 'WEEK',
      'desk_hot': 'HOT DESK',
      'desk_private': 'PRIVATE DESK',

      // Office & Studio Pages
      'office_title': 'PRIVATE OFFICE',
      'studio_title': 'STUDIO RENT',
      'contact_msg': 'PLEASE CONTACT US\nFOR THE DETAILS',

      // Contact Page
      'contact_title': 'CONTACT US',
    },

    // ==========================================
    // RUSSIAN
    // ==========================================
    'ru': {
      'brand_title':
          'EVIL SPACE', // Usually best to keep brand names in English
      'home_subtitle': 'КОВОРКИНГ',

      // Menu / Navigation
      'menu_feed': 'НОВОСТИ',
      'menu_desk': 'СВОЙ СТОЛ',
      'menu_office': 'ЛИЧНЫЙ ОФИС',
      'menu_studio': 'СТУДИЯ',
      'menu_contact': 'КОНТАКТЫ',

      // Desk Page
      'desk_title': 'СВОЙ СТОЛ\nЦЕНЫ В VND',
      'desk_day': 'ДЕНЬ',
      'desk_week': 'НЕДЕЛЯ',
      'desk_hot': 'ХОТ-ДЕСК',
      'desk_private': 'ЛИЧНЫЙ СТОЛ',

      // Office & Studio Pages
      'office_title': 'ЛИЧНЫЙ ОФИС',
      'studio_title': 'АРЕНДА СТУДИИ',
      'contact_msg': 'СВЯЖИТЕСЬ С НАМИ\nДЛЯ ДЕТАЛЕЙ',

      // Contact Page
      'contact_title': 'КОНТАКТЫ',
    },

    // ==========================================
    // VIETNAMESE (Optimized for your 5-pixel font)
    // ==========================================
    'vi': {
      'brand_title': 'EVIL SPACE',
      'home_subtitle': 'COWORKING',

      // Menu / Navigation
      'menu_feed': 'TIN TƯC',
      'menu_desk': 'BAN RIÊNG',
      'menu_office': 'VĂN PHONG',
      'menu_studio': 'PHONG STUDIO',
      'menu_contact': 'LIÊN HÊ',

      // Desk Page
      'desk_title': 'BAN RIÊNG\nGIA Tinh BĂNG VND',
      'desk_day': 'THE NGAY',
      'desk_week': 'TUÂN',
      'desk_hot': 'BAN CHUNG',
      'desk_private': 'BAN RIÊNG',

      // Office & Studio Pages
      'office_title': 'VĂN PHONG',
      'studio_title': 'THUÊ STUDIO',
      'contact_msg': 'VUI LONG LIÊN HÊ\nĐÊ BIÊT CHI TIÊT',

      // Contact Page
      'contact_title': 'LIÊN HÊ',
    },
  };
}
