import { consumePromoForMenuOrder } from './promo_engine.js';

const WEBHOOK_PATH = '/api/webhooks/casso';
const MAX_BODY_BYTES = 64 * 1024;
const MAX_DESCRIPTION_LENGTH = 1024;
const MAX_REFERENCE_LENGTH = 180;
const MAX_TRANSACTION_TIME_LENGTH = 80;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== WEBHOOK_PATH) {
      return jsonError('Not found.', 404);
    }

    const secret = cleanSecret(env.CASSO_WEBHOOK_SECRET);
    if (!secret) {
      return jsonError('Payment webhook is not configured.', 503);
    }

    const supplied = request.headers.get('secure-token') ?? '';
    if (!constantTimeEqual(supplied, secret)) {
      return jsonError('Unauthorized.', 401);
    }

    const body = await readJson(request);
    if (!body) return jsonError('Invalid webhook payload.', 400);

    // Casso uses error=0 for a normal delivery. A provider-side error is
    // acknowledged so it does not create a retry storm against the checkout.
    if (Number(body.error ?? 0) !== 0) {
      return json({ ok: true, accepted: 0, matched: 0, ignored: 0 });
    }

    const transactions = normalizeCassoTransactions(body);
    let matched = 0;
    let ignored = 0;
    let alreadyPaid = 0;

    for (const transaction of transactions) {
      const result = await applyTransaction(env, transaction);
      if (result === 'matched') matched += 1;
      else if (result === 'already_paid') alreadyPaid += 1;
      else ignored += 1;
    }

    return json({
      ok: true,
      accepted: transactions.length,
      matched,
      alreadyPaid,
      ignored,
    });
  },
};

async function applyTransaction(env, transaction) {
  if (!transaction.transactionId || !transaction.orderCode) return 'ignored';
  if (!transactionMatchesConfiguredAccount(transaction, env.VIETQR_ACCOUNT_NUMBER)) {
    return 'ignored';
  }

  const order = await env.evil_space
    .prepare(`
      SELECT id, order_code, amount_vnd, status, checkout_revision,
             payment_provider, payment_transaction_id
      FROM menu_orders
      WHERE order_code = ?
      LIMIT 1
    `)
    .bind(transaction.orderCode)
    .first();

  if (!order) return 'ignored';

  if (String(order.status) === 'paid') {
    return String(order.payment_provider ?? '') === 'casso' &&
      String(order.payment_transaction_id ?? '') === transaction.transactionId
      ? 'already_paid'
      : 'ignored';
  }
  if (String(order.status) !== 'pending') return 'ignored';
  if (Number(order.amount_vnd) !== transaction.amountVnd) return 'ignored';

  const now = nowSeconds();
  let result;
  try {
    result = await env.evil_space
      .prepare(`
        UPDATE menu_orders
        SET status = 'paid',
            paid_at = ?,
            payment_provider = 'casso',
            payment_transaction_id = ?,
            payment_bank_reference = ?,
            payment_transaction_at = ?
        WHERE id = ?
          AND status = 'pending'
          AND amount_vnd = ?
          AND checkout_revision = ?
      `)
      .bind(
        now,
        transaction.transactionId,
        transaction.bankReference || null,
        transaction.transactionAt || null,
        Number(order.id),
        transaction.amountVnd,
        Number(order.checkout_revision ?? 0),
      )
      .run();
  } catch (error) {
    // The unique provider/transaction index makes webhook replays harmless.
    if (String(error).toLowerCase().includes('unique')) return 'ignored';
    throw error;
  }

  if (Number(result.meta?.changes ?? 0) !== 1) {
    const raced = await env.evil_space
      .prepare(`
        SELECT status, payment_provider, payment_transaction_id
        FROM menu_orders
        WHERE id = ?
        LIMIT 1
      `)
      .bind(Number(order.id))
      .first();
    if (
      String(raced?.status ?? '') === 'paid' &&
      String(raced?.payment_provider ?? '') === 'casso' &&
      String(raced?.payment_transaction_id ?? '') === transaction.transactionId
    ) {
      return 'already_paid';
    }
    return 'ignored';
  }

  await consumePromoForMenuOrder(env, Number(order.id), now);
  return 'matched';
}

export function normalizeCassoTransactions(body) {
  const data = body?.data;
  const rawTransactions = Array.isArray(data)
    ? data
    : data && typeof data === 'object'
      ? [data]
      : [];

  const normalized = [];
  for (const raw of rawTransactions) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;

    const amountVnd = Number(raw.amount);
    if (
      !Number.isSafeInteger(amountVnd) ||
      amountVnd <= 0 ||
      amountVnd > 10_000_000_000
    ) {
      continue;
    }

    const description = cleanText(raw.description, MAX_DESCRIPTION_LENGTH);
    const cassoId = Number(raw.id);
    const bankReference = firstText(
      raw.reference,
      raw.tid,
      MAX_REFERENCE_LENGTH,
    );
    const transactionId =
      Number.isSafeInteger(cassoId) && cassoId > 0
        ? `id:${cassoId}`
        : bankReference
          ? `ref:${bankReference}`
          : '';

    normalized.push({
      transactionId,
      bankReference,
      amountVnd,
      description,
      orderCode: extractOrderCode(description),
      accountNumber: cleanAccountNumber(
        raw.accountNumber ?? raw.bank_sub_acc_id ?? raw.subAccId,
      ),
      transactionAt: firstText(
        raw.transactionDateTime,
        raw.when,
        MAX_TRANSACTION_TIME_LENGTH,
      ),
    });
  }
  return normalized;
}

export function extractOrderCode(description) {
  const text = typeof description === 'string' ? description.toUpperCase() : '';
  const match = /(?:^|[^A-Z0-9])EVIL[\s._-]*([A-HJ-NP-Z2-9]{6})(?=$|[^A-Z0-9])/.exec(text);
  return match?.[1] ?? '';
}

export function transactionMatchesConfiguredAccount(transaction, configuredAccount) {
  const expected = cleanAccountNumber(configuredAccount);
  if (!expected) return true;
  const received = cleanAccountNumber(transaction?.accountNumber);
  return !received || received === expected;
}

function firstText(first, second, maxLength) {
  return cleanText(first, maxLength) || cleanText(second, maxLength);
}

function cleanText(value, maxLength) {
  if (value == null) return '';
  const text = String(value).trim().replace(/\s+/g, ' ');
  return text.length <= maxLength ? text : '';
}

function cleanAccountNumber(value) {
  if (value == null) return '';
  const text = String(value).replace(/\D/g, '');
  return text.length >= 4 && text.length <= 32 ? text : '';
}

function cleanSecret(value) {
  const text = typeof value === 'string' ? value.trim() : '';
  return text.length >= 16 && text.length <= 256 ? text : '';
}

function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

async function readJson(request) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(length) && length > MAX_BODY_BYTES) return null;
  try {
    const body = await request.json();
    return body && typeof body === 'object' ? body : null;
  } catch {
    return null;
  }
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
