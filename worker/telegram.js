const SESSION_COOKIE = '__Host-evil_admin_session';
const BOT_USERNAME = 'CoworkingEvilAdminBot';
const DAY_PASS_VND = 250000;
const MONTH_PASS_VND = 2500000;
const ADMIN_LINK_TTL = 10 * 60;
const CUSTOMER_LINK_TTL = 6 * 60 * 60;
const SESSION_TTL = 30 * 60;
const MAX_NAME_LENGTH = 100;
const MAX_TEXT_LENGTH = 180;
const WIFI_SSID = 'Evil Space';

export async function handleAdminTelegramStatus(request, env) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);

  const link = await env.evil_space
    .prepare(`
      SELECT telegram_username, notifications_enabled,
             booking_notifications, purchase_notifications, linked_at
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
    botUsername: BOT_USERNAME,
  });
}

export async function handleAdminTelegramLink(request, env) {
  const admin = await authenticatedWebAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);

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
          (token_hash, admin_id, created_at, expires_at, used_at)
        VALUES (?, ?, ?, ?, NULL)
      `)
      .bind(tokenHash, admin.id, now, now + ADMIN_LINK_TTL),
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

export async function createCustomerTelegramLink(env, bookingId) {
  const id = toPositiveInt(bookingId);
  if (!id) return null;
  const now = nowSeconds();
  const { end } = nhaTrangDayBounds(now);
  const expiresAt = Math.min(end, now + CUSTOMER_LINK_TTL);
  if (expiresAt <= now) return null;

  const token = randomToken(24);
  const tokenHash = await hashToken(token);
  await env.evil_space.batch([
    env.evil_space
      .prepare('DELETE FROM customer_telegram_link_tokens WHERE booking_id = ? AND used_at IS NULL')
      .bind(id),
    env.evil_space
      .prepare(`
        INSERT INTO customer_telegram_link_tokens
          (token_hash, booking_id, created_at, expires_at, used_at)
        VALUES (?, ?, ?, ?, NULL)
      `)
      .bind(tokenHash, id, now, expiresAt),
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
      SELECT id, status, customer_id, accepted_visit_id, created_at
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
      SELECT l.telegram_chat_id
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
        await sendBookingToAdmin(env, link.telegram_chat_id, booking);
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
      SELECT l.telegram_chat_id
      FROM admin_telegram_links l
      JOIN admins a ON a.id = l.admin_id
      WHERE a.status = 'approved'
        AND l.notifications_enabled = 1
        AND l.purchase_notifications = 1
    `)
    .all();

  const text = `🛒 <b>NEW PURCHASE REQUEST</b>\n\n${escapeHtml(clean)}\n\nOpen /buy to manage the shared list.`;
  await Promise.all(
    (links.results ?? []).map((link) =>
      telegramApi(env, 'sendMessage', {
        chat_id: link.telegram_chat_id,
        text,
        parse_mode: 'HTML',
        reply_markup: adminMenuKeyboard(),
      }).catch((error) =>
        console.error('Telegram purchase notification failed', safeError(error)),
      ),
    ),
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
  }

  const admin = await linkedAdmin(env, user.id);
  if (!admin) {
    await telegramApi(env, 'sendMessage', {
      chat_id: chatId,
      text: 'This Telegram account is not linked.\n\nAdmins: open evils.space/admin → Telegram.\nCustomers: request a desk on evils.space and press CONNECT TELEGRAM.',
    });
    return;
  }

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
}

async function handleAdminCommand(env, admin, chatId, command) {
  const args = command.args.trim();
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
      return sendIncome(env, chatId);
    case 'day':
      if (args) return prepareNamedOperation(env, admin, chatId, 'confirm_day', args);
      await setAdminState(env, admin, 'wait_day_name', {});
      return sendText(env, chatId, 'DAY PASS · send the customer name.\n\n/cancel to stop.');
    case 'month':
      if (args) return prepareNamedOperation(env, admin, chatId, 'confirm_month', args);
      return sendMonthMenu(env, chatId);
    case 'customer':
    case 'customers':
      if (args) return sendCustomerSearch(env, chatId, args);
      await setAdminState(env, admin, 'wait_customer_search', {});
      return sendText(env, chatId, 'CUSTOMERS · send a name, phone, Telegram or email to search.\n\n/cancel to stop.');
    case 'buy':
      if (args) return preparePurchase(env, admin, chatId, args);
      return sendBuy(env, chatId);
    case 'settings':
      return sendSettings(env, admin, chatId);
    case 'cancel':
      await clearAdminState(env, admin.telegram_user_id);
      return sendText(env, chatId, 'Cancelled.', adminMenuKeyboard());
    case 'help':
      return sendText(
        env,
        chatId,
        'EVIL SPACE ADMIN\n\n/menu — main menu\n/today — today\n/bookings — pending desk requests\n/day Name — day pass\n/month Name — new month pass\n/customer Alex — search customers\n/income — income\n/buy Item — add purchase request\n/settings — notifications\n/cancel — cancel current action',
        adminMenuKeyboard(),
      );
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
      return sendCustomerSearch(env, chatId, text);
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
    if (data.startsWith('cc:') || data.startsWith('cw:')) {
      await handleCustomerCallback(env, callback, userId, chatId, data);
      return;
    }

    const admin = await linkedAdmin(env, userId);
    if (!admin) {
      await answerCallback(env, callback.id, 'Telegram is not linked to an approved admin.', true);
      return;
    }

    if (data.startsWith('ba:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, 'Invalid booking.', true);
      try {
        const booking = await acceptBooking(env, id, admin);
        await answerCallback(env, callback.id, 'Booking accepted.');
        await notifyBookingOutcome(env, booking.id, 'accepted');
      } catch (error) {
        await answerCallback(env, callback.id, userMessage(error), true);
      }
      return;
    }

    if (data.startsWith('bd:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, 'Invalid booking.', true);
      try {
        const booking = await declineBooking(env, id, admin);
        await answerCallback(env, callback.id, 'Booking declined.');
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
        await answerCallback(env, callback.id, 'Checked in.');
        await sendToday(env, admin, chatId);
      } catch (error) {
        await answerCallback(env, callback.id, userMessage(error), true);
      }
      return;
    }

    if (data.startsWith('cust:')) {
      const id = toPositiveInt(data.slice(5));
      await answerCallback(env, callback.id);
      if (id) await sendCustomer(env, chatId, id);
      return;
    }

    if (data.startsWith('cd:') || data.startsWith('cm:')) {
      const id = toPositiveInt(data.slice(3));
      const customer = id ? await customerById(env, id) : null;
      if (!customer) return answerCallback(env, callback.id, 'Customer not found.', true);
      const state = data.startsWith('cd:') ? 'confirm_day' : 'confirm_month';
      await answerCallback(env, callback.id);
      return prepareNamedOperation(env, admin, chatId, state, customer.name);
    }

    if (data.startsWith('pb:')) {
      const id = toPositiveInt(data.slice(3));
      if (!id) return answerCallback(env, callback.id, 'Invalid purchase.', true);
      try {
        await markPurchaseBought(env, id, admin);
        await answerCallback(env, callback.id, 'Marked bought.');
        await sendBuy(env, chatId);
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
        return sendText(env, chatId, 'DAY PASS · send the customer name.\n\n/cancel to stop.');
      case 'm:month':
        await answerCallback(env, callback.id);
        return sendMonthMenu(env, chatId);
      case 'm:customers':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_customer_search', {});
        return sendText(env, chatId, 'CUSTOMERS · send a search value.\n\n/cancel to stop.');
      case 'm:income':
        await answerCallback(env, callback.id);
        return sendIncome(env, chatId);
      case 'm:buy':
        await answerCallback(env, callback.id);
        return sendBuy(env, chatId);
      case 'm:settings':
        await answerCallback(env, callback.id);
        return sendSettings(env, admin, chatId);
      case 'month:new':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_month_name', {});
        return sendText(env, chatId, 'NEW MONTH PASS · send the customer name.\n\n/cancel to stop.');
      case 'month:active':
        await answerCallback(env, callback.id);
        return sendActiveMemberships(env, chatId);
      case 'buy:add':
        await answerCallback(env, callback.id);
        await setAdminState(env, admin, 'wait_purchase_title', {});
        return sendText(env, chatId, 'PURCHASE · send what needs to be bought.\n\n/cancel to stop.');
      case 'op:cancel':
        await answerCallback(env, callback.id, 'Cancelled.');
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
        await answerCallback(env, callback.id, 'Updated.');
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
  const bookingId = toPositiveInt(data.slice(3));
  if (!bookingId) return answerCallback(env, callback.id, 'Invalid booking.', true);
  const booking = await env.evil_space
    .prepare(`
      SELECT b.id, b.status, b.customer_id, b.accepted_visit_id, b.created_at
      FROM booking_requests b
      JOIN customer_telegram_links l ON l.customer_id = b.customer_id
      WHERE b.id = ? AND l.telegram_user_id = ?
    `)
    .bind(bookingId, userId)
    .first();
  if (!booking) return answerCallback(env, callback.id, 'This booking is not linked to you.', true);

  const { start, end } = nhaTrangDayBounds(nowSeconds());
  const createdAt = Number(booking.created_at ?? 0);
  if (createdAt < start || createdAt >= end) {
    return answerCallback(env, callback.id, 'This booking has expired.', true);
  }

  if (data.startsWith('cc:')) {
    try {
      const cancelled = await cancelBookingRecord(env, booking, 'telegram');
      await answerCallback(env, callback.id, 'Booking cancelled.');
      await sendText(env, chatId, '❌ <b>BOOKING CANCELLED</b>\n\nYou can request another desk anytime at evils.space.', null, true);
      await notifyBookingOutcome(env, cancelled.id, 'cancelled');
    } catch (error) {
      await answerCallback(env, callback.id, userMessage(error), true);
    }
    return;
  }

  if (booking.status !== 'accepted') {
    return answerCallback(env, callback.id, 'Wi-Fi is available after the booking is accepted.', true);
  }
  if (typeof env.WIFI_PASSWORD !== 'string' || !env.WIFI_PASSWORD) {
    return answerCallback(env, callback.id, 'Wi-Fi access is not configured yet.', true);
  }

  await answerCallback(env, callback.id, 'Wi-Fi details sent.');
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `📶 <b>EVIL SPACE WI-FI</b>\n\nNetwork: <code>${escapeHtml(WIFI_SSID)}</code>\nPassword: <code>${escapeHtml(env.WIFI_PASSWORD)}</code>`,
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: 'COPY NETWORK', copy_text: { text: WIFI_SSID } },
          { text: 'COPY PASSWORD', copy_text: { text: env.WIFI_PASSWORD } },
        ],
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
      SELECT t.admin_id, t.expires_at, a.email
      FROM admin_telegram_link_tokens t
      JOIN admins a ON a.id = t.admin_id
      WHERE t.token_hash = ? AND t.used_at IS NULL AND a.status = 'approved'
    `)
    .bind(tokenHash)
    .first();
  if (!pending || Number(pending.expires_at) <= now) {
    return sendText(env, chatId, 'This admin link expired. Open the Evil Space admin panel and generate a new one.');
  }

  const username = user.username ? `@${user.username}` : '';
  await env.evil_space.batch([
    env.evil_space.prepare('DELETE FROM admin_telegram_links WHERE admin_id = ? OR telegram_user_id = ?').bind(pending.admin_id, user.id),
    env.evil_space
      .prepare(`
        INSERT INTO admin_telegram_links
          (admin_id, telegram_user_id, telegram_chat_id, telegram_username,
           notifications_enabled, booking_notifications, purchase_notifications,
           linked_at, updated_at)
        VALUES (?, ?, ?, ?, 1, 1, 1, ?, ?)
      `)
      .bind(pending.admin_id, user.id, chatId, username, now, now),
    env.evil_space.prepare('UPDATE admin_telegram_link_tokens SET used_at = ? WHERE token_hash = ?').bind(now, tokenHash),
  ]);

  const admin = await linkedAdmin(env, user.id);
  await audit(env, admin, 'telegram.link', 'admin', admin.id, username);
  await sendText(env, chatId, `✅ <b>TELEGRAM ADMIN CONNECTED</b>\n\n${escapeHtml(pending.email)}\n\nYou can operate Evil Space from this chat.`, adminMenuKeyboard(), true);
  await sendAdminMenu(env, admin, chatId);
}

async function pairCustomer(env, user, chatId, token) {
  if (!isReasonableToken(token)) return sendText(env, chatId, 'This booking link is invalid.');
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const pending = await env.evil_space
    .prepare(`
      SELECT t.booking_id, t.expires_at,
             b.id, b.name, b.contact_type, b.contact_value, b.status, b.customer_id, b.created_at
      FROM customer_telegram_link_tokens t
      JOIN booking_requests b ON b.id = t.booking_id
      WHERE t.token_hash = ? AND t.used_at IS NULL
    `)
    .bind(tokenHash)
    .first();
  if (!pending || Number(pending.expires_at) <= now) {
    return sendText(env, chatId, 'This booking link expired. Return to evils.space and create a new desk request if needed.');
  }
  const { start, end } = nhaTrangDayBounds(now);
  const createdAt = Number(pending.created_at ?? 0);
  if (createdAt < start || createdAt >= end || !['new', 'accepted'].includes(pending.status)) {
    return sendText(env, chatId, 'This booking is no longer active.');
  }

  const username = user.username ? `@${user.username}` : '';
  const customer = await ensureCustomer(env, {
    name: pending.name,
    telegram: username || (pending.contact_type === 'telegram' ? pending.contact_value : ''),
  });

  await env.evil_space.batch([
    env.evil_space.prepare('DELETE FROM customer_telegram_links WHERE customer_id = ? OR telegram_user_id = ?').bind(customer.id, user.id),
    env.evil_space
      .prepare(`
        INSERT INTO customer_telegram_links
          (customer_id, telegram_user_id, telegram_chat_id, telegram_username, linked_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `)
      .bind(customer.id, user.id, chatId, username, now, now),
    env.evil_space.prepare('UPDATE booking_requests SET customer_id = ? WHERE id = ?').bind(customer.id, pending.id),
    env.evil_space.prepare('UPDATE customer_telegram_link_tokens SET used_at = ? WHERE token_hash = ?').bind(now, tokenHash),
  ]);

  if (pending.status === 'accepted') {
    await sendCustomerAccepted(env, chatId, pending.id);
  } else {
    await telegramApi(env, 'sendMessage', {
      chat_id: chatId,
      text: '✅ <b>BOOKING UPDATES CONNECTED</b>\n\nWe will message you here when Evil Space accepts or declines your desk request.',
      parse_mode: 'HTML',
      reply_markup: {
        inline_keyboard: [[{ text: 'CANCEL REQUEST', callback_data: `cc:${pending.id}` }]],
      },
    });
  }
}

async function sendAdminMenu(env, admin, chatId) {
  const summary = await todaySummary(env);
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: `🗞 <b>EVIL SPACE ADMIN</b>\n\nToday: <b>${summary.occupied}/${summary.total}</b> desks\nPending bookings: <b>${summary.pending}</b>\nIncome: <b>${formatMoney(summary.income)}</b>`,
    parse_mode: 'HTML',
    reply_markup: adminMenuKeyboard(),
  });
}

function adminMenuKeyboard() {
  return {
    inline_keyboard: [
      [
        { text: 'TODAY', callback_data: 'm:today' },
        { text: 'BOOKINGS', callback_data: 'm:bookings' },
      ],
      [
        { text: 'DAY PASS', callback_data: 'm:day' },
        { text: 'MONTH', callback_data: 'm:month' },
      ],
      [
        { text: 'CUSTOMERS', callback_data: 'm:customers' },
        { text: 'INCOME', callback_data: 'm:income' },
      ],
      [
        { text: 'BUY', callback_data: 'm:buy' },
        { text: 'SETTINGS', callback_data: 'm:settings' },
      ],
    ],
  };
}

async function sendToday(env, admin, chatId) {
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
    (visit) => `• ${escapeHtml(visit.name)} · ${visit.kind === 'month' ? 'MONTH' : 'DAY'} · ${formatLocalTime(visit.created_at)}`,
  );
  const text = [
    '📋 <b>TODAY</b>',
    '',
    `Occupied: <b>${summary.occupied}/${summary.total}</b>`,
    `Income: <b>${formatMoney(summary.income)}</b>`,
    `Pending bookings: <b>${summary.pending}</b>`,
    '',
    ...(lines.length ? lines : ['Nobody yet.']),
  ].join('\n');
  await sendText(env, chatId, text, adminMenuKeyboard(), true);
}

async function sendPendingBookings(env, admin, chatId) {
  const { start, end } = nhaTrangDayBounds(nowSeconds());
  const result = await env.evil_space
    .prepare(`
      SELECT id, name, contact_type, contact_value, status, created_at
      FROM booking_requests
      WHERE status = 'new' AND created_at >= ? AND created_at < ?
      ORDER BY created_at ASC, id ASC
      LIMIT 50
    `)
    .bind(start, end)
    .all();
  const bookings = result.results ?? [];
  if (!bookings.length) {
    await sendText(env, chatId, '✅ No pending bookings.', adminMenuKeyboard());
    return;
  }
  for (const booking of bookings) {
    await sendBookingToAdmin(env, chatId, booking);
  }
}

async function sendBookingToAdmin(env, chatId, booking) {
  const response = await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: bookingAdminText(booking, 'new'),
    parse_mode: 'HTML',
    reply_markup: bookingAdminKeyboard(booking.id),
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

function bookingAdminText(booking, status, actor = '') {
  const contact = booking.contact_type === 'telegram' ? 'TG' : 'PHONE';
  const heading = status === 'accepted'
    ? '✅ BOOKING ACCEPTED'
    : status === 'declined'
      ? '❌ BOOKING DECLINED'
      : status === 'cancelled'
        ? '🚫 BOOKING CANCELLED'
        : '🔔 NEW DESK REQUEST';
  return [
    `<b>${heading}</b>`,
    '',
    `<b>${escapeHtml(booking.name ?? '')}</b>`,
    `${contact}: ${escapeHtml(booking.contact_value ?? '')}`,
    `Time: ${formatLocalTime(booking.created_at)}`,
    actor ? `By: ${escapeHtml(actor)}` : '',
  ].filter(Boolean).join('\n');
}

function bookingAdminKeyboard(id) {
  return {
    inline_keyboard: [
      [
        { text: '✅ ACCEPT', callback_data: `ba:${id}` },
        { text: '❌ DECLINE', callback_data: `bd:${id}` },
      ],
      [{ text: 'OPEN ADMIN', url: 'https://evils.space/admin' }],
    ],
  };
}

async function sendMonthMenu(env, chatId) {
  return sendText(env, chatId, 'MONTH PASS', {
    inline_keyboard: [
      [{ text: 'NEW MONTH PASS', callback_data: 'month:new' }],
      [{ text: 'CHECK IN ACTIVE MEMBER', callback_data: 'month:active' }],
      [{ text: 'BACK', callback_data: 'm:today' }],
    ],
  });
}

async function sendActiveMemberships(env, chatId) {
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
  if (!rows.length) return sendText(env, chatId, 'No active memberships.', adminMenuKeyboard());
  rows.push([{ text: 'BACK', callback_data: 'm:month' }]);
  return sendText(env, chatId, 'ACTIVE MEMBERS · tap to check in', { inline_keyboard: rows });
}

async function prepareNamedOperation(env, admin, chatId, state, value) {
  const name = cleanText(value, MAX_NAME_LENGTH);
  if (!name) return sendText(env, chatId, 'Name is required.');
  await setAdminState(env, admin, state, { name });
  const isMonth = state === 'confirm_month';
  return sendText(env, chatId, `${isMonth ? 'MONTH PASS' : 'DAY PASS'}\n\n<b>${escapeHtml(name)}</b>\n${isMonth ? '2.5 MLN VND' : '250K VND'}\n\nConfirm?`, {
    inline_keyboard: [
      [
        { text: 'CONFIRM', callback_data: isMonth ? 'op:month:ok' : 'op:day:ok' },
        { text: 'CANCEL', callback_data: 'op:cancel' },
      ],
    ],
  }, true);
}

async function preparePurchase(env, admin, chatId, value) {
  const title = cleanText(value, MAX_TEXT_LENGTH);
  if (!title) return sendText(env, chatId, 'Purchase title is required.');
  await setAdminState(env, admin, 'confirm_buy', { title });
  return sendText(env, chatId, `ADD PURCHASE REQUEST\n\n<b>${escapeHtml(title)}</b>\n\nConfirm?`, {
    inline_keyboard: [[
      { text: 'CONFIRM', callback_data: 'op:buy:ok' },
      { text: 'CANCEL', callback_data: 'op:cancel' },
    ]],
  }, true);
}

async function confirmStateOperation(env, callback, admin, chatId, expectedState) {
  const session = await adminState(env, admin.telegram_user_id);
  if (!session || session.state !== expectedState) {
    return answerCallback(env, callback.id, 'This action expired. Start again.', true);
  }
  const payload = safeJson(session.payload_json);
  try {
    if (expectedState === 'confirm_day') {
      await addDayPass(env, payload.name, admin);
      await answerCallback(env, callback.id, 'Day pass added.');
    } else if (expectedState === 'confirm_month') {
      await addMonthPass(env, payload.name, admin);
      await answerCallback(env, callback.id, 'Month pass added.');
    } else if (expectedState === 'confirm_buy') {
      await addPurchase(env, payload.title, admin);
      await answerCallback(env, callback.id, 'Purchase request added.');
      await notifyAdminsPurchase(env, payload.title);
    }
    await clearAdminState(env, admin.telegram_user_id);
    return sendAdminMenu(env, admin, chatId);
  } catch (error) {
    return answerCallback(env, callback.id, userMessage(error), true);
  }
}

async function sendCustomerSearch(env, chatId, raw) {
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
  if (!customers.length) return sendText(env, chatId, 'No customers found.', adminMenuKeyboard());
  return sendText(env, chatId, `CUSTOMERS · ${customers.length} result(s)`, {
    inline_keyboard: [
      ...customers.map((customer) => [
        { text: customer.name, callback_data: `cust:${customer.id}` },
      ]),
      [{ text: 'BACK', callback_data: 'm:customers' }],
    ],
  });
}

async function sendCustomer(env, chatId, customerId) {
  const customer = await customerById(env, customerId);
  if (!customer) return sendText(env, chatId, 'Customer not found.', adminMenuKeyboard());
  const contact = [customer.phone, customer.telegram, customer.email].filter(Boolean).join(' · ') || 'No contact';
  const membership = customer.active_until
    ? `ACTIVE UNTIL ${formatLocalDate(customer.active_until)}`
    : 'NO ACTIVE MONTH PASS';
  return sendText(env, chatId, `<b>${escapeHtml(customer.name)}</b>\n${escapeHtml(contact)}\n${membership}`, {
    inline_keyboard: [
      [
        { text: 'DAY PASS', callback_data: `cd:${customer.id}` },
        { text: 'MONTH PASS', callback_data: `cm:${customer.id}` },
      ],
      [{ text: 'BACK', callback_data: 'm:customers' }],
    ],
  }, true);
}

async function sendIncome(env, chatId) {
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
  return sendText(env, chatId, `💰 <b>INCOME</b>\n\nToday: <b>${formatMoney(row?.today)}</b>\n7 days: <b>${formatMoney(row?.seven)}</b>\n30 days: <b>${formatMoney(row?.thirty)}</b>\nAll: <b>${formatMoney(row?.total)}</b>`, adminMenuKeyboard(), true);
}

async function sendBuy(env, chatId) {
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
  rows.unshift([{ text: 'ADD PURCHASE', callback_data: 'buy:add' }]);
  rows.push([{ text: 'BACK', callback_data: 'm:today' }]);
  return sendText(env, chatId, '🛒 TO BUY\n\nTap an item after it has been bought.', { inline_keyboard: rows });
}

async function sendSettings(env, admin, chatId) {
  const book = Number(admin.booking_notifications) === 1;
  const buy = Number(admin.purchase_notifications) === 1;
  return sendText(env, chatId, '⚙️ NOTIFICATIONS', {
    inline_keyboard: [
      [{ text: `Bookings ${book ? 'ON' : 'OFF'}`, callback_data: 'set:book' }],
      [{ text: `Purchases ${buy ? 'ON' : 'OFF'}`, callback_data: 'set:buy' }],
      [{ text: 'BACK', callback_data: 'm:today' }],
    ],
  });
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

async function acceptBooking(env, bookingId, admin) {
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const existing = await bookingById(env, bookingId);
  if (!existing) throw new OperationError('Booking not found.', 404);
  const createdAt = Number(existing.created_at ?? 0);
  if (createdAt < start || createdAt >= end) throw new OperationError('This desk request expired at midnight.', 410);

  const claimed = await env.evil_space
    .prepare(`
      UPDATE booking_requests
      SET status = 'processing', handled_at = ?, handled_by_email = ?
      WHERE id = ? AND status = 'new'
      RETURNING id, name, contact_type, contact_value, created_at
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
    const already = await env.evil_space
      .prepare(`
        SELECT id FROM visits
        WHERE customer_id = ? AND created_at >= ? AND created_at < ?
        LIMIT 1
      `)
      .bind(customer.id, start, end)
      .first();

    let acceptedVisitId = null;
    if (!already) {
      const visit = await env.evil_space
        .prepare(`
          INSERT INTO visits
            (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
          VALUES (?, 'day', NULL, ?, ?, ?, ?)
          RETURNING id
        `)
        .bind(claimed.name, DAY_PASS_VND, now, admin.email, customer.id)
        .first();
      acceptedVisitId = toPositiveInt(visit?.id);
    }

    await env.evil_space
      .prepare(`
        UPDATE booking_requests
        SET status = 'accepted', customer_id = ?, accepted_visit_id = ?
        WHERE id = ? AND status = 'processing'
      `)
      .bind(customer.id, acceptedVisitId, bookingId)
      .run();
    await audit(env, admin, 'booking.accept', 'booking', bookingId, claimed.name);
    return { ...claimed, id: bookingId, customer_id: customer.id, accepted_visit_id: acceptedVisitId };
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
  const { start, end } = nhaTrangDayBounds(now);
  const existing = await bookingById(env, bookingId);
  if (!existing) throw new OperationError('Booking not found.', 404);
  const createdAt = Number(existing.created_at ?? 0);
  if (createdAt < start || createdAt >= end) throw new OperationError('This desk request expired at midnight.', 410);

  const declined = await env.evil_space
    .prepare(`
      UPDATE booking_requests
      SET status = 'declined', handled_at = ?, handled_by_email = ?
      WHERE id = ? AND status = 'new'
      RETURNING id, name, contact_type, contact_value, created_at
    `)
    .bind(now, admin.email, bookingId)
    .first();
  if (!declined) throw new OperationError('Booking request was already handled.', 409);
  await audit(env, admin, 'booking.decline', 'booking', bookingId, declined.name);
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
    .bind(name, DAY_PASS_VND, now, admin.email, customer.id)
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
    .bind(name, membership.id, MONTH_PASS_VND, now, admin.email, customer.id)
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
    .prepare('SELECT telegram_chat_id, telegram_message_id FROM telegram_booking_messages WHERE booking_id = ?')
    .bind(bookingId)
    .all();
  await Promise.all(
    (messages.results ?? []).map((message) =>
      telegramApi(env, 'editMessageText', {
        chat_id: message.telegram_chat_id,
        message_id: message.telegram_message_id,
        text: bookingAdminText(booking, status, actor),
        parse_mode: 'HTML',
        reply_markup: { inline_keyboard: [[{ text: 'OPEN ADMIN', url: 'https://evils.space/admin' }]] },
      }).catch(() => null),
    ),
  );

  const customer = await customerTelegramForBooking(env, bookingId);
  if (!customer) return;
  if (status === 'accepted') {
    await sendCustomerAccepted(env, customer.telegram_chat_id, bookingId);
  } else if (status === 'declined') {
    await telegramApi(env, 'sendMessage', {
      chat_id: customer.telegram_chat_id,
      text: '❌ <b>BOOKING DECLINED</b>\n\nWe could not confirm this desk request. You can make another request anytime at evils.space.',
      parse_mode: 'HTML',
      reply_markup: { inline_keyboard: [[{ text: 'OPEN EVIL SPACE', url: 'https://evils.space' }]] },
    });
  } else if (status === 'cancelled') {
    await telegramApi(env, 'sendMessage', {
      chat_id: customer.telegram_chat_id,
      text: '🚫 <b>BOOKING CANCELLED</b>\n\nYour desk is no longer counted as occupied.',
      parse_mode: 'HTML',
    });
  }
}

async function sendCustomerAccepted(env, chatId, bookingId) {
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: '✅ <b>BOOKING ACCEPTED</b>\n\nYour desk at Evil Space is confirmed for today.\nOpen daily 11:00–23:00.\n\nYou can cancel here anytime if your plans change.',
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '❌ CANCEL BOOKING', callback_data: `cc:${bookingId}` },
          { text: '📶 WI-FI', callback_data: `cw:${bookingId}` },
        ],
        [{ text: 'DIRECTIONS', url: 'https://www.google.com/maps/dir/?api=1&destination=Evil%20Space%2C%2060%20Cao%20V%C4%83n%20B%C3%A9%2C%20Nha%20Trang' }],
      ],
    },
  });
}

async function customerTelegramForBooking(env, bookingId) {
  return env.evil_space
    .prepare(`
      SELECT l.telegram_chat_id, l.telegram_user_id
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
  const { start, end } = nhaTrangDayBounds(now);
  const row = await env.evil_space
    .prepare(`
      SELECT
        COALESCE((SELECT total_desks FROM site_state WHERE id = 1), 10) AS total,
        (SELECT COUNT(*) FROM visits WHERE created_at >= ? AND created_at < ?) AS occupied,
        (SELECT COUNT(*) FROM booking_requests WHERE status = 'new' AND created_at >= ? AND created_at < ?) AS pending,
        COALESCE((SELECT SUM(amount) FROM visits WHERE created_at >= ? AND created_at < ?), 0) AS income
    `)
    .bind(start, end, start, end, start, end)
    .first();
  return {
    total: Math.max(1, Number(row?.total ?? 10)),
    occupied: Math.max(0, Number(row?.occupied ?? 0)),
    pending: Math.max(0, Number(row?.pending ?? 0)),
    income: Math.max(0, Number(row?.income ?? 0)),
  };
}

async function linkedAdmin(env, telegramUserId) {
  return env.evil_space
    .prepare(`
      SELECT a.id, a.email, l.telegram_user_id, l.telegram_chat_id,
             l.telegram_username, l.booking_notifications, l.purchase_notifications
      FROM admin_telegram_links l
      JOIN admins a ON a.id = l.admin_id
      WHERE l.telegram_user_id = ? AND a.status = 'approved'
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
             handled_at, handled_by_email, customer_id, accepted_visit_id
      FROM booking_requests
      WHERE id = ?
      LIMIT 1
    `)
    .bind(id)
    .first();
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

function nhaTrangDayBounds(now) {
  const offset = 7 * 3600;
  const local = new Date((now + offset) * 1000);
  const localMidnightUtc = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) / 1000;
  const start = localMidnightUtc - offset;
  return { start, end: start + 86400 };
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
};
