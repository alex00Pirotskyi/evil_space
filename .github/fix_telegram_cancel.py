from pathlib import Path

path = Path('worker/telegram.js')
text = path.read_text(encoding='utf-8')

replacements = {
    "    cancelRequest: 'CANCEL REQUEST',\n": "    cancelRequest: 'CANCEL REQUEST',\n    cancelConfirm: 'Cancel this desk request?',\n    confirmCancel: 'YES, CANCEL',\n    keepBooking: 'KEEP BOOKING',\n    bookingKept: 'Booking kept.',\n",
    "    cancelRequest: 'ОТМЕНИТЬ ЗАПРОС',\n": "    cancelRequest: 'ОТМЕНИТЬ ЗАПРОС',\n    cancelConfirm: 'Отменить этот запрос на стол?',\n    confirmCancel: 'ДА, ОТМЕНИТЬ',\n    keepBooking: 'ОСТАВИТЬ БРОНЬ',\n    bookingKept: 'Бронь сохранена.',\n",
    "    cancelRequest: 'HỦY YÊU CẦU',\n": "    cancelRequest: 'HỦY YÊU CẦU',\n    cancelConfirm: 'Hủy yêu cầu đặt bàn này?',\n    confirmCancel: 'CÓ, HỦY',\n    keepBooking: 'GIỮ ĐẶT BÀN',\n    bookingKept: 'Đã giữ đặt bàn.',\n",
    "    if (data.startsWith('cc:') || data.startsWith('cw:')) {\n": "    if (data.startsWith('cc:') || data.startsWith('cf:') || data.startsWith('ck:') || data.startsWith('cw:')) {\n",
}
for old, new in replacements.items():
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one match for {old!r}, found {count}')
    text = text.replace(old, new)

old_block = """  if (data.startsWith('cc:')) {
    try {
      const cancelled = await cancelBookingRecord(env, booking, 'telegram');
      await answerCallback(env, callback.id, tr(lang, 'bookingCancelledCallback'));
      await sendCustomerCancelled(env, chatId, lang);
      await notifyBookingOutcome(env, cancelled.id, 'cancelled');
    } catch (error) {
      await answerCallback(env, callback.id, userMessage(error), true);
    }
    return;
  }

  if (booking.status !== 'accepted') {
"""
new_block = """  if (data.startsWith('cc:')) {
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
"""
if text.count(old_block) != 1:
    raise SystemExit('customer cancel block did not match exactly once')
text = text.replace(old_block, new_block)

anchor = "async function sendCustomerAccepted(env, chatId, bookingId, language) {\n"
confirmation = """async function sendCustomerCancelConfirmation(env, chatId, bookingId, language) {
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

"""
if text.count(anchor) != 1:
    raise SystemExit('sendCustomerAccepted anchor did not match exactly once')
text = text.replace(anchor, confirmation + anchor)
path.write_text(text, encoding='utf-8')

test_path = Path('test/telegram_contract_test.dart')
test_text = test_path.read_text(encoding='utf-8')
test_anchor = """    test('Wi-Fi and bot credentials are runtime secrets, never constants', () {
"""
regression = """    test('customer cancellation requires a second explicit tap', () {
      expect(
        telegram,
        contains(
          "if (data.startsWith('cc:') || data.startsWith('cf:') || data.startsWith('ck:') || data.startsWith('cw:'))",
        ),
      );
      expect(telegram, contains('sendCustomerCancelConfirmation'));
      expect(telegram, contains('callback_data: `cf:${bookingId}`'));
      expect(telegram, contains('callback_data: `ck:${bookingId}`'));

      final ask = telegram.indexOf("if (data.startsWith('cc:')) {");
      final confirm = telegram.indexOf("if (data.startsWith('cf:')) {", ask);
      expect(ask, greaterThanOrEqualTo(0));
      expect(confirm, greaterThan(ask));
      expect(
        telegram.substring(ask, confirm),
        isNot(contains('cancelBookingRecord')),
      );

      final wifi = telegram.indexOf(
        "if (booking.status !== 'accepted')",
        confirm,
      );
      expect(wifi, greaterThan(confirm));
      final confirmedCancel = telegram.substring(confirm, wifi);
      expect(
        confirmedCancel,
        contains("cancelBookingRecord(env, booking, 'telegram')"),
      );
      expect(
        confirmedCancel,
        contains("notifyBookingOutcome(env, cancelled.id, 'cancelled')"),
      );
      expect(
        confirmedCancel,
        isNot(contains('sendCustomerCancelled(env, chatId, lang)')),
      );
    });

"""
if test_text.count(test_anchor) != 1:
    raise SystemExit('telegram contract test anchor did not match exactly once')
test_text = test_text.replace(test_anchor, regression + test_anchor)
test_path.write_text(test_text, encoding='utf-8')
