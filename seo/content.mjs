// Public facts here are intentionally limited to details confirmed by the live
// booking app and the owner. Keep translations and the Business Profile in sync.
export const business = Object.freeze({
  name: 'Evil Space',
  origin: 'https://evils.space',
  street: '60 Cao Văn Bé',
  ward: 'Vĩnh Phước',
  city: 'Nha Trang',
  region: 'Khánh Hòa',
  phone: '+84565056748',
  maps: 'https://maps.app.goo.gl/5AFFB2AzszcsFvSz5?g_st=ic',
  instagram: 'https://www.instagram.com/evil_space_coworking',
  opens: '11:00',
  closes: '23:00',
  desks: 10,
  dayVnd: 200000,
  monthVnd: 2500000,
});

export const languages = Object.freeze({
  en: {
    htmlLang: 'en', ogLocale: 'en_US', label: 'English',
    common: {
      issue: 'A quiet place to get things done',
      navigation: 'Main navigation', breadcrumbs: 'Breadcrumbs', language: 'Language',
      home: 'Coworking', prices: 'Prices', visit: 'Find us', book: 'Check desks & book',
      open: 'Open daily', address: '60 Cao Văn Bé, Vĩnh Phước, Nha Trang',
      day: 'Day pass', month: 'One month', hours: 'Daily hours',
      bookingNote: 'Desk availability and the final price are shown in the booking app. A request is confirmed after the team accepts it.',
      maps: 'Open Google Maps', photos: 'Photos & reviews', phone: 'Call Evil Space',
      explore: 'Explore Evil Space', questions: 'Good to know',
      next: 'Plan your workday',
      related: {
        home: 'Coworking in Nha Trang at Evil Space',
        pricing: 'Day pass and monthly coworking prices in Nha Trang',
        visit: 'Address, hours and directions to Evil Space in Nha Trang',
      },
      footer: 'A quieter workday in Nha Trang.',
      business: 'Evil Space coworking, Nha Trang',
    },
    pages: {
      home: {
        title: 'Coworking Space in Nha Trang | Evil Space',
        description: 'Coworking space in Nha Trang at 60 Cao Văn Bé, Vĩnh Phước. Day passes from the regular 200K VND rate, monthly desks and online booking.',
        eyebrow: 'Nha Trang / Coworking / Open 11:00–23:00',
        heading: 'A coworking space in Nha Trang for a day or a month.',
        lead: 'Work from Evil Space at 60 Cao Văn Bé in Vĩnh Phước, Nha Trang. Choose a day pass or ask about a monthly desk; we open every day from 11:00 to 23:00.',
        sections: [
          { heading: 'Choose the day that works', paragraphs: [
            'See current desk availability and request a desk for today or tomorrow online. The space has ten desks; availability changes as people book.',
            'A day pass is 200K VND at the regular rate. If an offer is active, the booking page shows the price for the selected day before you send a request.',
          ] },
          { heading: 'Stay for the month', paragraphs: [
            'If Nha Trang is your base, the one-month coworking option is 2.5 million VND. Check the current details with the team before committing to a month.',
            'We are open every day from 11:00 to 23:00, so you can plan a work session around your own schedule.',
          ] },
          { heading: 'A real place in Nha Trang', paragraphs: [
            'Find us at 60 Cao Văn Bé in Vĩnh Phước. Get directions on Google Maps, browse real photos and reviews there, or call before you visit.',
          ] },
        ],
        faqs: [
          { q: 'Can I book a desk for tomorrow?', a: 'Yes. The booking app accepts requests for today and tomorrow and shows availability for both days.' },
          { q: 'Where is this Nha Trang coworking space?', a: 'Evil Space is at 60 Cao Văn Bé, Vĩnh Phước, Nha Trang. Follow the Google Maps link on this page to check the location and see photos before visiting.' },
        ],
        ctaHeading: 'Your desk is a few taps away.',
        ctaText: 'Check live availability, choose today or tomorrow, and send your booking request.',
      },
      pricing: {
        title: 'Coworking Prices in Nha Trang | Evil Space',
        description: 'Evil Space coworking prices in Nha Trang: 200K VND regular day pass or 2.5 million VND for one month. Check availability and book online.',
        eyebrow: 'Simple choices / No long list of plans',
        heading: 'A day here, or a month of work.',
        lead: 'Choose the time you need at Evil Space. The regular day pass is 200K VND and the one-month coworking option is 2.5 million VND.',
        sections: [
          { heading: 'Day pass · 200K VND', paragraphs: [
            'A straightforward choice when you need a coworking desk in Nha Trang for a day. See today’s or tomorrow’s remaining desks and send a request through the booking app.',
            'The app displays the current price for your chosen day. A temporary promotion can change that price, and the team confirms your request after receiving it.',
          ] },
          { heading: 'One month · 2.5 million VND', paragraphs: [
            'A simpler choice when you expect to work here regularly. Contact the team to arrange a month and confirm the current terms before paying.',
            'The space opens daily from 11:00 to 23:00 at 60 Cao Văn Bé, Vĩnh Phước, Nha Trang.',
          ] },
          { heading: 'Visit before deciding', paragraphs: [
            'See the address and directions, call with any questions, and check the real photos and reviews on Google Maps. You can start with a day before arranging a month.',
          ] },
        ],
        faqs: [
          { q: 'Is the displayed day price always the final price?', a: 'The booking app shows the current price for the day you select, including an active promotion if there is one.' },
          { q: 'Is a booking confirmed as soon as I send it?', a: 'A request is sent to Evil Space first. Your desk is confirmed after the team accepts it.' },
        ],
        ctaHeading: 'See today’s available desks.',
        ctaText: 'The live booking page has current availability and the price for today or tomorrow.',
      },
      visit: {
        title: 'Find Evil Space Coworking in Nha Trang | Address & Hours',
        description: 'Visit Evil Space coworking at 60 Cao Văn Bé, Vĩnh Phước, Nha Trang. Open daily 11:00–23:00. Get directions, see photos and check desks.',
        eyebrow: '60 Cao Văn Bé / Vĩnh Phước / Nha Trang',
        heading: 'Find your way to Evil Space.',
        lead: 'We are at 60 Cao Văn Bé in Vĩnh Phước, Nha Trang, Khánh Hòa. The coworking space is open every day from 11:00 to 23:00.',
        sections: [
          { heading: 'Get directions', paragraphs: [
            'Open our Google Maps listing for directions and check the pin before travelling. The listing also has photos and customer reviews so you can see the space before arriving.',
            'If you are unsure about the entrance or plan to arrive late, call us using the number below.',
          ] },
          { heading: 'Check before you come', paragraphs: [
            'The booking app shows how many of the ten desks are available today and tomorrow. Send a request in advance if you want to work here; the team will confirm it.',
            'For a day, the regular pass is 200K VND. You can also ask about the one-month coworking option.',
          ] },
          { heading: 'Photos, reviews and contact', paragraphs: [
            'We keep the website simple. See the latest space photos and reviews on Google Maps or Instagram, and call if you have a question about visiting.',
          ] },
        ],
        faqs: [
          { q: 'What are the opening hours?', a: 'Evil Space is open every day from 11:00 until 23:00. Check the Maps listing for any special holiday hours.' },
          { q: 'Can I check availability before travelling?', a: 'Yes. The booking app shows live availability for today and tomorrow.' },
        ],
        ctaHeading: 'On your way?',
        ctaText: 'Open directions, or check the available desks before you leave.',
      },
    },
  },
  ru: {
    htmlLang: 'ru', ogLocale: 'ru_RU', label: 'Русский',
    common: {
      issue: 'Спокойное место для работы',
      navigation: 'Навигация', breadcrumbs: 'Путь к странице', language: 'Язык',
      home: 'Коворкинг', prices: 'Цены', visit: 'Как добраться', book: 'Посмотреть места и забронировать',
      open: 'Ежедневно', address: '60 Cao Văn Bé, Vĩnh Phước, Нячанг',
      day: 'Один день', month: 'Один месяц', hours: 'Часы работы',
      bookingNote: 'Количество свободных мест и окончательная цена указаны при бронировании. Заявка подтверждается после ответа команды.',
      maps: 'Открыть Google Maps', photos: 'Фото и отзывы', phone: 'Позвонить в Evil Space',
      explore: 'Узнать об Evil Space', questions: 'Полезно знать',
      next: 'Спланируйте рабочий день',
      related: {
        home: 'Коворкинг Evil Space в Нячанге',
        pricing: 'Цены на рабочее место на день и месяц в Нячанге',
        visit: 'Адрес, часы работы и маршрут до Evil Space в Нячанге',
      },
      footer: 'Работать в Нячанге может быть спокойнее.',
      business: 'Коворкинг Evil Space в Нячанге',
    },
    pages: {
      home: {
        title: 'Коворкинг в Нячанге — Evil Space | Рабочее место на день и месяц',
        description: 'Коворкинг Evil Space в Нячанге: 60 Cao Văn Bé, рабочее место на день или месяц, ежедневно с 11:00 до 23:00. Проверить свободные места.',
        eyebrow: 'Нячанг / Коворкинг / Ежедневно 11:00–23:00',
        heading: 'Коворкинг в Нячанге для хорошего рабочего дня.',
        lead: 'Evil Space — коворкинг в Нячанге для тех, кому нужен рабочий стол и время сосредоточиться. Приходите на день или выберите место на месяц.',
        sections: [
          { heading: 'Выберите удобный день', paragraphs: [
            'На сайте можно посмотреть свободные столы и отправить заявку на сегодня или завтра. Всего в пространстве десять мест; их доступность меняется по мере бронирования.',
            'Обычная стоимость дня — 200 000 донгов. Если действует акция, при бронировании отобразится цена на выбранную дату.',
          ] },
          { heading: 'Работайте целый месяц', paragraphs: [
            'Если вы остаётесь в Нячанге, месяц работы в коворкинге стоит 2,5 млн донгов. Перед оплатой уточните актуальные условия у команды.',
            'Мы открыты ежедневно с 11:00 до 23:00: рабочее время можно подобрать под свой график.',
          ] },
          { heading: 'Реальное место в Нячанге', paragraphs: [
            'Ждём вас по адресу 60 Cao Văn Bé, район Vĩnh Phước. На Google Maps можно построить маршрут, посмотреть настоящие фотографии и отзывы или позвонить нам перед визитом.',
          ] },
        ],
        faqs: [
          { q: 'Можно забронировать стол на завтра?', a: 'Да. В приложении можно отправить заявку на сегодня или завтра и посмотреть свободные места на обе даты.' },
          { q: 'Где находится коворкинг в Нячанге?', a: 'Evil Space находится по адресу 60 Cao Văn Bé, район Vĩnh Phước, Нячанг. Ссылку на маршрут и настоящие фотографии можно найти на этой странице.' },
        ],
        ctaHeading: 'Ваш рабочий стол уже близко.',
        ctaText: 'Посмотрите свободные места, выберите сегодня или завтра и отправьте заявку.',
      },
      pricing: {
        title: 'Цены на коворкинг в Нячанге | Evil Space',
        description: 'Цены Evil Space в Нячанге: день — 200 000 донгов, месяц — 2,5 млн донгов. Узнать о свободных местах и отправить заявку онлайн.',
        eyebrow: 'Два понятных варианта',
        heading: 'На один день или на месяц.',
        lead: 'Выберите подходящий срок работы в Evil Space. Обычная цена дня — 200 000 донгов, месяц в коворкинге — 2,5 млн донгов.',
        sections: [
          { heading: 'День · 200 000 донгов', paragraphs: [
            'Простой вариант, если вам нужен рабочий стол в Нячанге на один день. Посмотрите свободные места на сегодня или завтра и отправьте заявку через приложение.',
            'В приложении показана актуальная цена на выбранный день. Во время акции она может отличаться; команда подтвердит вашу заявку после получения.',
          ] },
          { heading: 'Месяц · 2,5 млн донгов', paragraphs: [
            'Подходит тем, кто планирует регулярно работать здесь. Свяжитесь с командой, чтобы оформить месяц и уточнить условия до оплаты.',
            'Пространство открыто ежедневно с 11:00 до 23:00 по адресу 60 Cao Văn Bé, Vĩnh Phước, Нячанг.',
          ] },
          { heading: 'Сначала загляните', paragraphs: [
            'Проверьте адрес и маршрут, позвоните с вопросами, посмотрите настоящие фотографии и отзывы на Google Maps. Можно начать с одного дня.',
          ] },
        ],
        faqs: [
          { q: 'Цена за день всегда одинаковая?', a: 'При бронировании отображается цена на выбранную дату, в том числе с учётом действующей акции.' },
          { q: 'Стол подтверждается сразу после отправки заявки?', a: 'Сначала заявка поступает в Evil Space. Бронирование подтверждено после того, как команда её примет.' },
        ],
        ctaHeading: 'Проверьте места на сегодня.',
        ctaText: 'В приложении указаны свободные столы и цена на сегодня или завтра.',
      },
      visit: {
        title: 'Как найти коворкинг Evil Space в Нячанге | Адрес и часы',
        description: 'Evil Space: 60 Cao Văn Bé, Vĩnh Phước, Нячанг. Открыто ежедневно с 11:00 до 23:00. Маршрут, фотографии и свободные места.',
        eyebrow: '60 Cao Văn Bé / Vĩnh Phước / Нячанг',
        heading: 'Как нас найти.',
        lead: 'Evil Space находится по адресу 60 Cao Văn Bé, район Vĩnh Phước, Нячанг, провинция Кханьхоа. Коворкинг открыт каждый день с 11:00 до 23:00.',
        sections: [
          { heading: 'Постройте маршрут', paragraphs: [
            'Откройте нашу карточку в Google Maps, чтобы проложить маршрут и проверить отметку на карте. Там же есть фотографии и отзывы гостей.',
            'Если не можете найти вход или собираетесь прийти поздно, позвоните нам по указанному ниже номеру.',
          ] },
          { heading: 'Проверьте места заранее', paragraphs: [
            'В приложении показано, сколько из десяти столов свободно сегодня и завтра. Если хотите поработать у нас, отправьте заявку; команда подтвердит её.',
            'Обычная стоимость дня — 200 000 донгов. Можно также узнать об условиях работы на месяц.',
          ] },
          { heading: 'Фото, отзывы и связь', paragraphs: [
            'Мы оставили сайт простым. Свежие фотографии пространства и отзывы можно посмотреть на Google Maps или в Instagram, а с вопросами — позвонить.',
          ] },
        ],
        faqs: [
          { q: 'В какие часы вы работаете?', a: 'Ежедневно с 11:00 до 23:00. Часы работы в праздничные дни лучше проверить в Google Maps.' },
          { q: 'Можно узнать о свободных местах до поездки?', a: 'Да. Приложение показывает свободные места на сегодня и завтра.' },
        ],
        ctaHeading: 'Собираетесь к нам?',
        ctaText: 'Постройте маршрут или проверьте свободные места перед выходом.',
      },
    },
  },
  vi: {
    htmlLang: 'vi', ogLocale: 'vi_VN', label: 'Tiếng Việt',
    common: {
      issue: 'Một nơi yên tĩnh để tập trung làm việc',
      navigation: 'Điều hướng', breadcrumbs: 'Đường dẫn trang', language: 'Ngôn ngữ',
      home: 'Không gian làm việc', prices: 'Bảng giá', visit: 'Đường đến đây', book: 'Xem bàn trống & đặt chỗ',
      open: 'Mở cửa hằng ngày', address: '60 Cao Văn Bé, Vĩnh Phước, Nha Trang',
      day: 'Vé ngày', month: 'Một tháng', hours: 'Giờ mở cửa',
      bookingNote: 'Số bàn còn trống và giá cuối cùng được hiển thị khi đặt chỗ. Yêu cầu được xác nhận sau khi nhân viên chấp nhận.',
      maps: 'Mở Google Maps', photos: 'Ảnh & đánh giá', phone: 'Gọi Evil Space',
      explore: 'Khám phá Evil Space', questions: 'Thông tin hữu ích',
      next: 'Lên kế hoạch làm việc',
      related: {
        home: 'Coworking Evil Space tại Nha Trang',
        pricing: 'Giá vé ngày và gói coworking theo tháng tại Nha Trang',
        visit: 'Địa chỉ, giờ mở cửa và đường đến Evil Space ở Nha Trang',
      },
      footer: 'Một ngày làm việc yên tĩnh hơn tại Nha Trang.',
      business: 'Không gian làm việc chung Evil Space tại Nha Trang',
    },
    pages: {
      home: {
        title: 'Coworking Nha Trang | Không gian làm việc Evil Space',
        description: 'Evil Space là không gian coworking tại 60 Cao Văn Bé, Nha Trang. Có vé ngày, gói tháng, mở cửa 11:00–23:00 và nhận đặt bàn trực tuyến.',
        eyebrow: 'Nha Trang / Không gian làm việc / 11:00–23:00',
        heading: 'Không gian coworking tại Nha Trang cho một ngày hoặc một tháng.',
        lead: 'Evil Space là không gian làm việc chung tại Nha Trang dành cho những ai cần một chiếc bàn và thời gian để tập trung. Ghé làm việc một ngày hoặc chọn gói một tháng.',
        sections: [
          { heading: 'Chọn ngày phù hợp', paragraphs: [
            'Bạn có thể xem số bàn còn trống và gửi yêu cầu đặt chỗ cho hôm nay hoặc ngày mai. Không gian có tổng cộng mười bàn; số chỗ trống thay đổi khi có khách đặt.',
            'Giá vé ngày thông thường là 200.000 VND. Nếu đang có ưu đãi, trang đặt chỗ sẽ hiển thị giá cho ngày bạn chọn trước khi gửi yêu cầu.',
          ] },
          { heading: 'Làm việc trong một tháng', paragraphs: [
            'Nếu bạn ở Nha Trang lâu hơn, gói làm việc một tháng có giá 2,5 triệu VND. Hãy liên hệ để xác nhận điều kiện hiện tại trước khi đăng ký.',
            'Evil Space mở cửa mỗi ngày từ 11:00 đến 23:00, thuận tiện để sắp xếp thời gian làm việc theo lịch của bạn.',
          ] },
          { heading: 'Một địa điểm thật tại Nha Trang', paragraphs: [
            'Chúng tôi ở 60 Cao Văn Bé, phường Vĩnh Phước. Bạn có thể xem đường đi, ảnh thật và đánh giá trên Google Maps hoặc gọi trước khi ghé.',
          ] },
        ],
        faqs: [
          { q: 'Tôi có thể đặt bàn cho ngày mai không?', a: 'Có. Ứng dụng nhận yêu cầu cho hôm nay và ngày mai, đồng thời hiển thị số bàn còn trống của cả hai ngày.' },
          { q: 'Không gian coworking này nằm ở đâu tại Nha Trang?', a: 'Evil Space ở 60 Cao Văn Bé, phường Vĩnh Phước, Nha Trang. Bạn có thể xem vị trí trên Google Maps và tham khảo ảnh thật trước khi ghé.' },
        ],
        ctaHeading: 'Bàn làm việc của bạn đang chờ.',
        ctaText: 'Xem chỗ trống, chọn hôm nay hoặc ngày mai rồi gửi yêu cầu đặt bàn.',
      },
      pricing: {
        title: 'Giá coworking tại Nha Trang | Evil Space',
        description: 'Bảng giá Evil Space tại Nha Trang: vé ngày thông thường 200.000 VND hoặc gói tháng 2,5 triệu VND. Xem bàn trống và đặt chỗ trực tuyến.',
        eyebrow: 'Hai lựa chọn rõ ràng',
        heading: 'Một ngày hoặc cả tháng.',
        lead: 'Chọn thời gian làm việc phù hợp tại Evil Space. Vé ngày thông thường có giá 200.000 VND; gói làm việc một tháng là 2,5 triệu VND.',
        sections: [
          { heading: 'Vé ngày · 200.000 VND', paragraphs: [
            'Lựa chọn đơn giản khi bạn cần một bàn làm việc tại Nha Trang trong ngày. Xem chỗ trống hôm nay hoặc ngày mai và gửi yêu cầu qua ứng dụng.',
            'Ứng dụng hiển thị giá hiện tại của ngày bạn chọn. Giá có thể thay đổi khi có ưu đãi; nhân viên sẽ xác nhận sau khi nhận yêu cầu.',
          ] },
          { heading: 'Một tháng · 2,5 triệu VND', paragraphs: [
            'Phù hợp khi bạn dự định làm việc tại đây thường xuyên. Hãy liên hệ để đăng ký gói tháng và xác nhận điều kiện trước khi thanh toán.',
            'Không gian mở cửa hằng ngày từ 11:00 đến 23:00 tại 60 Cao Văn Bé, phường Vĩnh Phước, Nha Trang.',
          ] },
          { heading: 'Ghé xem trước khi quyết định', paragraphs: [
            'Xem địa chỉ và đường đi, gọi nếu cần hỏi thêm, tham khảo ảnh thật cùng đánh giá trên Google Maps. Bạn có thể bắt đầu bằng một ngày làm việc.',
          ] },
        ],
        faqs: [
          { q: 'Giá vé ngày luôn cố định không?', a: 'Ứng dụng hiển thị giá cho ngày bạn chọn, bao gồm ưu đãi đang áp dụng nếu có.' },
          { q: 'Gửi yêu cầu là đã đặt được bàn chưa?', a: 'Yêu cầu sẽ được gửi đến Evil Space trước. Bàn được xác nhận sau khi nhân viên chấp nhận.' },
        ],
        ctaHeading: 'Xem bàn trống hôm nay.',
        ctaText: 'Trang đặt chỗ hiển thị số bàn còn trống và giá hiện tại cho hôm nay hoặc ngày mai.',
      },
      visit: {
        title: 'Địa chỉ Evil Space tại Nha Trang | Giờ mở cửa & đường đi',
        description: 'Ghé Evil Space tại 60 Cao Văn Bé, Vĩnh Phước, Nha Trang. Mở cửa hằng ngày 11:00–23:00. Xem đường đi, hình ảnh và bàn trống.',
        eyebrow: '60 Cao Văn Bé / Vĩnh Phước / Nha Trang',
        heading: 'Đường đến Evil Space.',
        lead: 'Evil Space ở 60 Cao Văn Bé, phường Vĩnh Phước, Nha Trang, Khánh Hòa. Không gian làm việc mở cửa mỗi ngày từ 11:00 đến 23:00.',
        sections: [
          { heading: 'Xem đường đi', paragraphs: [
            'Mở địa điểm trên Google Maps để tìm đường và kiểm tra vị trí ghim trước khi xuất phát. Tại đó cũng có ảnh và đánh giá của khách để bạn xem trước không gian.',
            'Nếu bạn chưa rõ lối vào hoặc dự định ghé muộn, hãy gọi theo số điện thoại bên dưới.',
          ] },
          { heading: 'Kiểm tra chỗ trước khi ghé', paragraphs: [
            'Ứng dụng cho biết còn bao nhiêu trong tổng số mười bàn vào hôm nay và ngày mai. Nếu muốn làm việc tại đây, hãy gửi yêu cầu để nhân viên xác nhận.',
            'Vé ngày thông thường có giá 200.000 VND. Bạn cũng có thể hỏi thêm về gói làm việc một tháng.',
          ] },
          { heading: 'Ảnh, đánh giá và liên hệ', paragraphs: [
            'Chúng tôi giữ trang web thật gọn. Ảnh mới và đánh giá về không gian nằm trên Google Maps hoặc Instagram; bạn có thể gọi nếu cần hỏi thêm.',
          ] },
        ],
        faqs: [
          { q: 'Evil Space mở cửa lúc nào?', a: 'Mỗi ngày từ 11:00 đến 23:00. Vui lòng xem Google Maps để biết giờ đặc biệt vào ngày lễ.' },
          { q: 'Tôi có thể xem bàn trống trước khi đến không?', a: 'Có. Ứng dụng hiển thị số bàn còn trống của hôm nay và ngày mai.' },
        ],
        ctaHeading: 'Bạn sắp ghé?',
        ctaText: 'Xem đường đi hoặc kiểm tra bàn còn trống trước khi xuất phát.',
      },
    },
  },
});
