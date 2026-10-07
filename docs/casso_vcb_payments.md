# Automatic Vietcombank payment confirmation

Evil Space can automatically confirm menu payments from the existing VietQR
checkout flow using a Casso webhook.

## How it works

1. The menu checkout creates a unique transfer description: `EVIL <ORDER_CODE>`.
2. The customer pays the exact QR amount into the configured Vietcombank account.
3. Casso watches that bank account and POSTs the incoming transaction to:
   `https://evils.space/api/webhooks/casso`
4. The Worker accepts the event only when:
   - the `secure-token` header matches `CASSO_WEBHOOK_SECRET`;
   - the incoming amount is positive;
   - the transaction description contains a valid Evil Space order code;
   - the account number, when supplied by Casso, matches `VIETQR_ACCOUNT_NUMBER`;
   - the order is still pending; and
   - the incoming amount exactly equals the current order total.
5. The order is marked paid exactly once. Casso transaction IDs are unique in D1,
   making webhook retries/replays harmless.
6. The existing Flutter checkout status poll sees `paid` and updates automatically.

No Vietcombank password, Casso API key, or webhook secret is stored in Flutter.

## One-time production setup

### 1. Add a Cloudflare Worker secret

Generate a long random value and store it directly in Cloudflare:

```sh
npx wrangler secret put CASSO_WEBHOOK_SECRET
```

Do not commit this value to GitHub.

### 2. Configure Casso

Connect the same Vietcombank account used by `VIETQR_ACCOUNT_NUMBER`.

Create a webhook integration with:

- Webhook URL: `https://evils.space/api/webhooks/casso`
- Security key: exactly the value stored as `CASSO_WEBHOOK_SECRET`
- Incoming transactions only: enabled
- Bank/account: the Vietcombank account used by Evil Space

Casso sends the configured security key in the `secure-token` HTTP header.

### 3. Deploy

The production release applies D1 migrations before deploying the Worker.

### 4. Smoke test

Create a small real menu order and pay its QR without modifying the transfer
description. The checkout should switch to paid automatically after the bank
transaction reaches Casso.

## Safety behavior

Transactions are ignored rather than guessed when the order reference is
missing, the amount differs, the order was cancelled/expired, or an explicit
account number differs from the configured VietQR account. Manual admin payment
confirmation remains available as a fallback.
