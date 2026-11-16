# Evil Space VCB bookmarklet — temporary payment confirmation

One Chrome bookmarklet. No extension, extra HMAC secret, or new Cloudflare configuration.

## Flow

1. Customer checks out using the current VietQR (EVIL XXXXXX order reference).
2. Owner signs in normally to the VCB Digibank web account details screen and clicks the EVIL VCB bookmarklet.
3. Bookmarklet opens a small https://evils.space/api/admin/vcb-relay window. It uses the **existing Evil Space admin login** (/admin); no new key or password is required.
4. Bookmarklet presses the bank page's visible Search button at randomized 30–60-second intervals. Only *newly observed* incoming credits carrying an EVIL order reference are sent by postMessage to the relay window.
5. Relay makes a same-origin, admin-authenticated POST to /api/admin/vcb-confirm. Worker checks the configured receiving account, credit direction, bank reference, date, pending EVIL order, and **exact amount**. The existing D1 unique provider/reference index prevents duplicate confirmations.
6. A match sets menu_orders.status = paid. Flutter menu polls every two seconds and now returns to the menu after a brief confirmation. Telegram ORDER PAID updates the same status and triggers the same return.

Existing Casso and Android provider implementations remain unchanged. No new D1 migrations.

## Install

Installable HTML/bookmarklet source is provided in the companion evil-vcb-simple-bookmarklet.zip package. Drag EVIL • VCB Payments from install.html onto Chrome's bookmarks bar. It runs directly on the VCB account detail page; no extension.

Make sure the selected VCB account matches VIETQR_ACCOUNT_NUMBER on Cloudflare. Keep both windows open with today's transaction-history range. If the bridge asks for a login, sign in through the evils.space/admin link in its window and click Check connection.

## Limits

- Only **menu** payments, not coworking bookings or monthly memberships.
- Existing history rows at launch are baseline-only; it reports newly discovered credits.
- VCB web history reveals a date, not bank-attested time. Matching is restricted to recent pending orders. Wrong amount, unknown code, wrong receiving account, cancelled order or replay are ignored.
- Expired VCB sessions, closed tabs, throttled background timers, or changed bank HTML can interrupt payment monitoring. Telegram manual confirmation remains available.
- **Bank web page data is not bank-attested evidence.** Reuse the existing admin login as minimal authority; never expose a public unauthenticated mark-paid endpoint. Do not automate VCB login. Switch to SePay's official feed when personal accounts are supported.

## Deploy

Merge PR into main, run existing make production workflow, then install the new bookmarklet. No VCB_BROWSER_HMAC_SECRET, no VCB_BROWSER_AUTO_CONFIRM, no Chrome extension.
