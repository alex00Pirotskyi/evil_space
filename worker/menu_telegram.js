import { markMenuOrderPaidByTelegram } from './menu.js';

export async function handleMenuTelegramShortcut(request, env) {
  if (!env.TELEGRAM_WEBHOOK_SECRET || !env.TELEGRAM_BOT_TOKEN) return null;
  const supplied = request.headers.get('X-Telegram-Bot-Api-Secret-Token') ?? '';
  if (!constantTimeEqual(supplied, env.TELEGRAM_WEBHOOK_SECRET)) return null;

  let update;
  try {
    update = await request.clone().json();
  } catch {
    return null;
  }

  const callback = update?.callback_query;
  const data = typeof callback?.data === 'string' ? callback.data : '';
  const match = /^mp:(\d+)$/.exec(data);
  if (!match) return null;

  const userId = Number(callback?.from?.id ?? 0);
  const chatId = Number(callback?.message?.chat?.id ?? 0);
  const messageId = Number(callback?.message?.message_id ?? 0);
  if (!userId || !chatId) return json({ ok: true });

  const result = await markMenuOrderPaidByTelegram(env, Number(match[1]), userId);
  if (result.status === 'forbidden') {
    await answerCallback(env, callback.id, 'Telegram is not linked to an approved admin.', true);
    return json({ ok: true });
  }
  if (result.status === 'missing' || result.status === 'invalid') {
    await answerCallback(env, callback.id, 'Order not found.', true);
    return json({ ok: true });
  }
  if (result.status === 'expired') {
    await answerCallback(env, callback.id, 'Order has expired.', true);
    return json({ ok: true });
  }

  await answerCallback(env, callback.id, 'Payment confirmed.');
  if (messageId) {
    await telegramApi(env, 'editMessageReplyMarkup', {
      chat_id: chatId,
      message_id: messageId,
      reply_markup: { inline_keyboard: [] },
    }).catch(() => null);
  }

  const order = result.order;
  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: [
      '✅ PAID',
      '',
      `Order: ${order.orderCode}`,
      order.itemName,
      formatVnd(order.amountVnd),
      `Confirmed by: ${order.paidByEmail ?? 'admin'}`,
    ].join('\n'),
  }).catch((error) => console.error('Telegram paid confirmation failed', safeError(error)));

  return json({ ok: true });
}

async function answerCallback(env, callbackId, text, showAlert = false) {
  if (!callbackId) return;
  await telegramApi(env, 'answerCallbackQuery', {
    callback_query_id: callbackId,
    text,
    show_alert: showAlert,
  }).catch(() => null);
}

async function telegramApi(env, method, payload) {
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

function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let index = 0; index < a.length; index += 1) {
    diff |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return diff === 0;
}

function formatVnd(value) {
  return `${Number(value).toLocaleString('en-US')} VND`;
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function safeError(error) {
  return error instanceof Error ? error.message : String(error);
}
