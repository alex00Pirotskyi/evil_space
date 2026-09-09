# Evil Space admin setup

The production admin backend uses:

- Flutter web for `/admin`
- Cloudflare Worker for `/api/*`
- Cloudflare D1
- Cloudflare Email Service for owner approval
- server-side admin sessions with an `HttpOnly; Secure; SameSite=Strict` cookie
- Cloudflare Worker rate limiting for login/register and sensitive operations

There is no Supabase, Firebase, browser-stored admin token, or plaintext password storage.

## 1. Cloudflare email

Approval messages are sent to:

`evilssspace79@gmail.com`

The Worker sends from `admin@evils.space`.

In Cloudflare, verify the destination address and configure `evils.space` as an approved Email Service sending domain.

## 2. Secrets and payment configuration

Configure the Worker secrets used by the enabled features:

```text
TELEGRAM_BOT_TOKEN
TELEGRAM_WEBHOOK_SECRET
WIFI_PASSWORD
SUPER_ADMIN_PASSWORD
VIETQR_ACCOUNT_NUMBER
```

`SUPER_ADMIN_PASSWORD` is only required for the admin-deletion operation.

`VIETQR_ACCOUNT_NUMBER` must be the real Vietcombank account number that should receive `/menu` payments. Never use a `QRGD...` dynamic QR reference as the account number.

The menu payment generator defaults to Vietcombank/NAPAS BIN `970436`. Override it only if the receiving bank changes:

```text
VIETQR_BANK_BIN
```

The public site never supplies a trusted price. A menu order is created from the currently active D1 menu item, snapshots its server-side price, generates a unique `EVIL XXXXXX` transfer reference, and builds the VietQR payload in the Worker.

## 3. D1

D1 binding: `evil_space`

Database: `evil-space`

Migrations are stored in `migrations/`. Do not manually edit production tables in place when the change belongs in a migration.

For local migration/integration verification:

```bat
node worker/integration_test.mjs
```

For a manual remote migration run, use the repository-pinned Wrangler version from `tool/wrangler_version.txt` rather than an unversioned latest release.

Normal production deployment should use:

```bat
make
```

The release script rehearses all migrations against clean local D1, performs a Wrangler deployment dry run, then applies remote migrations and deploys the Worker/assets.

## 4. Admin build switch

The authenticated dashboard is currently enabled with:

```bat
flutter build web --release --wasm --dart-define=EVIL_SPACE_ADMIN_PREVIEW=true
```

`EVIL_SPACE_ADMIN_PREVIEW` is a legacy name. It does not provide preview/sample authorization and does not bypass the Worker session check; it only enables the authenticated admin UI in that Flutter build.

The production release script already supplies this define.

## Admin approval flow

1. Open `/admin`.
2. Select **NEW ADMIN? REQUEST ACCESS**.
3. Enter the candidate email and password.
4. The Worker stores a random salt and PBKDF2 password hash, never the plaintext password.
5. Cloudflare emails the owner a one-time review link.
6. The owner explicitly chooses **APPROVE ADMIN** or **REJECT ADMIN**.
7. Either decision consumes the one-time approval token.
8. Approved admins can sign in; rejected admins cannot.
9. Successful sign-in creates a random server-side session and returns only the secure session cookie.

Approval links expire after 24 hours. Admin sessions expire after 14 days.

Short passwords are intentionally allowed for this private admin surface. Cloudflare rate limiting is applied separately to reduce brute-force abuse.

## Menu administration

After signing in, use the **MENU** button in `/admin` or open `/admin/menu` directly.

Upload one JSON document. Publishing a valid document creates a new catalog version and atomically makes it active; existing orders keep their original item name and price snapshot.

Example:

```json
{
  "version": 1,
  "groups": [
    {
      "id": "beverages",
      "name": "Beverages",
      "items": [
        {
          "id": "cola",
          "name": "Cola",
          "priceVnd": 30000,
          "description": null
        }
      ]
    }
  ]
}
```

The public menu is `/menu`. A customer presses **BUY**, scans the generated QR, and the page polls the order status. Linked Telegram admins receive the order with an **ITEM PAID** action. Only a linked approved admin can confirm it. The admin menu page also provides a manual **MARK PAID** fallback.

## Telegram admin

After signing in, an approved admin can connect Telegram from the admin UI. The generated link is temporary and stores only a token hash in D1. Telegram webhook requests must include the configured webhook secret.

Menu-order notifications use the existing purchase-notification preference. Pressing **ITEM PAID** performs an idempotent server-side state transition; the public page changes to **PAYMENT CONFIRMED** on its next poll.

## Production domain

`evils.space` is configured as the Worker custom domain. `/api/*` remains same-origin with the Flutter application, so browser admin operations do not need a public API token or permissive CORS configuration.

After deployment, `tool/release.dart` verifies:

```text
https://evils.space/api/health
```
