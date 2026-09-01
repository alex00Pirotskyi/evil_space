import {
  bookingDayKind,
  bookingWindow,
  compactServiceDate,
  isBookableServiceDay,
  nhaTrangDayBounds,
  serviceDateKey,
  serviceDayForOffset,
  serviceDayFromCompactDate,
  visitTimestampForServiceDay,
} from './booking_rules.js';
import { resolvePricing } from './pricing.js';
const SESSION_COOKIE = '__Host-evil_admin_session';
const BOT_USERNAME = 'CoworkingEvilAdminBot';
const ADMIN_LINK_TTL = 10 * 60;
const CUSTOMER_LINK_TTL = 30 * 60 * 60;
const SESSION_TTL = 30 * 60;
const MAX_NAME_LENGTH = 100;
const MAX_TEXT_LENGTH = 180;
const WIFI_SSID = 'Evil Space';
const LANGUAGES = new Set(['en', 'ru', 'vi']);

const TEXT = {
  en: {
    adminConnected: '✅ <b>TELEGRAM ADMIN CONNECTED</b>',
    adminConnectedCopy: 'You can operate Evil Space from this chat.',
    customerConnected: '✅ <b>BOOKING UPDATES CONNECTED</b>',
    customerConnectedCopy: 'We will message you here when Evil Space accepts or declines your desk request.',
    customerPending: '⏳ <b>BOOKING REQUEST SENT</b>',
    customerPendingCopy: 'Your request is waiting for an Evil Space admin.',
    customerAccepted: '✅ <b>BOOKING ACCEPTED</b>',
    customerAcceptedCopy: 'Your desk at Evil Space is confirmed.\nOpen daily 11:00–23:00.\n\nYou can cancel here anytime if your plans change.',
    customerDeclined: '❌ <b>BOOKING DECLINED</b>',
    customerDeclinedCopy: 'We could not confirm this desk request. You can make another request anytime at evils.space.',
    customerCancelled: '🚫 <b>BOOKING CANCELLED</b>',
    customerCancelledCopy: 'Your desk is no longer counted as occupied.',
    customerNoBooking: 'You do not have an active desk request for today or tomorrow.',
    unlinked: 'This Telegram account is not linked.\n\nAdmins: open evils.space/admin → Telegram.\nCustomers: open evils.space and press TG when booking.',
    today: 'TODAY',
    tomorrow: 'TOMORROW',
    date: 'Date',
    price: 'Price',
    bookings: 'BOOKINGS',
    dayPass: 'DAY PASS',
    month: 'MONTH',
    customers: 'CUSTOMERS',
    income: 'INCOME',
    buy: 'BUY',
    settings: 'SETTINGS',
    language: 'LANGUAGE',
    back: 'BACK',
    accept: 'ACCEPT',
    decline: 'DECLINE',
    openAdmin: 'OPEN ADMIN',
    openSite: 'OPEN EVIL SPACE',
    cancelBooking: 'CANCEL BOOKING',
    cancelRequest: 'CANCEL REQUEST',
    cancelConfirm: 'Cancel this desk request?',
    confirmCancel: 'YES, CANCEL',
    keepBooking: 'KEEP BOOKING',
    bookingKept: 'Booking kept.',
    directions: 'DIRECTIONS',
    wifi: 'WI-FI',
    copyNetwork: 'COPY NETWORK',
    copyPassword: 'COPY PASSWORD',
    occupied: 'Occupied',
    pendingBookings: 'Pending bookings',
    nobody: 'Nobody yet.',
    noPending: '✅ No pending bookings.',
    newDeskRequest: '🔔 NEW DESK REQUEST',
    bookingAcceptedTitle: '✅ BOOKING ACCEPTED',
    bookingDeclinedTitle: '❌ BOOKING DECLINED',
    bookingCancelledTitle: '🚫 BOOKING CANCELLED',
    phone: 'PHONE',
    time: 'Time',
    by: 'By',
    dayPrompt: 'DAY PASS · send the customer name.\n\n/cancel to stop.',
    monthPrompt: 'NEW MONTH PASS · send the customer name.\n\n/cancel to stop.',
    customerPrompt: 'CUSTOMERS · send a name, phone, Telegram or email to search.\n\n/cancel to stop.',
    purchasePrompt: 'PURCHASE · send what needs to be bought.\n\n/cancel to stop.',
    cancelled: 'Cancelled.',
    confirm: 'CONFIRM',
    cancel: 'CANCEL',
    confirmQuestion: 'Confirm?',
    newMonthPass: 'NEW MONTH PASS',
    checkInActive: 'CHECK IN ACTIVE MEMBER',
    noActiveMembers: 'No active memberships.',
    activeMembers: 'ACTIVE MEMBERS · tap to check in',
    nameRequired: 'Name is required.',
    purchaseRequired: 'Purchase title is required.',
    actionExpired: 'This action expired. Start again.',
    dayAdded: 'Day pass added.',
    monthAdded: 'Month pass added.',
    purchaseAdded: 'Purchase request added.',
    noCustomers: 'No customers found.',
    noContact: 'No contact',
    activeUntil: 'ACTIVE UNTIL',
    noActiveMonth: 'NO ACTIVE MONTH PASS',
    addPurchase: 'ADD PURCHASE',
    toBuy: '🛒 TO BUY\n\nTap an item after it has been bought.',
    notifications: '⚙️ NOTIFICATIONS',
    purchases: 'Purchases',
    on: 'ON',
    off: 'OFF',
    updated: 'Updated.',
    bookingAcceptedCallback: 'Booking accepted.',
    bookingDeclinedCallback: 'Booking declined.',
    bookingCancelledCallback: 'Booking cancelled.',
    checkedIn: 'Checked in.',
    markedBought: 'Marked bought.',
    invalidBooking: 'Invalid booking.',
    notLinkedAdmin: 'Telegram is not linked to an approved admin.',
    bookingNotYours: 'This booking is not linked to you.',
    bookingExpired: 'This booking has expired.',
    wifiAfterAccept: 'Wi-Fi is available after the booking is accepted.',
    wifiNotConfigured: 'Wi-Fi access is not configured yet.',
    wifiSent: 'Wi-Fi details sent.',
    network: 'Network',
    password: 'Password',
    languageTitle: '🌐 <b>LANGUAGE</b>\n\nChoose the language for this bot.',
    languageChanged: 'Language updated.',
    bookingAlreadyActive: 'You already have an active desk request for this day.',
    purchaseNotification: '🛒 <b>NEW PURCHASE REQUEST</b>',
    purchaseNotificationCopy: 'Open /buy to manage the shared list.',
    help: 'EVIL SPACE ADMIN\n\n/menu — main menu\n/today — today\n/bookings — pending desk requests\n/day Name — day pass\n/month Name — new month pass\n/customer Alex — search customers\n/income — income\n/buy Item — add purchase request\n/settings — notifications\n/language — language\n/cancel — cancel current action',
  },
  ru: {
    adminConnected: '✅ <b>TELEGRAM АДМИНИСТРАТОРА ПОДКЛЮЧЁН</b>',
    adminConnectedCopy: 'Теперь Evil Space можно управлять прямо из этого чата.',
    customerConnected: '✅ <b>УВЕДОМЛЕНИЯ О БРОНИ ПОДКЛЮЧЕНЫ</b>',
    customerConnectedCopy: 'Мы напишем сюда, когда Evil Space примет или отклонит ваш запрос.',
    customerPending: '⏳ <b>ЗАПРОС НА БРОНЬ ОТПРАВЛЕН</b>',
    customerPendingCopy: 'Запрос ожидает подтверждения администратора Evil Space.',
    customerAccepted: '✅ <b>БРОНЬ ПОДТВЕРЖДЕНА</b>',
    customerAcceptedCopy: 'Ваш стол в Evil Space подтверждён.\nРаботаем ежедневно 11:00–23:00.\n\nЕсли планы изменятся, бронь можно отменить здесь.',
    customerDeclined: '❌ <b>БРОНЬ ОТКЛОНЕНА</b>',
    customerDeclinedCopy: 'Мы не смогли подтвердить этот запрос. Новый запрос можно отправить в любое время на evils.space.',
    customerCancelled: '🚫 <b>БРОНЬ ОТМЕНЕНА</b>',
    customerCancelledCopy: 'Стол больше не считается занятым.',
    customerNoBooking: 'У вас нет активной брони на сегодня или завтра.',
    unlinked: 'Этот Telegram не подключён.\n\nАдминистратор: откройте evils.space/admin → Telegram.\nКлиент: откройте evils.space и при бронировании нажмите TG.',
    today: 'СЕГОДНЯ',
    tomorrow: 'ЗАВТРА',
    date: 'Дата',
    price: 'Цена',
    bookings: 'БРОНИ',
    dayPass: 'ДЕНЬ',
    month: 'МЕСЯЦ',
    customers: 'КЛИЕНТЫ',
    income: 'ДОХОД',
    buy: 'КУПИТЬ',
    settings: 'НАСТРОЙКИ',
    language: 'ЯЗЫК',
    back: 'НАЗАД',
    accept: 'ПРИНЯТЬ',
    decline: 'ОТКЛОНИТЬ',
    openAdmin: 'ОТКРЫТЬ АДМИНКУ',
    openSite: 'ОТКРЫТЬ EVIL SPACE',
    cancelBooking: 'ОТМЕНИТЬ БРОНЬ',
    cancelRequest: 'ОТМЕНИТЬ ЗАПРОС',
    cancelConfirm: 'Отменить этот запрос на стол?',
    confirmCancel: 'ДА, ОТМЕНИТЬ',
    keepBooking: 'ОСТАВИТЬ БРОНЬ',
    bookingKept: 'Бронь сохранена.',
    directions: 'МАРШРУТ',
    wifi: 'WI-FI',
    copyNetwork: 'КОПИРОВАТЬ СЕТЬ',
    copyPassword: 'КОПИРОВАТЬ ПАРОЛЬ',
    occupied: 'Занято',
    pendingBookings: 'Ожидают подтверждения',
    nobody: 'Пока никого.',
    noPending: '✅ Нет ожидающих броней.',
    newDeskRequest: '🔔 НОВЫЙ ЗАПРОС НА СТОЛ',
    bookingAcceptedTitle: '✅ БРОНЬ ПРИНЯТА',
    bookingDeclinedTitle: '❌ БРОНЬ ОТКЛОНЕНА',
    bookingCancelledTitle: '🚫 БРОНЬ ОТМЕНЕНА',
    phone: 'ТЕЛ',
    time: 'Время',
    by: 'Кем',
    dayPrompt: 'ДНЕВНОЙ ПРОПУСК · отправьте имя клиента.\n\n/cancel — отмена.',
    monthPrompt: 'НОВЫЙ МЕСЯЧНЫЙ АБОНЕМЕНТ · отправьте имя клиента.\n\n/cancel — отмена.',
    customerPrompt: 'КЛИЕНТЫ · отправьте имя, телефон, Telegram или email для поиска.\n\n/cancel — отмена.',
    purchasePrompt: 'ПОКУПКА · отправьте, что нужно купить.\n\n/cancel — отмена.',
    cancelled: 'Отменено.',
    confirm: 'ПОДТВЕРДИТЬ',
    cancel: 'ОТМЕНА',
    confirmQuestion: 'Подтвердить?',
    newMonthPass: 'НОВЫЙ АБОНЕМЕНТ',
    checkInActive: 'ОТМЕТИТЬ АКТИВНОГО',
    noActiveMembers: 'Нет активных абонементов.',
    activeMembers: 'АКТИВНЫЕ АБОНЕМЕНТЫ · нажмите для отметки',
    nameRequired: 'Нужно имя.',
    purchaseRequired: 'Нужно название покупки.',
    actionExpired: 'Действие устарело. Начните заново.',
    dayAdded: 'Дневной пропуск добавлен.',
    monthAdded: 'Месячный абонемент добавлен.',
    purchaseAdded: 'Покупка добавлена.',
    noCustomers: 'Клиенты не найдены.',
    noContact: 'Нет контакта',
    activeUntil: 'АКТИВЕН ДО',
    noActiveMonth: 'НЕТ АКТИВНОГО АБОНЕМЕНТА',
    addPurchase: 'ДОБАВИТЬ ПОКУПКУ',
    toBuy: '🛒 НУЖНО КУПИТЬ\n\nНажмите на товар после покупки.',
    notifications: '⚙️ УВЕДОМЛЕНИЯ',
    purchases: 'Покупки',
    on: 'ВКЛ',
    off: 'ВЫКЛ',
    updated: 'Обновлено.',
    bookingAcceptedCallback: 'Бронь принята.',
    bookingDeclinedCallback: 'Бронь отклонена.',
    bookingCancelledCallback: 'Бронь отменена.',
    checkedIn: 'Клиент отмечен.',
    markedBought: 'Отмечено как купленное.',
    invalidBooking: 'Некорректная бронь.',
    notLinkedAdmin: 'Telegram не подключён к подтверждённому администратору.',
    bookingNotYours: 'Эта бронь не привязана к вашему Telegram.',
    bookingExpired: 'Эта бронь уже истекла.',
    wifiAfterAccept: 'Wi-Fi доступен после подтверждения брони.',
    wifiNotConfigured: 'Wi-Fi пока не настроен.',
    wifiSent: 'Данные Wi-Fi отправлены.',
    network: 'Сеть',
    password: 'Пароль',
    languageTitle: '🌐 <b>ЯЗЫК</b>\n\nВыберите язык бота.',
    languageChanged: 'Язык изменён.',
    bookingAlreadyActive: 'У вас уже есть активный запрос на этот день.',
    purchaseNotification: '🛒 <b>НОВАЯ ПОКУПКА</b>',
    purchaseNotificationCopy: 'Откройте /buy для общего списка покупок.',
    help: 'EVIL SPACE ADMIN\n\n/menu — меню\n/today — сегодня\n/bookings — ожидающие брони\n/day Имя — дневной пропуск\n/month Имя — месячный абонемент\n/customer Alex — поиск клиентов\n/income — доход\n/buy Товар — список покупок\n/settings — уведомления\n/language — язык\n/cancel — отменить текущее действие',
  },
  vi: {
    adminConnected: '✅ <b>ĐÃ KẾT NỐI TELEGRAM QUẢN TRỊ</b>',
    adminConnectedCopy: 'Bạn có thể quản lý Evil Space trực tiếp từ cuộc trò chuyện này.',
    customerConnected: '✅ <b>ĐÃ KẾT NỐI CẬP NHẬT ĐẶT BÀN</b>',
    customerConnectedCopy: 'Chúng tôi sẽ nhắn tại đây khi Evil Space chấp nhận hoặc từ chối yêu cầu của bạn.',
    customerPending: '⏳ <b>ĐÃ GỬI YÊU CẦU ĐẶT BÀN</b>',
    customerPendingCopy: 'Yêu cầu đang chờ quản trị viên Evil Space xác nhận.',
    customerAccepted: '✅ <b>ĐÃ XÁC NHẬN ĐẶT BÀN</b>',
    customerAcceptedCopy: 'Bàn của bạn tại Evil Space đã được xác nhận cho hôm nay.\nMở cửa hằng ngày 11:00–23:00.\n\nBạn có thể hủy tại đây nếu kế hoạch thay đổi.',
    customerDeclined: '❌ <b>YÊU CẦU ĐÃ BỊ TỪ CHỐI</b>',
    customerDeclinedCopy: 'Chúng tôi chưa thể xác nhận yêu cầu này. Bạn có thể gửi yêu cầu mới bất cứ lúc nào tại evils.space.',
    customerCancelled: '🚫 <b>ĐÃ HỦY ĐẶT BÀN</b>',
    customerCancelledCopy: 'Bàn của bạn không còn được tính là đang sử dụng.',
    customerNoBooking: 'Hôm nay bạn không có yêu cầu đặt bàn đang hoạt động.',
    unlinked: 'Tài khoản Telegram này chưa được kết nối.\n\nQuản trị viên: mở evils.space/admin → Telegram.\nKhách: mở evils.space và nhấn TG khi đặt bàn.',
    today: 'HÔM NAY',
    tomorrow: 'NGÀY MAI',
    date: 'Ngày',
    price: 'Giá',
    bookings: 'ĐẶT BÀN',
    dayPass: 'VÉ NGÀY',
    month: 'THÁNG',
    customers: 'KHÁCH HÀNG',
    income: 'DOANH THU',
    buy: 'MUA',
    settings: 'CÀI ĐẶT',
    language: 'NGÔN NGỮ',
    back: 'QUAY LẠI',
    accept: 'CHẤP NHẬN',
    decline: 'TỪ CHỐI',
    openAdmin: 'MỞ ADMIN',
    openSite: 'MỞ EVIL SPACE',
    cancelBooking: 'HỦY ĐẶT BÀN',
    cancelRequest: 'HỦY YÊU CẦU',
    cancelConfirm: 'Hủy yêu cầu đặt bàn này?',
    confirmCancel: 'CÓ, HỦY',
    keepBooking: 'GIỮ ĐẶT BÀN',
    bookingKept: 'Đã giữ đặt bàn.',
    directions: 'CHỈ ĐƯỜNG',
    wifi: 'WI-FI',
    copyNetwork: 'SAO CHÉP MẠNG',
    copyPassword: 'SAO CHÉP MẬT KHẨU',
    occupied: 'Đang dùng',
    pendingBookings: 'Yêu cầu đang chờ',
    nobody: 'Chưa có ai.',
    noPending: '✅ Không có yêu cầu đặt bàn đang chờ.',
    newDeskRequest: '🔔 YÊU CẦU ĐẶT BÀN MỚI',
    bookingAcceptedTitle: '✅ ĐÃ CHẤP NHẬN ĐẶT BÀN',
    bookingDeclinedTitle: '❌ ĐÃ TỪ CHỐI ĐẶT BÀN',
    bookingCancelledTitle: '🚫 ĐÃ HỦY ĐẶT BÀN',
    phone: 'ĐT',
    time: 'Giờ',
    by: 'Bởi',
    dayPrompt: 'VÉ NGÀY · gửi tên khách hàng.\n\n/cancel để hủy.',
    monthPrompt: 'GÓI THÁNG MỚI · gửi tên khách hàng.\n\n/cancel để hủy.',
    customerPrompt: 'KHÁCH HÀNG · gửi tên, điện thoại, Telegram hoặc email để tìm.\n\n/cancel để hủy.',
    purchasePrompt: 'MUA HÀNG · gửi nội dung cần mua.\n\n/cancel để hủy.',
    cancelled: 'Đã hủy.',
    confirm: 'XÁC NHẬN',
    cancel: 'HỦY',
    confirmQuestion: 'Xác nhận?',
    newMonthPass: 'GÓI THÁNG MỚI',
    checkInActive: 'CHECK-IN THÀNH VIÊN',
    noActiveMembers: 'Không có gói tháng đang hoạt động.',
    activeMembers: 'THÀNH VIÊN ĐANG HOẠT ĐỘNG · nhấn để check-in',
    nameRequired: 'Cần tên khách hàng.',
    purchaseRequired: 'Cần nội dung mua hàng.',
    actionExpired: 'Thao tác đã hết hạn. Hãy bắt đầu lại.',
    dayAdded: 'Đã thêm vé ngày.',
    monthAdded: 'Đã thêm gói tháng.',
    purchaseAdded: 'Đã thêm mục cần mua.',
    noCustomers: 'Không tìm thấy khách hàng.',
    noContact: 'Không có liên hệ',
    activeUntil: 'HOẠT ĐỘNG ĐẾN',
    noActiveMonth: 'KHÔNG CÓ GÓI THÁNG',
    addPurchase: 'THÊM MỤC CẦN MUA',
    toBuy: '🛒 CẦN MUA\n\nNhấn vào mục sau khi đã mua.',
    notifications: '⚙️ THÔNG BÁO',
    purchases: 'Mua hàng',
    on: 'BẬT',
    off: 'TẮT',
    updated: 'Đã cập nhật.',
    bookingAcceptedCallback: 'Đã chấp nhận đặt bàn.',
    bookingDeclinedCallback: 'Đã từ chối đặt bàn.',
    bookingCancelledCallback: 'Đã hủy đặt bàn.',
    checkedIn: 'Đã check-in.',
    markedBought: 'Đã đánh dấu đã mua.',
    invalidBooking: 'Đặt bàn không hợp lệ.',
    notLinkedAdmin: 'Telegram chưa được kết nối với quản trị viên đã duyệt.',
    bookingNotYours: 'Đặt bàn này không được liên kết với Telegram của bạn.',
    bookingExpired: 'Đặt bàn này đã hết hạn.',
    wifiAfterAccept: 'Wi-Fi có sau khi đặt bàn được chấp nhận.',
    wifiNotConfigured: 'Wi-Fi chưa được cấu hình.',
    wifiSent: 'Đã gửi thông tin Wi-Fi.',
    network: 'Mạng',
    password: 'Mật khẩu',
    languageTitle: '🌐 <b>NGÔN NGỮ</b>\n\nChọn ngôn ngữ cho bot.',
    languageChanged: 'Đã đổi ngôn ngữ.',
    bookingAlreadyActive: 'Bạn đã có một yêu cầu đặt bàn đang hoạt động hôm nay.',
    purchaseNotification: '🛒 <b>YÊU CẦU MUA HÀNG MỚI</b>',
    purchaseNotificationCopy: 'Mở /buy để quản lý danh sách chung.',
    help: 'EVIL SPACE ADMIN\n\n/menu — menu\n/today — hôm nay\n/bookings — đặt bàn đang chờ\n/day Tên — vé ngày\n/month Tên — gói tháng\n/customer Alex — tìm khách hàng\n/income — doanh thu\n/buy Mục — danh sách mua\n/settings — thông báo\n/language — ngôn ngữ\n/cancel — hủy thao tác hiện tại',
  },
};

function normalizeLanguage(value) {
  const code = typeof value === 'string' ? value.toLowerCase().trim() : '';
  return LANGUAGES.has(code) ? code : 'en';
}

function tr(language, key) {
  const lang = normalizeLanguage(language);
  return TEXT[lang]?.[key] ?? TEXT.en[key] ?? key;
}

export async function handleAdminTelegramStatus(request, env) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);

  const link = await env.evil_space
    .prepare(`
      SELECT telegram_username, notifications_enabled,
             booking_notifications, purchase_notifications, linked_at, language
      FROM admin_telegram_links
      WHERE admin_id = ?
    `)
    .bind(admin.id)
    .first();

  return json({
    ok: true,
    linked: Boolean(link),
    username: link?.telegram_username ?? '',
    notificationsEnabled: Number(link?.notifications_enabled ?? 1) === 1,
    bookingNotifications: Number(link?.booking_notifications ?? 1) === 1,
    purchaseNotifications: Number(link?.purchase_notifications ?? 1) === 1,
    linkedAt: Number(link?.linked_at ?? 0),
    language: normalizeLanguage(link?.language),
    botUsername: BOT_USERNAME,
  });
}

export async function handleAdminTelegramLink(request, env) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const language = normalizeLanguage(body?.language);

  const now = nowSeconds();
  const token = randomToken(24);
  const tokenHash = await hashToken(token);
  await env.evil_space.batch([
    env.evil_space
      .prepare('DELETE FROM admin_telegram_link_tokens WHERE admin_id = ?')
      .bind(admin.id),
    env.evil_space
      .prepare(`
        INSERT INTO admin_telegram_link_tokens
          (token_hash, admin_id, created_at, expires_at, used_at, language)
        VALUES (?, ?, ?, ?, NULL, ?)
      `)
      .bind(tokenHash, admin.id, now, now + ADMIN_LINK_TTL, language),
  ]);

  return json({
    ok: true,
    expiresAt: now + ADMIN_LINK_TTL,
    url: `https://t.me/${BOT_USERNAME}?start=a_${token}`,
  });
}

export async function handleAdminTelegramDisconnect(request, env) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);

  const link = await env.evil_space
    .prepare('SELECT telegram_user_id FROM admin_telegram_links WHERE admin_id = ?')
    .bind(admin.id)
    .first();

  const statements = [
    env.evil_space.prepare('DELETE FROM admin_telegram_links WHERE admin_id = ?').bind(admin.id),
    env.evil_space.prepare('DELETE FROM admin_telegram_link_tokens WHERE admin_id = ?').bind(admin.id),
  ];
  if (link?.telegram_user_id) {
    statements.push(
      env.evil_space
        .prepare('DELETE FROM telegram_admin_sessions WHERE telegram_user_id = ?')
        .bind(link.telegram_user_id),
    );
  }
  await env.evil_space.batch(statements);
  return json({ ok: true });
}

export async function handleAdminTelegramPreferences(request, env) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const bookings = body.bookingNotifications === true ? 1 : 0;
  const purchases = body.purchaseNotifications === true ? 1 : 0;
  const result = await env.evil_space
    .prepare(`
      UPDATE admin_telegram_links
      SET booking_notifications = ?, purchase_notifications = ?, updated_at = ?
      WHERE admin_id = ?
    `)
    .bind(bookings, purchases, nowSeconds(), admin.id)
    .run();
  if (!result.meta?.changes) return jsonError('Connect Telegram first.', 409);
  return handleAdminTelegramStatus(request, env);
}

export async function createCustomerTelegramLink(env, bookingId, rawLanguage = 'en') {
  const id = toPositiveInt(bookingId);
  if (!id) return null;
  const now = nowSeconds();
  const booking = await bookingById(env, id);
  if (!booking) return null;
  const serviceDay = Number(booking.service_day ?? 0);
  const expiresAt = Math.min(serviceDay + 86400, now + CUSTOMER_LINK_TTL);
  if (expiresAt <= now) return null;
  const language = normalizeLanguage(rawLanguage);

  const token = randomToken(24);
  const tokenHash = await hashToken(token);
  await env.evil_space.batch([
    env.evil_space
      .prepare('DELETE FROM customer_telegram_link_tokens WHERE booking_id = ? AND used_at IS NULL')
      .bind(id),
    env.evil_space
      .prepare(`
        INSERT INTO customer_telegram_link_tokens
(token_hash, booking_id, created_at, expires_at, used_at, language)
        VALUES (?, ?, ?, ?, NULL, ?)
      `)
      .bind(tokenHash, id, now, expiresAt, language),
  ]);
  return `https://t.me/${BOT_USERNAME}?start=c_${token}`;
}

export async function handleWebAcceptBooking(request, env, ctx) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const bookingId = toPositiveInt(body?.id);
  if (!bookingId) return jsonError('Booking request is required.', 400);

  try {
    const booking = await acceptBooking(env, bookingId, admin);
    ctx?.waitUntil(notifyBookingOutcome(env, booking.id, 'accepted'));
    return json({ ok: true });
  } catch (error) {
    return operationError(error);
  }
}

export async function handleWebDeclineBooking(request, env, ctx) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const bookingId = toPositiveInt(body?.id);
  if (!bookingId) return jsonError('Booking request is required.', 400);

  try {
    const booking = await declineBooking(env, bookingId, admin);
    ctx?.waitUntil(notifyBookingOutcome(env, booking.id, 'declined'));
    return json({ ok: true });
  } catch (error) {
    return operationError(error);
  }
}

export async function handlePublicBookingCancel(request, env, ctx) {
  const body = await readJson(request);
  const token = typeof body?.token === 'string' ? body.token : '';
  if (!isReasonableToken(token)) return jsonError('Invalid booking.', 400);

  const tokenHash = await hashToken(token);
  const booking = await env.evil_space
    .prepare(`
      SELECT id, status, customer_id, accepted_visit_id, created_at, service_day, amount_vnd
      FROM booking_requests
      WHERE client_token_hash = ?
      LIMIT 1
    `)
    .bind(tokenHash)
    .first();
  if (!booking) return json({ ok: true });

  try {
    const cancelled = await cancelBookingRecord(env, booking, 'website');
    ctx?.waitUntil(notifyBookingOutcome(env, cancelled.id, 'cancelled'));
    return json({ ok: true });
  } catch (error) {
    return operationError(error);
  }
}

export async function notifyAdminsNewBooking(env, bookingId) {
  if (!telegramConfigured(env)) return;
  const booking = await bookingById(env, bookingId);
  if (!booking) return;

  const links = await env.evil_space
    .prepare(`
      SELECT l.telegram_chat_id, l.language
      FROM admin_telegram_links l
      JOIN admins a ON a.id = l.admin_id
      WHERE a.status = 'approved'
        AND l.notifications_enabled = 1
        AND l.booking_notifications = 1
    `)
    .all();

  await Promise.all(
    (links.results ?? []).map(async (link) => {
      try {
        await sendBookingToAdmin(env, link.telegram_chat_id, booking, link.language);
      } catch (error) {
        console.error('Telegram booking notification failed', safeError(error));
      }
    }),
  );
}

export async function notifyAdminsPurchase(env, title) {
  if (!telegramConfigured(env)) return;
  const clean = cleanText(title, MAX_TEXT_LENGTH);
  if (!clean) return;

  const links = await env.evil_space
    .prepare(`
      SELECT l.telegram_chat_id, l.language
      FROM admin_telegram_links l
      JOIN admins a ON a.id = l.admin_id
      WHERE a.status = 'approved'
        AND l.notifications_enabled = 1
        AND l.purchase_notifications = 1
    `)
    .all();

  await Promise.all(
    (links.results ?? []).map((link) => {
      const lang = normalizeLanguage(link.language);
      return telegramApi(env, 'sendMessage', {
        chat_id: link.telegram_chat_id,
        text: `${tr(lang, 'purchaseNotification')}\n\n${escapeHtml(clean)}\n\n${tr(lang, 'purchaseNotificationCopy')}`,
        parse_mode: 'HTML',
        reply_markup: adminMenuKeyboard(lang),
      }).catch((error) =>
        console.error('Telegram purchase notification failed', safeError(error)),
      );
    }),
  );
}

export async function handleTelegramWebhook(request, env) {
  if (!telegramConfigured(env) || !env.TELEGRAM_WEBHOOK_SECRET) {
    return jsonError('Telegram is not configured.', 503);
  }
  const supplied = request.headers.get('X-Telegram-Bot-Api-Secret-Token') ?? '';
  if (!constantTimeEqual(supplied, env.TELEGRAM_WEBHOOK_SECRET)) {
    return jsonError('Invalid webhook.', 403);
  }

  const update = await readJson(request, 1024 * 1024);
  if (!update) return json({ ok: true });

  try {
    if (update.callback_query) {
      await handleCallback(env, update.callback_query);
    } else if (update.message?.text) {
      await handleMessage(env, update.message);
    }
  } catch (error) {
    console.error('Telegram update failed', safeError(error));
  }
  return json({ ok: true });
}

async function handleMessage(env, message) {
  const user = message.from;
  const chatId = message.chat?.id;
  const text = typeof message.text === 'string' ? message.text.trim() : '';
  if (!user?.id || !chatId || !text) return;

  const command = parseCommand(text);
  if (command?.name === 'start') {
    const payload = command.args.trim();
    if (payload.startsWith('a_')) {
      await pairAdmin(env, user, chatId, payload.slice(2));
      return;
    }
    if (payload.startsWith('c_')) {
      await pairCustomer(env, user, chatId, payload.slice(2));
      return;
    }
    if (payload.startsWith('book_')) {
      await bookViaTelegram(env, user, chatId, payload.slice(5));
      return;
    }
  }

  const admin = await linkedAdmin(env, user.id);
  if (admin) {
    if (command) {
      await handleAdminCommand(env, admin, chatId, command);
      return;
    }
    const session = await adminState(env, user.id);
    if (!session) {
      await sendAdminMenu(env, admin, chatId);
      return;
    }
    await handleAdminStateText(env, admin, chatId, session, text);
    return;
  }

  const customer = await linkedCustomer(env, user.id);
  if (customer) {
    if (command?.name === 'language' || command?.name === 'lang') {
      await sendLanguageMenu(env, chatId, customer.language, 'customer');
      return;
    }
    await sendCustomerHome(env, customer, chatId);
    return;
  }

  const lang = normalizeLanguage(user.language_code?.slice(0, 2));
  await sendText(env, chatId, tr(lang, 'unlinked'));
}

async function handleAdminCommand(env, admin, chatId, command) {
  const args = command.args.trim();
  const lang = normalizeLanguage(admin.language);
  switch (command.name) {
    case 'start':
    case 'menu':
      await clearAdminState(env, admin.telegram_user_id);
      return sendAdminMenu(env, admin, chatId);
    case 'today':
      return sendToday(env, admin, chatId);
    case 'bookings':
      return sendPendingBookings(env, admin, chatId);
    case 'income':
      return sendIncome(env, admin, chatId);
    case 'day':
      if (args) return prepareNamedOperation(env, admin, chatId, 'confirm_day', args);
      await setAdminState(env, admin, 'wait_day_name', {});
      return sendText(env, chatId, tr(lang, 'dayPrompt'));
    case 'month':
      if (args) return prepareNamedOperation(env, admin, chatId, 'confirm_month', args);
      return sendMonthMenu(env, admin, chatId);
    case 'customer':
    case 'customers':
      if (args) return sendCustomerSearch(env, admin, chatId, args);
      await setAdminState(env, admin, 'wait_customer_search', {});
      return sendText(env, chatId, tr(lang, 'customerPrompt'));
    case 'buy':
      if (args) return preparePurchase(env, admin, chatId, args);
      return sendBuy(env, admin, chatId);
    case 'settings':
      return sendSettings(env, admin, chatId);
    case 'language':
    case 'lang':
      return sendLanguageMenu(env, chatId, lang, 'admin');
    case 'cancel':
      await clearAdminState(env, admin.telegram_user_id);
      return sendText(env, chatId, tr(lang, 'cancelled'), adminMenuKeyboard(lang));
    case 'help':
      return sendText(env, chatId, tr(lang, 'help'), adminMenuKeyboard(lang));
    default:
      return sendAdminMenu(env, admin, chatId);
  }
}

async function handleAdminStateText(env, admin, chatId, session, text) {
  switch (session.state) {
    case 'wait_day_name':
      return prepareNamedOperation(env, admin, chatId, 'confirm_day', text);
    case 'wait_month_name':
      return prepareNamedOperation(env, admin, chatId, 'confirm_month', text);
    case 'wait_purchase_title':
      return preparePurchase(env, admin, chatId, text);
    case 'wait_customer_search':
      await clearAdminState(env, admin.telegram_user_id);
      return sendCustomerSearch(env, admin, chatId, text);
    default:
      await clearAdminState(env, admin.telegram_user_id);
      return sendAdminMenu(env, admin, chatId);
  }
}

async function handleCallback(env, callback) {
  const userId = callback.from?.id;
  const chatId = callback.message?.chat?.id;
  const data = typeof callback.data === 'string' ? callback.data : '';
  if (!userId || !chatId || !data) return;

  try {
    if (data.startsWith('cl:')) {
      const customer = await linkedCustomer(env, userId);
      if (!customer) return answerCallback(env, callback.id, 'Not linked.', true);
      const language = normalizeLanguage(data.slice(3));
      await setCustomerLanguage(env, userId, language);
      await answerCallback(env, callback.id, tr(language, 'languageChanged'));
      return sendCustomerHome(env, await linkedCustomer(env, userId), chatId);
    }

    if (data.startsWith('al:')) {
      const admin = await linkedAdmin(env, userId);
      if (!admin) return answerCallback(env, callback.id, 'Not linked.', true);
      const language = normalizeLanguage(data.slice(3));
      await setAdminLanguage(env, admin.id, language);
      await answerCallback(env, callback.id, tr(language, 'languageChanged'));
      return sendAdminMenu(env, await linkedAdmin(env, userId), chatId);
    }

    if (data.startsWith('cc:') || data.startsWith('cf:') || data.startsWith('ck:') || data.startsWith('cw:')) {
      await handleCustomerCallback(env, callback, userId, chatId, data);
      return;
    }

    const admin = await linkedAdmin(env, userId);
    if (!admin) {
      await answerCallback(env, callback.id, tr('en', 'notLinkedAdmin'), true);
      return;
    }
    const lang = normalizeLanguage(admin.language);

    if (data.startsWith('ba:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, tr(lang, 'invalidBooking'), true);
      try {
        const booking = await acceptBooking(env, id, admin);
        await answerCallback(env, callback.id, tr(lang, 'bookingAcceptedCallback'));
        await notifyBookingOutcome(env, booking.id, 'accepted');
      } catch (error) {
        await answerCallback(env, callback.id, userMessage(error), true);
      }
      return;
    }

    if (data.startsWith('bd:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, tr(lang, 'invalidBooking'), true);
      try {
        const booking = await declineBooking(env, id, admin);
        await answerCallback(env, callback.id, tr(lang, 'bookingDeclinedCallback'));
        await notifyBookingOutcome(env, booking.id, 'declined');
      } catch (error) {
        await answerCallback(env, callback.id, userMessage(error), true);
      }
      return;
    }

    if (data.startsWith('mi:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, 'Invalid membership.', true);
      try {
        await checkInMembership(env, id, admin);
        await answerCallback(env, callback.id, tr(lang, 'checkedIn'));
        await sendToday(env, admin, chatId);
      } catch (error) {
        await answerCallback(env, callback.id, userMessage(error), true);
      }
      return;
    }

    if (data.startsWith('cust:')) {
      const id = toPositiveInt(data.slice(5));
      await answerCallback(env, callback.id);
      if (id) await sendCustomer(env, admin, chatId, id);
      return;
    }

    if (data.startsWith('cd:') || data.startsWith('cm:')) {
      const id = toPositiveInt(data.slice(3));
      const customer = id ? await customerById(env, id) : null;
      if (!customer) return answerCallback(env, callback.id, tr(lang, 'noCustomers'), true);
      const state = data.startsWith('cd:') ? 'confirm_day' : 'confirm_month';
      await answerCallback(env, callback.id);
      return prepareNamedOperation(env, admin, chatId, state, customer.name);
    }

    if (data.startsWith('pb:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, 'Invalid purchase.', true);
      try {
        await markPurchaseBought(env, id, admin);
        await answerCallback(env, callback.id, tr(lang, 'markedBought'));
        await sendBuy(env, admin, chatId);
      } catch (error) {
        await answerCallback(env, callback.id, userMessage(error), true);
      }
      return;
    }

    switch (data) {
      case 'm:today':
        await answerCallback(env, callback.id);
        return sendToday(env, admin, chatId);
      case 'm:bookings':
        await answerCallback(env, callback.id);
        return sendPendingBookings(env, admin, chatId);
      case 'm:day':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_day_name', {});
        return sendText(env, chatId, tr(lang, 'dayPrompt'));
      case 'm:month':
        await answerCallback(env, callback.id);
        return sendMonthMenu(env, admin, chatId);
      case 'm:customers':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_customer_search', {});
        return sendText(env, chatId, tr(lang, 'customerPrompt'));
      case 'm:income':
        await answerCallback(env, callback.id);
        return sendIncome(env, admin, chatId);
      case 'm:buy':
        await answerCallback(env, callback.id);
        return sendBuy(env, admin, chatId);
      case 'm:settings':
        await answerCallback(env, callback.id);
        return sendSettings(env, admin, chatId);
      case 'm:language':
        await answerCallback(env, callback.id);
        return sendLanguageMenu(env, chatId, lang, 'admin');
      case 'month:new':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_month_name', {});
        return sendText(env, chatId, tr(lang, 'monthPrompt'));
      case 'month:active':
        await answerCallback(env, callback.id);
        return sendActiveMemberships(env, admin, chatId);
      case 'buy:add':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_purchase_title', {});
        return sendText(env, chatId, tr(lang, 'purchasePrompt'));
      case 'op:cancel':
        await answerCallback(env, callback.id, tr(lang, 'cancelled'));
        await clearAdminState(env, admin.telegram_user_id);
        return sendAdminMenu(env, admin, chatId);
      case 'op:day:ok':
        return confirmStateOperation(env, callback, admin, chatId, 'confirm_day');
      case 'op:month:ok':
        return confirmStateOperation(env, callback, admin, chatId, 'confirm_month');
      case 'op:buy:ok':
        return confirmStateOperation(env, callback, admin, chatId, 'confirm_buy');
      case 'set:book':
      case 'set:buy':
        await toggleSetting(env, admin, data);
        await answerCallback(env, callback.id, tr(lang, 'updated'));
        return sendSettings(env, await linkedAdmin(env, userId), chatId);
      default:
        await answerCallback(env, callback.id);
        return sendAdminMenu(env, admin, chatId);
    }
  } catch (error) {
    console.error('Telegram callback failed', safeError(error));
    await answerCallback(env, callback.id, 'Could not complete the action.', true);
  }
}

async function handleCustomerCallback(env, callback, userId, chatId, data) {
  const customer = await linkedCustomer(env, userId);
  const lang = normalizeLanguage(customer?.language);
  const bookingId = toPositiveInt(data.slice(3));
  if (!bookingId) return answerCallback(env, callback.id, tr(lang, 'invalidBooking'), true);
  const booking = await env.evil_space
    .prepare(`
      SELECT b.id, b.status, b.customer_id, b.accepted_visit_id, b.created_at, b.service_day, b.amount_vnd
      FROM booking_requests b
      JOIN customer_telegram_links l ON l.customer_id = b.customer_id
      WHERE b.id = ? AND l.telegram_user_id = ?
    `)
    .bind(bookingId, userId)
    .first();
  if (!booking) return answerCallback(env, callback.id, tr(lang, 'bookingNotYours'), true);

  if (!isBookableServiceDay(Number(booking.service_day ?? 0), nowSeconds())) {
    return answerCallback(env, callback.id, tr(lang, 'bookingExpired'), true);
  }

  if (data.startsWith('cc:')) {
    if (!['new', 'accepted'].includes(booking.status)) {
      return answerCallback(env, callback.id, 'This booking can no longer be cancelled.', true);
    }
    await answerCallback(env, callback.id);
    await sendCustomerCancelConfirmation(env, chatId, booking.id, lang);
    return;
  }

  if (data.startsWith('ck:')) {
    await answerCallback(env, callback.id, tr(lang, 'bookingKept'));
    await sendCustomerHome(env, customer, chatId);
    return;
  }

  if (data.startsWith('cf:')) {
    try {
      const cancelled = await cancelBookingRecord(env, booking, 'telegram');
      await answerCallback(env, callback.id, tr(lang, 'bookingCancelledCallback'));
      await notifyBookingOutcome(env, cancelled.id, 'cancelled');
    } catch (error) {
      await answerCallback(env, callback.id, userMessage(error), true);
    }
    return;
  }

  if (booking.status !== 'accepted') {
    return answerCallback(env, callback.id, tr(lang, 'wifiAfterAccept'), true);
  }
  if (typeof env.WIFI_PASSWORD !== 'string' || !env.WIFI_PASSWORD) {
    return answerCallback(env, callback.id, tr(lang, 'wifiNotConfigured'), true);
  }

  await answerCallback(env, callback.id, tr(lang, 'wifiSent'));
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `📶 <b>EVIL SPACE WI-FI</b>\n\n${tr(lang, 'network')}: <code>${escapeHtml(WIFI_SSID)}</code>\n${tr(lang, 'password')}: <code>${escapeHtml(env.WIFI_PASSWORD)}</code>`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: tr(lang, 'copyNetwork'), copy_text: { text: WIFI_SSID } },
          { text: tr(lang, 'copyPassword'), copy_text: { text: env.WIFI_PASSWORD } },
        ],
        [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: `cl:${lang}` }],
      ],
    },
  });
}

async function pairAdmin(env, user, chatId, token) {
  if (!isReasonableToken(token)) return sendText(env, chatId, 'This admin link is invalid.');
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const pending = await env.evil_space
    .prepare(`
      SELECT t.admin_id, t.expires_at, t.language, a.email
      FROM admin_telegram_link_tokens t
      JOIN admins a ON a.id = t.admin_id
      WHERE t.token_hash = ? AND t.used_at IS NULL AND a.status = 'approved'
    `)
    .bind(tokenHash)
    .first();
  if (!pending || Number(pending.expires_at) <= now) {
    return sendText(env, chatId, 'This admin link expired. Open the Evil Space admin panel and generate a new one.');
  }

  const language = normalizeLanguage(pending.language);
  const username = user.username ? `@${user.username}` : '';
  await env.evil_space.batch([
    env.evil_space.prepare('DELETE FROM admin_telegram_links WHERE admin_id = ? OR telegram_user_id = ?').bind(pending.admin_id, user.id),
    env.evil_space
      .prepare(`
        INSERT INTO admin_telegram_links
          (admin_id, telegram_user_id, telegram_chat_id, telegram_username,
           notifications_enabled, booking_notifications, purchase_notifications,
           linked_at, updated_at, language)
        VALUES (?, ?, ?, ?, 1, 1, 1, ?, ?, ?)
      `)
      .bind(pending.admin_id, user.id, chatId, username, now, now, language),
    env.evil_space.prepare('UPDATE admin_telegram_link_tokens SET used_at = ? WHERE token_hash = ?').bind(now, tokenHash),
  ]);

  const admin = await linkedAdmin(env, user.id);
  await audit(env, admin, 'telegram.link', 'admin', admin.id, username);
  await sendText(
    env,
    chatId,
    `${tr(language, 'adminConnected')}\n\n${escapeHtml(pending.email)}\n\n${tr(language, 'adminConnectedCopy')}`,
    adminMenuKeyboard(language),
    true,
  );
  await sendAdminMenu(env, admin, chatId);
}

async function pairCustomer(env, user, chatId, token) {
  if (!isReasonableToken(token)) return sendText(env, chatId, 'This booking link is invalid.');
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const pending = await env.evil_space
    .prepare(`
      SELECT t.booking_id, t.expires_at, t.language,
   b.id, b.name, b.contact_type, b.contact_value, b.status, b.customer_id,
   b.created_at, b.service_day, b.amount_vnd
      FROM customer_telegram_link_tokens t
      JOIN booking_requests b ON b.id = t.booking_id
      WHERE t.token_hash = ? AND t.used_at IS NULL
    `)
    .bind(tokenHash)
    .first();
  if (!pending || Number(pending.expires_at) <= now) {
    return sendText(env, chatId, 'This booking link expired. Return to evils.space and create a new desk request if needed.');
  }
  if (!isBookableServiceDay(Number(pending.service_day ?? 0), now) || !['new', 'accepted'].includes(pending.status)) {
    return sendText(env, chatId, 'This booking is no longer active.');
  }

  const language = normalizeLanguage(pending.language);
  const identity = telegramBookingIdentity(user);
  const customer = await ensureTelegramCustomer(env, user, identity);
  await upsertCustomerTelegramLink(env, customer.id, user, chatId, language);
  await env.evil_space.batch([
    env.evil_space.prepare('UPDATE booking_requests SET customer_id = ? WHERE id = ?').bind(customer.id, pending.id),
    env.evil_space.prepare('UPDATE customer_telegram_link_tokens SET used_at = ? WHERE token_hash = ?').bind(now, tokenHash),
  ]);

  if (pending.status === 'accepted') {
    await sendCustomerAccepted(env, chatId, pending.id, language);
  } else {
    await sendCustomerPending(env, chatId, pending.id, language, true);
  }
}

async function bookViaTelegram(env, user, chatId, rawPayload) {
  const now = nowSeconds();
  let language = 'en';
  let serviceDay = null;
  const match = /^(\d{8})_(en|ru|vi)$/.exec(String(rawPayload ?? ''));
  if (match) {
    serviceDay = serviceDayFromCompactDate(match[1]);
    language = normalizeLanguage(match[2]);
  } else {
    language = normalizeLanguage(rawPayload);
    serviceDay = serviceDayForOffset(0, now);
  }
  if (serviceDay == null || !isBookableServiceDay(serviceDay, now)) {
    return sendText(env, chatId, 'This booking date is no longer available. Return to evils.space and choose today or tomorrow.');
  }

  const identity = telegramBookingIdentity(user);
  const customer = await ensureTelegramCustomer(env, user, identity);
  await upsertCustomerTelegramLink(env, customer.id, user, chatId, language);

  const existing = await env.evil_space
    .prepare(`
      SELECT id, status
      FROM booking_requests
      WHERE customer_id = ?
        AND service_day = ?
        AND status IN ('new', 'processing', 'accepted')
      ORDER BY id DESC
      LIMIT 1
    `)
    .bind(customer.id, serviceDay)
    .first();

  if (existing?.id) {
    if (existing.status === 'accepted') {
      await sendCustomerAccepted(env, chatId, existing.id, language);
    } else {
      await sendCustomerPending(env, chatId, existing.id, language);
    }
    return;
  }

  const capacity = await serviceDayCapacity(env, serviceDay);
  if (capacity.occupied >= capacity.total) {
    return sendText(env, chatId, 'No desks are left for this day.');
  }

  const amountVnd = (await resolvePricing(env, serviceDay, now)).dayPassVnd;
  const created = await env.evil_space
    .prepare(`
      INSERT INTO booking_requests
        (name, contact_type, contact_value, status, created_at, customer_id,
         service_day, amount_vnd)
      VALUES (?, 'telegram', ?, 'new', ?, ?, ?, ?)
      RETURNING id
    `)
    .bind(identity.name, identity.contact, now, customer.id, serviceDay, amountVnd)
    .first();
  if (!created?.id) throw new Error('Could not create Telegram booking.');

  await Promise.all([
    notifyAdminsNewBooking(env, created.id),
    sendCustomerPending(env, chatId, created.id, language),
  ]);
}

function telegramBookingIdentity(user) {
  const username = cleanOptionalText(user?.username, MAX_NAME_LENGTH);
  if (username) {
    const value = `@${username}`;
    return { name: value, contact: value };
  }
  const first = cleanOptionalText(user?.first_name, MAX_NAME_LENGTH);
  const last = cleanOptionalText(user?.last_name, MAX_NAME_LENGTH);
  const display = cleanText([first, last].filter(Boolean).join(' '), MAX_NAME_LENGTH) || 'Telegram';
  return { name: display, contact: display };
}

async function ensureTelegramCustomer(env, user, identity) {
  const linked = await linkedCustomer(env, user.id);
  if (linked?.customer_id) {
    await env.evil_space
      .prepare(`
        UPDATE customers
        SET name = ?, telegram = CASE WHEN ? LIKE '@%' THEN ? ELSE telegram END, updated_at = ?
        WHERE id = ?
      `)
      .bind(identity.name, identity.contact, identity.contact, nowSeconds(), linked.customer_id)
      .run();
    return { id: Number(linked.customer_id), name: identity.name };
  }

  if (identity.contact.startsWith('@')) {
    const existing = await env.evil_space
      .prepare('SELECT id FROM customers WHERE lower(telegram) = lower(?) LIMIT 1')
      .bind(identity.contact)
      .first();
    if (existing?.id) {
      await env.evil_space
        .prepare('UPDATE customers SET name = ?, telegram = ?, updated_at = ? WHERE id = ?')
        .bind(identity.name, identity.contact, nowSeconds(), existing.id)
        .run();
      return { id: Number(existing.id), name: identity.name };
    }
  }

  const now = nowSeconds();
  const created = await env.evil_space
    .prepare(`
      INSERT INTO customers
        (name, phone, email, telegram, contact_other, notes, created_at, updated_at)
      VALUES (?, '', '', ?, '', '', ?, ?)
      RETURNING id
    `)
    .bind(identity.name, identity.contact.startsWith('@') ? identity.contact : '', now, now)
    .first();
  return { id: Number(created.id), name: identity.name };
}

async function upsertCustomerTelegramLink(env, customerId, user, chatId, language) {
  const username = user.username ? `@${user.username}` : '';
  const now = nowSeconds();
  await env.evil_space.batch([
    env.evil_space.prepare('DELETE FROM customer_telegram_links WHERE customer_id = ? OR telegram_user_id = ?').bind(customerId, user.id),
    env.evil_space
      .prepare(`
        INSERT INTO customer_telegram_links
          (customer_id, telegram_user_id, telegram_chat_id, telegram_username, linked_at, updated_at, language)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `)
      .bind(customerId, user.id, chatId, username, now, now, normalizeLanguage(language)),
  ]);
}

async function sendAdminMenu(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const summary = await todaySummary(env);
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `🗞 <b>EVIL SPACE ADMIN</b>\n\n${tr(lang, 'today')}: <b>${summary.occupied}/${summary.total}</b>\n${tr(lang, 'pendingBookings')}: <b>${summary.pending}</b>\n${tr(lang, 'income')}: <b>${formatMoney(summary.income)}</b>`,
    parse_mode: 'HTML',
    reply_markup: adminMenuKeyboard(lang),
  });
}

function adminMenuKeyboard(language) {
  const lang = normalizeLanguage(language);
  return {
    inline_keyboard: [
      [
        { text: tr(lang, 'today'), callback_data: 'm:today' },
        { text: tr(lang, 'bookings'), callback_data: 'm:bookings' },
      ],
      [
        { text: tr(lang, 'dayPass'), callback_data: 'm:day' },
        { text: tr(lang, 'month'), callback_data: 'm:month' },
      ],
      [
        { text: tr(lang, 'customers'), callback_data: 'm:customers' },
        { text: tr(lang, 'income'), callback_data: 'm:income' },
      ],
      [
        { text: tr(lang, 'buy'), callback_data: 'm:buy' },
        { text: tr(lang, 'settings'), callback_data: 'm:settings' },
      ],
      [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: 'm:language' }],
    ],
  };
}

async function sendToday(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const [summary, visits] = await Promise.all([
    todaySummary(env),
    env.evil_space
      .prepare(`
        SELECT name, kind, amount, created_at
        FROM visits
        WHERE created_at >= ? AND created_at < ?
        ORDER BY created_at DESC, id DESC
        LIMIT 25
      `)
      .bind(start, end)
      .all(),
  ]);
  const lines = (visits.results ?? []).map(
    (visit) => `• ${escapeHtml(visit.name)} · ${visit.kind === 'month' ? tr(lang, 'month') : tr(lang, 'dayPass')} · ${formatLocalTime(visit.created_at)}`,
  );
  const text = [
    `📋 <b>${tr(lang, 'today')}</b>`,
    '',
    `${tr(lang, 'occupied')}: <b>${summary.occupied}/${summary.total}</b>`,
    `${tr(lang, 'income')}: <b>${formatMoney(summary.income)}</b>`,
    `${tr(lang, 'pendingBookings')}: <b>${summary.pending}</b>`,
    '',
    ...(lines.length ? lines : [tr(lang, 'nobody')]),
  ].join('\n');
  await sendText(env, chatId, text, adminMenuKeyboard(lang), true);
}

async function sendPendingBookings(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const { today, end } = bookingWindow(nowSeconds());
  const result = await env.evil_space
    .prepare(`
      SELECT id, name, contact_type, contact_value, status, created_at,
   service_day, amount_vnd, handled_at, handled_by_email
      FROM booking_requests
      WHERE status = 'new' AND service_day >= ? AND service_day < ?
      ORDER BY service_day ASC, created_at ASC, id ASC
      LIMIT 50
    `)
    .bind(today, end)
    .all();
  const bookings = result.results ?? [];
  if (!bookings.length) {
    await sendText(env, chatId, tr(lang, 'noPending'), adminMenuKeyboard(lang));
    return;
  }
  for (const booking of bookings) {
    await sendBookingToAdmin(env, chatId, booking, lang);
  }
}

async function sendBookingToAdmin(env, chatId, booking, language) {
  const lang = normalizeLanguage(language);
  const response = await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: bookingAdminText(booking, 'new', '', lang),
    parse_mode: 'HTML',
    reply_markup: bookingAdminKeyboard(booking.id, lang),
  });
  const messageId = toPositiveInt(response?.result?.message_id);
  if (messageId) {
    await env.evil_space
      .prepare(`
        INSERT INTO telegram_booking_messages
          (booking_id, telegram_chat_id, telegram_message_id, created_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(booking_id, telegram_chat_id)
        DO UPDATE SET telegram_message_id = excluded.telegram_message_id,
                      created_at = excluded.created_at
      `)
      .bind(booking.id, chatId, messageId, nowSeconds())
      .run();
  }
}

function bookingAdminText(booking, status, actor = '', language = 'en') {
  const lang = normalizeLanguage(language);
  const contact = booking.contact_type === 'telegram' ? 'TG' : tr(lang, 'phone');
  const heading = status === 'accepted'
    ? tr(lang, 'bookingAcceptedTitle')
    : status === 'declined'
      ? tr(lang, 'bookingDeclinedTitle')
      : status === 'cancelled'
        ? tr(lang, 'bookingCancelledTitle')
        : tr(lang, 'newDeskRequest');
  const serviceDay = Number(booking.service_day ?? 0);
  const kind = bookingDayKind(serviceDay, nowSeconds());
  const dayLabel = kind === 'tomorrow' ? tr(lang, 'tomorrow') : tr(lang, 'today');
  return [
    `<b>${heading}</b>`,
    '',
    `<b>${escapeHtml(booking.name ?? '')}</b>`,
    `${contact}: ${escapeHtml(booking.contact_value ?? '')}`,
    `${dayLabel} · ${formatLocalDate(serviceDay)} · <b>${formatMoney(booking.amount_vnd)}</b>`,
    `${tr(lang, 'time')}: ${formatLocalTime(booking.created_at)}`,
    actor ? `${tr(lang, 'by')}: ${escapeHtml(actor)}` : '',
  ].filter(Boolean).join('\n');
}

function bookingAdminKeyboard(id, language) {
  const lang = normalizeLanguage(language);
  return {
    inline_keyboard: [
      [
        { text: `✅ ${tr(lang, 'accept')}`, callback_data: `ba:${id}` },
        { text: `❌ ${tr(lang, 'decline')}`, callback_data: `bd:${id}` },
      ],
      [{ text: tr(lang, 'openAdmin'), url: 'https://evils.space/admin' }],
    ],
  };
}

async function sendMonthMenu(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  return sendText(env, chatId, tr(lang, 'month'), {
    inline_keyboard: [
      [{ text: tr(lang, 'newMonthPass'), callback_data: 'month:new' }],
      [{ text: tr(lang, 'checkInActive'), callback_data: 'month:active' }],
      [{ text: tr(lang, 'back'), callback_data: 'm:today' }],
    ],
  });
}

async function sendActiveMemberships(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const result = await env.evil_space
    .prepare(`
      SELECT id, name, expires_at
      FROM memberships
      WHERE expires_at > ?
      ORDER BY name COLLATE NOCASE ASC
      LIMIT 30
    `)
    .bind(nowSeconds())
    .all();
  const rows = (result.results ?? []).map((membership) => [
    { text: `${membership.name} · ${formatLocalDate(membership.expires_at)}`, callback_data: `mi:${membership.id}` },
  ]);
  if (!rows.length) return sendText(env, chatId, tr(lang, 'noActiveMembers'), adminMenuKeyboard(lang));
  rows.push([{ text: tr(lang, 'back'), callback_data: 'm:month' }]);
  return sendText(env, chatId, tr(lang, 'activeMembers'), { inline_keyboard: rows });
}

async function prepareNamedOperation(env, admin, chatId, state, value) {
  const lang = normalizeLanguage(admin.language);
  const name = cleanText(value, MAX_NAME_LENGTH);
  if (!name) return sendText(env, chatId, tr(lang, 'nameRequired'));
  await setAdminState(env, admin, state, { name });
  const isMonth = state === 'confirm_month';
  const now = nowSeconds();
  const pricing = await resolvePricing(env, serviceDayForOffset(0, now), now);
  return sendText(
    env,
    chatId,
    `${isMonth ? tr(lang, 'month') : tr(lang, 'dayPass')}\n\n<b>${escapeHtml(name)}</b>\n${formatMoney(isMonth ? pricing.monthPassVnd : pricing.dayPassVnd)}\n\n${tr(lang, 'confirmQuestion')}`,
    {
      inline_keyboard: [[
        { text: tr(lang, 'confirm'), callback_data: isMonth ? 'op:month:ok' : 'op:day:ok' },
        { text: tr(lang, 'cancel'), callback_data: 'op:cancel' },
      ]],
    },
    true,
  );
}

async function preparePurchase(env, admin, chatId, value) {
  const lang = normalizeLanguage(admin.language);
  const title = cleanText(value, MAX_TEXT_LENGTH);
  if (!title) return sendText(env, chatId, tr(lang, 'purchaseRequired'));
  await setAdminState(env, admin, 'confirm_buy', { title });
  return sendText(env, chatId, `${tr(lang, 'addPurchase')}\n\n<b>${escapeHtml(title)}</b>\n\n${tr(lang, 'confirmQuestion')}`, {
    inline_keyboard: [[
      { text: tr(lang, 'confirm'), callback_data: 'op:buy:ok' },
      { text: tr(lang, 'cancel'), callback_data: 'op:cancel' },
    ]],
  }, true);
}

async function confirmStateOperation(env, callback, admin, chatId, expectedState) {
  const lang = normalizeLanguage(admin.language);
  const session = await adminState(env, admin.telegram_user_id);
  if (!session || session.state !== expectedState) {
    return answerCallback(env, callback.id, tr(lang, 'actionExpired'), true);
  }
  const payload = safeJson(session.payload_json);
  try {
    if (expectedState === 'confirm_day') {
      await addDayPass(env, payload.name, admin);
      await answerCallback(env, callback.id, tr(lang, 'dayAdded'));
    } else if (expectedState === 'confirm_month') {
      await addMonthPass(env, payload.name, admin);
      await answerCallback(env, callback.id, tr(lang, 'monthAdded'));
    } else if (expectedState === 'confirm_buy') {
      await addPurchase(env, payload.title, admin);
      await answerCallback(env, callback.id, tr(lang, 'purchaseAdded'));
      await notifyAdminsPurchase(env, payload.title);
    }
    await clearAdminState(env, admin.telegram_user_id);
    return sendAdminMenu(env, admin, chatId);
  } catch (error) {
    return answerCallback(env, callback.id, userMessage(error), true);
  }
}

async function sendCustomerSearch(env, admin, chatId, raw) {
  const lang = normalizeLanguage(admin.language);
  const query = cleanText(raw, MAX_TEXT_LENGTH);
  if (!query) return sendText(env, chatId, 'Search value is required.');
  const like = `%${query.toLowerCase()}%`;
  const result = await env.evil_space
    .prepare(`
      SELECT c.id, c.name, c.phone, c.email, c.telegram,
             MAX(CASE WHEN m.expires_at > ? THEN m.expires_at ELSE NULL END) AS active_until
      FROM customers c
      LEFT JOIN memberships m ON m.customer_id = c.id
      WHERE lower(c.name) LIKE ?
         OR lower(COALESCE(c.phone, '')) LIKE ?
         OR lower(COALESCE(c.email, '')) LIKE ?
         OR lower(COALESCE(c.telegram, '')) LIKE ?
      GROUP BY c.id
      ORDER BY c.name COLLATE NOCASE ASC
      LIMIT 10
    `)
    .bind(nowSeconds(), like, like, like, like)
    .all();
  const customers = result.results ?? [];
  if (!customers.length) return sendText(env, chatId, tr(lang, 'noCustomers'), adminMenuKeyboard(lang));
  return sendText(env, chatId, `${tr(lang, 'customers')} · ${customers.length}`, {
    inline_keyboard: [
      ...customers.map((customer) => [
        { text: customer.name, callback_data: `cust:${customer.id}` },
      ]),
      [{ text: tr(lang, 'back'), callback_data: 'm:customers' }],
    ],
  });
}

async function sendCustomer(env, admin, chatId, customerId) {
  const lang = normalizeLanguage(admin.language);
  const customer = await customerById(env, customerId);
  if (!customer) return sendText(env, chatId, tr(lang, 'noCustomers'), adminMenuKeyboard(lang));
  const contact = [customer.phone, customer.telegram, customer.email].filter(Boolean).join(' · ') || tr(lang, 'noContact');
  const membership = customer.active_until
    ? `${tr(lang, 'activeUntil')} ${formatLocalDate(customer.active_until)}`
    : tr(lang, 'noActiveMonth');
  return sendText(env, chatId, `<b>${escapeHtml(customer.name)}</b>\n${escapeHtml(contact)}\n${membership}`, {
    inline_keyboard: [
      [
        { text: tr(lang, 'dayPass'), callback_data: `cd:${customer.id}` },
        { text: tr(lang, 'month'), callback_data: `cm:${customer.id}` },
      ],
      [{ text: tr(lang, 'back'), callback_data: 'm:customers' }],
    ],
  }, true);
}

async function sendIncome(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const seven = start - 6 * 86400;
  const thirty = start - 29 * 86400;
  const row = await env.evil_space
    .prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN created_at >= ? AND created_at < ? THEN amount ELSE 0 END), 0) AS today,
        COALESCE(SUM(CASE WHEN created_at >= ? THEN amount ELSE 0 END), 0) AS seven,
        COALESCE(SUM(CASE WHEN created_at >= ? THEN amount ELSE 0 END), 0) AS thirty,
        COALESCE(SUM(amount), 0) AS total
      FROM visits
    `)
    .bind(start, end, seven, thirty)
    .first();
  return sendText(
    env,
    chatId,
    `💰 <b>${tr(lang, 'income')}</b>\n\n${tr(lang, 'today')}: <b>${formatMoney(row?.today)}</b>\n7: <b>${formatMoney(row?.seven)}</b>\n30: <b>${formatMoney(row?.thirty)}</b>\nALL: <b>${formatMoney(row?.total)}</b>`,
    adminMenuKeyboard(lang),
    true,
  );
}

async function sendBuy(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const result = await env.evil_space
    .prepare(`
      SELECT id, title, created_at
      FROM purchase_requests
      WHERE status = 'needed'
      ORDER BY created_at DESC, id DESC
      LIMIT 30
    `)
    .all();
  const rows = (result.results ?? []).map((item) => [
    { text: `✓ ${item.title}`, callback_data: `pb:${item.id}` },
  ]);
  rows.unshift([{ text: tr(lang, 'addPurchase'), callback_data: 'buy:add' }]);
  rows.push([{ text: tr(lang, 'back'), callback_data: 'm:today' }]);
  return sendText(env, chatId, tr(lang, 'toBuy'), { inline_keyboard: rows });
}

async function sendSettings(env, admin, chatId) {
  const lang = normalizeLanguage(admin.language);
  const book = Number(admin.booking_notifications) === 1;
  const buy = Number(admin.purchase_notifications) === 1;
  return sendText(env, chatId, tr(lang, 'notifications'), {
    inline_keyboard: [
      [{ text: `${tr(lang, 'bookings')} ${book ? tr(lang, 'on') : tr(lang, 'off')}`, callback_data: 'set:book' }],
      [{ text: `${tr(lang, 'purchases')} ${buy ? tr(lang, 'on') : tr(lang, 'off')}`, callback_data: 'set:buy' }],
      [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: 'm:language' }],
      [{ text: tr(lang, 'back'), callback_data: 'm:today' }],
    ],
  });
}

async function sendLanguageMenu(env, chatId, language, role) {
  const lang = normalizeLanguage(language);
  const prefix = role === 'admin' ? 'al' : 'cl';
  return sendText(env, chatId, tr(lang, 'languageTitle'), {
    inline_keyboard: [
      [
        { text: 'ENGLISH', callback_data: `${prefix}:en` },
        { text: 'РУССКИЙ', callback_data: `${prefix}:ru` },
      ],
      [{ text: 'TIẾNG VIỆT', callback_data: `${prefix}:vi` }],
    ],
  }, true);
}

async function toggleSetting(env, admin, data) {
  if (data === 'set:book') {
    await env.evil_space
      .prepare('UPDATE admin_telegram_links SET booking_notifications = CASE booking_notifications WHEN 1 THEN 0 ELSE 1 END, updated_at = ? WHERE admin_id = ?')
      .bind(nowSeconds(), admin.id)
      .run();
  } else if (data === 'set:buy') {
    await env.evil_space
      .prepare('UPDATE admin_telegram_links SET purchase_notifications = CASE purchase_notifications WHEN 1 THEN 0 ELSE 1 END, updated_at = ? WHERE admin_id = ?')
      .bind(nowSeconds(), admin.id)
      .run();
  }
}

async function setAdminLanguage(env, adminId, language) {
  await env.evil_space
    .prepare('UPDATE admin_telegram_links SET language = ?, updated_at = ? WHERE admin_id = ?')
    .bind(normalizeLanguage(language), nowSeconds(), adminId)
    .run();
}

async function setCustomerLanguage(env, telegramUserId, language) {
  await env.evil_space
    .prepare('UPDATE customer_telegram_links SET language = ?, updated_at = ? WHERE telegram_user_id = ?')
    .bind(normalizeLanguage(language), nowSeconds(), telegramUserId)
    .run();
}

async function acceptBooking(env, bookingId, admin) {
  const now = nowSeconds();
  const existing = await bookingById(env, bookingId);
  if (!existing) throw new OperationError('Booking not found.', 404);
  const serviceDay = Number(existing.service_day ?? 0);
  if (!isBookableServiceDay(serviceDay, now)) {
    throw new OperationError('This desk request is no longer for today or tomorrow.', 410);
  }

  const claimed = await env.evil_space
    .prepare(`
      UPDATE booking_requests
      SET status = 'processing', handled_at = ?, handled_by_email = ?
      WHERE id = ? AND status = 'new'
      RETURNING id, name, contact_type, contact_value, created_at, service_day, amount_vnd
    `)
    .bind(now, admin.email, bookingId)
    .first();
  if (!claimed) throw new OperationError('Booking request was already handled.', 409);

  try {
    const customer = await ensureCustomer(env, {
      name: claimed.name,
      phone: claimed.contact_type === 'phone' ? claimed.contact_value : '',
      telegram: claimed.contact_type === 'telegram' ? claimed.contact_value : '',
    });
    const current = await bookingById(env, bookingId);
    const customerId = toPositiveInt(current?.customer_id) ?? customer.id;
    const serviceStart = Number(claimed.service_day);
    const serviceEnd = serviceStart + 86400;
    const already = await env.evil_space
      .prepare(`
        SELECT id FROM visits
        WHERE customer_id = ? AND created_at >= ? AND created_at < ?
        LIMIT 1
      `)
      .bind(customerId, serviceStart, serviceEnd)
      .first();

    let acceptedVisitId = null;
    if (!already) {
      const visitTime = visitTimestampForServiceDay(serviceStart, now);
      const fallbackPricing = await resolvePricing(env, serviceStart, now);
      const amountVnd = Number(claimed.amount_vnd ?? fallbackPricing.dayPassVnd);
      const visit = await env.evil_space
        .prepare(`
INSERT INTO visits
  (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
SELECT ?, 'day', NULL, ?, ?, ?, ?
WHERE (
  SELECT COUNT(*) FROM visits
  WHERE created_at >= ? AND created_at < ?
) < COALESCE((SELECT total_desks FROM site_state WHERE id = 1), 10)
RETURNING id
        `)
        .bind(claimed.name, amountVnd, visitTime, admin.email, customerId, serviceStart, serviceEnd)
        .first();
      acceptedVisitId = toPositiveInt(visit?.id);
      if (!acceptedVisitId) throw new OperationError('No desks are left for this day.', 409);
    }

    await env.evil_space
      .prepare(`
        UPDATE booking_requests
        SET status = 'accepted', customer_id = ?, accepted_visit_id = ?
        WHERE id = ? AND status = 'processing'
      `)
      .bind(customerId, acceptedVisitId, bookingId)
      .run();
    await audit(env, admin, 'booking.accept', 'booking', bookingId, `${claimed.name} · ${serviceDateKey(serviceStart)} · ${formatMoney(claimed.amount_vnd)}`);
    return { ...claimed, id: bookingId, customer_id: customerId, accepted_visit_id: acceptedVisitId };
  } catch (error) {
    await env.evil_space
      .prepare("UPDATE booking_requests SET status = 'new', handled_at = NULL, handled_by_email = NULL WHERE id = ? AND status = 'processing'")
      .bind(bookingId)
      .run();
    throw error;
  }
}

async function declineBooking(env, bookingId, admin) {
  const now = nowSeconds();
  const existing = await bookingById(env, bookingId);
  if (!existing) throw new OperationError('Booking not found.', 404);
  const serviceDay = Number(existing.service_day ?? 0);
  if (!isBookableServiceDay(serviceDay, now)) {
    throw new OperationError('This desk request is no longer for today or tomorrow.', 410);
  }

  const declined = await env.evil_space
    .prepare(`
      UPDATE booking_requests
      SET status = 'declined', handled_at = ?, handled_by_email = ?
      WHERE id = ? AND status = 'new'
      RETURNING id, name, contact_type, contact_value, created_at, service_day, amount_vnd
    `)
    .bind(now, admin.email, bookingId)
    .first();
  if (!declined) throw new OperationError('Booking request was already handled.', 409);
  await audit(env, admin, 'booking.decline', 'booking', bookingId, `${declined.name} · ${serviceDateKey(serviceDay)} · ${formatMoney(declined.amount_vnd)}`);
  return declined;
}

async function cancelBookingRecord(env, booking, source) {
  if (!['new', 'accepted'].includes(booking.status)) {
    if (booking.status === 'cancelled') return booking;
    throw new OperationError('This booking can no longer be cancelled.', 409);
  }
  const visitId = toPositiveInt(booking.accepted_visit_id);
  const statements = [];
  if (visitId) statements.push(env.evil_space.prepare('DELETE FROM visits WHERE id = ?').bind(visitId));
  statements.push(
    env.evil_space
      .prepare(`
        UPDATE booking_requests
        SET status = 'cancelled', handled_at = ?, handled_by_email = ?
        WHERE id = ? AND status IN ('new', 'accepted')
      `)
      .bind(nowSeconds(), source === 'telegram' ? 'customer:telegram' : 'customer:web', booking.id),
  );
  await env.evil_space.batch(statements);
  return { ...booking, status: 'cancelled' };
}

async function addDayPass(env, rawName, admin) {
  const name = cleanText(rawName, MAX_NAME_LENGTH);
  if (!name) throw new OperationError('Name is required.', 400);
  const now = nowSeconds();
  const customer = await ensureCustomer(env, { name });
  const visit = await env.evil_space
    .prepare(`
      INSERT INTO visits
        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
      VALUES (?, 'day', NULL, ?, ?, ?, ?)
      RETURNING id
    `)
    .bind(name, (await resolvePricing(env, serviceDayForOffset(0, now), now)).dayPassVnd, now, admin.email, customer.id)
    .first();
  await audit(env, admin, 'day_pass.create', 'visit', visit?.id, name);
  return visit;
}

async function addMonthPass(env, rawName, admin) {
  const name = cleanText(rawName, MAX_NAME_LENGTH);
  if (!name) throw new OperationError('Name is required.', 400);
  const now = nowSeconds();
  const customer = await ensureCustomer(env, { name });
  const existing = await env.evil_space
    .prepare('SELECT id FROM memberships WHERE customer_id = ? AND expires_at > ? LIMIT 1')
    .bind(customer.id, now)
    .first();
  if (existing) throw new OperationError('This customer already has an active month pass.', 409);

  const expiresAt = addCalendarMonth(now);
  const membership = await env.evil_space
    .prepare(`
      INSERT INTO memberships (name, starts_at, expires_at, created_at, customer_id)
      VALUES (?, ?, ?, ?, ?)
      RETURNING id
    `)
    .bind(name, now, expiresAt, now, customer.id)
    .first();
  await env.evil_space
    .prepare(`
      INSERT INTO visits
        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
      VALUES (?, 'month', ?, ?, ?, ?, ?)
    `)
    .bind(name, membership.id, (await resolvePricing(env, serviceDayForOffset(0, now), now)).monthPassVnd, now, admin.email, customer.id)
    .run();
  await audit(env, admin, 'month_pass.create', 'membership', membership.id, name);
  return membership;
}

async function checkInMembership(env, membershipId, admin) {
  const now = nowSeconds();
  const membership = await env.evil_space
    .prepare('SELECT id, name, customer_id FROM memberships WHERE id = ? AND expires_at > ?')
    .bind(membershipId, now)
    .first();
  if (!membership) throw new OperationError('This membership is expired or missing.', 404);
  const { start, end } = nhaTrangDayBounds(now);
  const already = await env.evil_space
    .prepare('SELECT id FROM visits WHERE membership_id = ? AND created_at >= ? AND created_at < ? LIMIT 1')
    .bind(membership.id, start, end)
    .first();
  if (already) throw new OperationError('This customer is already checked in today.', 409);
  const visit = await env.evil_space
    .prepare(`
      INSERT INTO visits
        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
      VALUES (?, 'month', ?, 0, ?, ?, ?)
      RETURNING id
    `)
    .bind(membership.name, membership.id, now, admin.email, membership.customer_id)
    .first();
  await audit(env, admin, 'membership.checkin', 'visit', visit?.id, membership.name);
  return visit;
}

async function addPurchase(env, rawTitle, admin) {
  const title = cleanText(rawTitle, MAX_TEXT_LENGTH);
  if (!title) throw new OperationError('Purchase title is required.', 400);
  const item = await env.evil_space
    .prepare(`
      INSERT INTO purchase_requests (title, status, created_at, created_by_email)
      VALUES (?, 'needed', ?, ?)
      RETURNING id
    `)
    .bind(title, nowSeconds(), admin.email)
    .first();
  await audit(env, admin, 'purchase.create', 'purchase', item?.id, title);
  return item;
}

async function markPurchaseBought(env, id, admin) {
  const result = await env.evil_space
    .prepare(`
      UPDATE purchase_requests
      SET status = 'bought', bought_at = ?, bought_by_email = ?
      WHERE id = ? AND status = 'needed'
    `)
    .bind(nowSeconds(), admin.email, id)
    .run();
  if (!result.meta?.changes) throw new OperationError('Purchase was already completed.', 409);
  await audit(env, admin, 'purchase.bought', 'purchase', id, '');
}

async function notifyBookingOutcome(env, bookingId, status) {
  if (!telegramConfigured(env)) return;
  const booking = await bookingById(env, bookingId);
  if (!booking) return;

  const actor = booking.handled_by_email ?? '';
  const messages = await env.evil_space
    .prepare(`
      SELECT m.telegram_chat_id, m.telegram_message_id,
             COALESCE(l.language, 'en') AS language
      FROM telegram_booking_messages m
      LEFT JOIN admin_telegram_links l
        ON l.telegram_chat_id = m.telegram_chat_id
      WHERE m.booking_id = ?
    `)
    .bind(bookingId)
    .all();
  await Promise.all(
    (messages.results ?? []).map((message) => {
      const lang = normalizeLanguage(message.language);
      return telegramApi(env, 'editMessageText', {
        chat_id: message.telegram_chat_id,
        message_id: message.telegram_message_id,
        text: bookingAdminText(booking, status, actor, lang),
        parse_mode: 'HTML',
        reply_markup: { inline_keyboard: [[{ text: tr(lang, 'openAdmin'), url: 'https://evils.space/admin' }]] },
      }).catch(() => null);
    }),
  );

  const customer = await customerTelegramForBooking(env, bookingId);
  if (!customer) return;
  const lang = normalizeLanguage(customer.language);
  if (status === 'accepted') {
    await sendCustomerAccepted(env, customer.telegram_chat_id, bookingId, lang);
  } else if (status === 'declined') {
    await sendCustomerDeclined(env, customer.telegram_chat_id, lang);
  } else if (status === 'cancelled') {
    await sendCustomerCancelled(env, customer.telegram_chat_id, lang);
  }
}

async function sendCustomerPending(env, chatId, bookingId, language, connected = false) {
  const lang = normalizeLanguage(language);
  const heading = connected ? tr(lang, 'customerConnected') : tr(lang, 'customerPending');
  const copy = connected ? tr(lang, 'customerConnectedCopy') : tr(lang, 'customerPendingCopy');
  const booking = await bookingById(env, bookingId);
  const details = booking ? bookingCustomerDetails(booking, lang) : '';
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `${heading}\n\n${details}${details ? '\n\n' : ''}${copy}`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [{ text: tr(lang, 'cancelRequest'), callback_data: `cc:${bookingId}` }],
        [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: `cl:${lang}` }],
      ],
    },
  });
}

async function sendCustomerCancelConfirmation(env, chatId, bookingId, language) {
  const lang = normalizeLanguage(language);
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `⚠️ <b>${tr(lang, 'cancelConfirm')}</b>`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [[
        { text: `❌ ${tr(lang, 'confirmCancel')}`, callback_data: `cf:${bookingId}` },
        { text: `✅ ${tr(lang, 'keepBooking')}`, callback_data: `ck:${bookingId}` },
      ]],
    },
  });
}

async function sendCustomerAccepted(env, chatId, bookingId, language) {
  const lang = normalizeLanguage(language);
  const booking = await bookingById(env, bookingId);
  const details = booking ? bookingCustomerDetails(booking, lang) : '';
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `${tr(lang, 'customerAccepted')}\n\n${details}${details ? '\n\n' : ''}${tr(lang, 'customerAcceptedCopy')}`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
{ text: `❌ ${tr(lang, 'cancelBooking')}`, callback_data: `cc:${bookingId}` },
{ text: `📶 ${tr(lang, 'wifi')}`, callback_data: `cw:${bookingId}` },
        ],
        [{ text: tr(lang, 'directions'), url: 'https://www.google.com/maps/dir/?api=1&destination=Evil%20Space%2C%2060%20Cao%20V%C4%83n%20B%C3%A9%2C%20Nha%20Trang' }],
        [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: `cl:${lang}` }],
      ],
    },
  });
}

async function sendCustomerDeclined(env, chatId, language) {
  const lang = normalizeLanguage(language);
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `${tr(lang, 'customerDeclined')}\n\n${tr(lang, 'customerDeclinedCopy')}`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [{ text: tr(lang, 'openSite'), url: 'https://evils.space' }],
        [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: `cl:${lang}` }],
      ],
    },
  });
}

async function sendCustomerCancelled(env, chatId, language) {
  const lang = normalizeLanguage(language);
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `${tr(lang, 'customerCancelled')}\n\n${tr(lang, 'customerCancelledCopy')}`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [{ text: tr(lang, 'openSite'), url: 'https://evils.space' }],
        [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: `cl:${lang}` }],
      ],
    },
  });
}

async function sendCustomerHome(env, customer, chatId) {
  const lang = normalizeLanguage(customer?.language);
  const { today, end } = bookingWindow(nowSeconds());
  const result = await env.evil_space
    .prepare(`
      SELECT id, status
      FROM booking_requests
      WHERE customer_id = ? AND service_day >= ? AND service_day < ?
        AND status IN ('new', 'processing', 'accepted')
      ORDER BY service_day ASC, id DESC
      LIMIT 2
    `)
    .bind(customer.customer_id, today, end)
    .all();
  const bookings = result.results ?? [];

  if (!bookings.length) {
    return sendText(env, chatId, tr(lang, 'customerNoBooking'), {
      inline_keyboard: [
        [{ text: tr(lang, 'openSite'), url: 'https://evils.space' }],
        [{ text: `🌐 ${tr(lang, 'language')}`, callback_data: `cl:${lang}` }],
      ],
    });
  }
  for (const booking of bookings) {
    if (booking.status === 'accepted') {
      await sendCustomerAccepted(env, chatId, booking.id, lang);
    } else {
      await sendCustomerPending(env, chatId, booking.id, lang);
    }
  }
}

async function customerTelegramForBooking(env, bookingId) {
  return env.evil_space
    .prepare(`
      SELECT l.telegram_chat_id, l.telegram_user_id, l.language
      FROM booking_requests b
      JOIN customer_telegram_links l ON l.customer_id = b.customer_id
      WHERE b.id = ?
      LIMIT 1
    `)
    .bind(bookingId)
    .first();
}

async function todaySummary(env) {
  const now = nowSeconds();
  const { today, tomorrow, end } = bookingWindow(now);
  const row = await env.evil_space
    .prepare(`
      SELECT
        COALESCE((SELECT total_desks FROM site_state WHERE id = 1), 10) AS total,
        (SELECT COUNT(*) FROM visits WHERE created_at >= ? AND created_at < ?) AS occupied,
        (SELECT COUNT(*) FROM booking_requests WHERE status = 'new' AND service_day = ?) AS pending_today,
        (SELECT COUNT(*) FROM booking_requests WHERE status = 'new' AND service_day = ?) AS pending_tomorrow,
        COALESCE((SELECT SUM(amount) FROM visits WHERE created_at >= ? AND created_at < ?), 0) AS income
    `)
    .bind(today, tomorrow, today, tomorrow, today, tomorrow)
    .first();
  const pendingToday = Math.max(0, Number(row?.pending_today ?? 0));
  const pendingTomorrow = Math.max(0, Number(row?.pending_tomorrow ?? 0));
  return {
    total: Math.max(1, Number(row?.total ?? 10)),
    occupied: Math.max(0, Number(row?.occupied ?? 0)),
    pending: pendingToday + pendingTomorrow,
    pendingToday,
    pendingTomorrow,
    income: Math.max(0, Number(row?.income ?? 0)),
    tomorrowFree: Math.max(0, Number(row?.total ?? 10) - Number((await serviceDayCapacity(env, tomorrow)).occupied ?? 0)),
    end,
  };
}

async function linkedAdmin(env, telegramUserId) {
  return env.evil_space
    .prepare(`
      SELECT a.id, a.email, l.telegram_user_id, l.telegram_chat_id,
             l.telegram_username, l.booking_notifications, l.purchase_notifications,
             l.language
      FROM admin_telegram_links l
      JOIN admins a ON a.id = l.admin_id
      WHERE l.telegram_user_id = ? AND a.status = 'approved'
      LIMIT 1
    `)
    .bind(telegramUserId)
    .first();
}

async function linkedCustomer(env, telegramUserId) {
  return env.evil_space
    .prepare(`
      SELECT l.customer_id, l.telegram_user_id, l.telegram_chat_id,
             l.telegram_username, l.language, c.name
      FROM customer_telegram_links l
      JOIN customers c ON c.id = l.customer_id
      WHERE l.telegram_user_id = ?
      LIMIT 1
    `)
    .bind(telegramUserId)
    .first();
}

async function authenticatedWebAdmin(request, env) {
  const token = cookieValue(request, SESSION_COOKIE);
  if (!token) return null;
  const tokenHash = await hashToken(token);
  return env.evil_space
    .prepare(`
      SELECT a.id, a.email
      FROM admin_sessions s
      JOIN admins a ON a.id = s.admin_id
      WHERE s.token_hash = ? AND s.expires_at > ? AND a.status = 'approved'
      LIMIT 1
    `)
    .bind(tokenHash, nowSeconds())
    .first();
}

async function ensureCustomer(env, data) {
  const name = cleanText(data.name, MAX_NAME_LENGTH);
  if (!name) throw new OperationError('Customer name is required.', 400);
  const phone = cleanOptionalText(data.phone, MAX_TEXT_LENGTH);
  const telegram = cleanOptionalText(data.telegram, MAX_TEXT_LENGTH);
  let customer = null;
  if (phone) {
    customer = await env.evil_space.prepare('SELECT id FROM customers WHERE lower(phone) = lower(?) LIMIT 1').bind(phone).first();
  }
  if (!customer && telegram) {
    customer = await env.evil_space.prepare('SELECT id FROM customers WHERE lower(telegram) = lower(?) LIMIT 1').bind(telegram).first();
  }
  if (!customer) {
    customer = await env.evil_space.prepare('SELECT id FROM customers WHERE lower(name) = lower(?) ORDER BY id LIMIT 1').bind(name).first();
  }
  const now = nowSeconds();
  if (customer) {
    await env.evil_space
      .prepare(`
        UPDATE customers
        SET name = ?,
            phone = CASE WHEN ? <> '' THEN ? ELSE phone END,
            telegram = CASE WHEN ? <> '' THEN ? ELSE telegram END,
            updated_at = ?
        WHERE id = ?
      `)
      .bind(name, phone, phone, telegram, telegram, now, customer.id)
      .run();
    return { id: Number(customer.id), name };
  }
  const created = await env.evil_space
    .prepare(`
      INSERT INTO customers
        (name, phone, email, telegram, contact_other, notes, created_at, updated_at)
      VALUES (?, ?, '', ?, '', '', ?, ?)
      RETURNING id
    `)
    .bind(name, phone, telegram, now, now)
    .first();
  return { id: Number(created.id), name };
}

async function bookingById(env, id) {
  return env.evil_space
    .prepare(`
      SELECT id, name, contact_type, contact_value, status, created_at,
   handled_at, handled_by_email, customer_id, accepted_visit_id,
   service_day, amount_vnd
      FROM booking_requests
      WHERE id = ?
      LIMIT 1
    `)
    .bind(id)
    .first();
}

async function serviceDayCapacity(env, serviceDay) {
  const row = await env.evil_space
    .prepare(`
      SELECT
        COALESCE((SELECT total_desks FROM site_state WHERE id = 1), 10) AS total,
        (SELECT COUNT(*) FROM visits WHERE created_at >= ? AND created_at < ?) AS occupied
    `)
    .bind(serviceDay, serviceDay + 86400)
    .first();
  return {
    total: Math.max(1, Number(row?.total ?? 10)),
    occupied: Math.max(0, Number(row?.occupied ?? 0)),
  };
}

function bookingCustomerDetails(booking, language) {
  const lang = normalizeLanguage(language);
  const serviceDay = Number(booking.service_day ?? 0);
  const kind = bookingDayKind(serviceDay, nowSeconds());
  const label = kind === 'tomorrow' ? tr(lang, 'tomorrow') : tr(lang, 'today');
  return `<b>${label} · ${formatLocalDate(serviceDay)} · ${formatMoney(booking.amount_vnd)}</b>`;
}

async function customerById(env, id) {
  return env.evil_space
    .prepare(`
      SELECT c.id, c.name, COALESCE(c.phone, '') AS phone,
             COALESCE(c.email, '') AS email,
             COALESCE(c.telegram, '') AS telegram,
             MAX(CASE WHEN m.expires_at > ? THEN m.expires_at ELSE NULL END) AS active_until
      FROM customers c
      LEFT JOIN memberships m ON m.customer_id = c.id
      WHERE c.id = ?
      GROUP BY c.id
    `)
    .bind(nowSeconds(), id)
    .first();
}

async function audit(env, admin, action, entityType, entityId, detail) {
  if (!admin?.id) return;
  await env.evil_space
    .prepare(`
      INSERT INTO operation_audit
        (admin_id, actor_email, source, action, entity_type, entity_id, detail, created_at)
      VALUES (?, ?, 'telegram', ?, ?, ?, ?, ?)
    `)
    .bind(admin.id, admin.email ?? '', action, entityType ?? '', toPositiveInt(entityId), cleanOptionalText(detail, MAX_TEXT_LENGTH), nowSeconds())
    .run();
}

async function adminState(env, telegramUserId) {
  const state = await env.evil_space
    .prepare('SELECT state, payload_json, updated_at FROM telegram_admin_sessions WHERE telegram_user_id = ?')
    .bind(telegramUserId)
    .first();
  if (!state) return null;
  if (Number(state.updated_at) < nowSeconds() - SESSION_TTL) {
    await clearAdminState(env, telegramUserId);
    return null;
  }
  return state;
}

async function setAdminState(env, admin, state, payload) {
  await env.evil_space
    .prepare(`
      INSERT INTO telegram_admin_sessions
        (telegram_user_id, admin_id, state, payload_json, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(telegram_user_id)
      DO UPDATE SET admin_id = excluded.admin_id, state = excluded.state,
                    payload_json = excluded.payload_json, updated_at = excluded.updated_at
    `)
    .bind(admin.telegram_user_id, admin.id, state, JSON.stringify(payload ?? {}), nowSeconds())
    .run();
}

async function clearAdminState(env, telegramUserId) {
  await env.evil_space.prepare('DELETE FROM telegram_admin_sessions WHERE telegram_user_id = ?').bind(telegramUserId).run();
}

async function telegramApi(env, method, payload) {
  if (!telegramConfigured(env)) throw new Error('Telegram bot token is not configured.');
  const response = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok || data?.ok !== true) {
    throw new Error(`Telegram ${method} failed (${response.status}).`);
  }
  return data;
}

async function sendText(env, chatId, text, replyMarkup = null, html = false) {
  const payload = { chat_id: chatId, text };
  if (html) payload.parse_mode = 'HTML';
  if (replyMarkup) payload.reply_markup = replyMarkup;
  return telegramApi(env, 'sendMessage', payload);
}

async function answerCallback(env, callbackQueryId, text = '', showAlert = false) {
  if (!callbackQueryId) return;
  try {
    await telegramApi(env, 'answerCallbackQuery', {
      callback_query_id: callbackQueryId,
      text,
      show_alert: showAlert,
    });
  } catch (_) {}
}

function parseCommand(text) {
  if (!text.startsWith('/')) return null;
  const firstSpace = text.indexOf(' ');
  const head = (firstSpace === -1 ? text : text.slice(0, firstSpace)).slice(1);
  const name = head.split('@')[0].toLowerCase();
  const args = firstSpace === -1 ? '' : text.slice(firstSpace + 1);
  return { name, args };
}

function safeJson(raw) {
  try {
    const parsed = JSON.parse(raw || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= maxLength ? text : '';
}

function cleanOptionalText(value, maxLength) {
  if (value == null || value === '') return '';
  return cleanText(String(value), maxLength);
}

function formatMoney(value) {
  const amount = Math.max(0, Number(value ?? 0));
  if (amount === 0) return '0 VND';
  if (amount % 1000000 === 0) return `${amount / 1000000} MLN VND`;
  if (amount >= 1000000) return `${(amount / 1000000).toFixed(1).replace(/\.0$/, '')} MLN VND`;
  if (amount % 1000 === 0) return `${amount / 1000}K VND`;
  return `${amount} VND`;
}

function formatLocalTime(seconds) {
  const local = new Date((Number(seconds ?? 0) + 7 * 3600) * 1000);
  return `${String(local.getUTCHours()).padStart(2, '0')}:${String(local.getUTCMinutes()).padStart(2, '0')}`;
}

function formatLocalDate(seconds) {
  const local = new Date((Number(seconds ?? 0) + 7 * 3600) * 1000);
  return `${String(local.getUTCDate()).padStart(2, '0')}.${String(local.getUTCMonth() + 1).padStart(2, '0')}.${local.getUTCFullYear()}`;
}

function addCalendarMonth(now) {
  const date = new Date(now * 1000);
  const originalDay = date.getUTCDate();
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + 1);
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  date.setUTCDate(Math.min(originalDay, lastDay));
  return Math.floor(date.getTime() / 1000);
}

function cookieValue(request, name) {
  const raw = request.headers.get('cookie') ?? '';
  for (const part of raw.split(';')) {
    const trimmed = part.trim();
    if (trimmed.startsWith(`${name}=`)) return decodeURIComponent(trimmed.slice(name.length + 1));
  }
  return '';
}

async function readJson(request, maxBytes = 16384) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (length > maxBytes) return null;
  try {
    const body = await request.json();
    return body && typeof body === 'object' ? body : null;
  } catch {
    return null;
  }
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return toBase64Url(new Uint8Array(digest));
}

function randomToken(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return toBase64Url(bytes);
}

function toBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

function isReasonableToken(token) {
  return typeof token === 'string' && token.length >= 24 && token.length <= 128 && /^[A-Za-z0-9_-]+$/.test(token);
}

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : null;
}

function telegramConfigured(env) {
  return typeof env.TELEGRAM_BOT_TOKEN === 'string' && env.TELEGRAM_BOT_TOKEN.length > 20;
}

function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function safeError(error) {
  return error instanceof Error ? error.message : 'Unknown error';
}

function userMessage(error) {
  return error instanceof OperationError ? error.message : 'Could not complete the action.';
}

function operationError(error) {
  if (error instanceof OperationError) return jsonError(error.message, error.status);
  console.error('Telegram operation failed', safeError(error));
  return jsonError('Could not complete the operation.', 500);
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function jsonError(message, status) {
  return json({ ok: false, error: message }, status);
}

class OperationError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

export const telegramTest = {
  parseCommand,
  formatMoney,
  constantTimeEqual,
  nhaTrangDayBounds,
  normalizeLanguage,
  telegramBookingIdentity,
  serviceDateKey,
};
