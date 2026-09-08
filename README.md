# Evil Space

Production Flutter + Cloudflare application for Evil Space coworking in Nha Trang.

The public site keeps the quiet paper / e-reader visual language, while the backend now runs the real coworking operations: live desk availability, today/tomorrow booking, pricing, customers, memberships, purchases, admin access, and Telegram workflows.

## Production stack

- Flutter 3.47.2 web application
- Cloudflare Worker for `/api/*`
- Cloudflare D1 database
- Cloudflare Email Service for admin approval
- Telegram Bot API for customer/admin workflows
- Cloudflare native Worker rate limiting on sensitive public/admin endpoints
- `evils.space` as the production custom domain

There is no Supabase or Firebase dependency in the production stack.

## Public experience

The public site provides:

- live desk availability from D1
- booking for today or tomorrow
- booking status and cancellation through an opaque client token
- base pricing of `200K VND` day pass, `2.5M VND` month pass, and `1M VND / month` locker unless an active promotion overrides it
- English, Russian, and Vietnamese
- October room-opening information
- Instagram, Google Maps, Zalo, and phone contact actions

`/qr` opens the public experience at the visit/contact section.

## Admin

`/admin` uses server-side authentication. The browser receives only an `HttpOnly; Secure; SameSite=Strict` session cookie; passwords and session tokens are not stored in localStorage.

New administrators:

1. register with email/password
2. trigger a one-time owner approval email
3. can be explicitly approved or rejected
4. can sign in only after approval

Short passwords are intentionally supported for this small private admin surface. Brute-force protection is handled independently by Cloudflare Worker rate limiting.

The current compile-time switch is still named `EVIL_SPACE_ADMIN_PREVIEW` for compatibility. Despite the legacy name, it only enables rendering of the authenticated production admin dashboard; it does not bypass authentication.

Production builds use:

```bash
--dart-define=EVIL_SPACE_ADMIN_PREVIEW=true
```

## Worker architecture

The production request path is deliberately explicit:

```text
worker/secure_entry.js
  -> worker/security.js
  -> worker/app.js
       -> worker/entry.js          public booking + Telegram-aware routes
       -> worker/admin_review.js   owner approve/reject flow
       -> worker/admin_worker.js   admin-only boundary
            -> worker/index.js     existing admin operations core
```

`admin_worker.js` only permits `/api/admin/*` and `/api/health`. This prevents the older public handlers still present inside `index.js` from being reachable in production while the remaining admin core is extracted incrementally.

## Database

D1 schema changes live in `migrations/` and are applied in order:

```text
0001_initial.sql
...
0009_pricing_promotions.sql
```

The release process also runs the entire migration chain against a clean local D1 instance before any production migration is attempted.

## Testing

Fast application/unit tests:

```bash
flutter pub get
flutter test --no-pub
```

Full project verification:

```bash
make test
```

`make test` includes:

- Flutter tests
- Worker syntax checks
- Worker helper tests
- a real local Cloudflare Worker + D1 integration flow covering migrations, admin login/session/logout, unauthorized access, public booking, booking acceptance, live status, and owner rejection

The old source-string Worker contract tests were removed once the runtime integration flow covered those paths.

## Local development

```bash
flutter pub get
flutter run -d chrome --dart-define=EVIL_SPACE_ADMIN_PREVIEW=true
```

For Worker/D1 integration testing:

```bash
node worker/integration_test.mjs
```

Wrangler is pinned in:

```text
tool/wrangler_version.txt
```

Do not replace the pinned version with an unversioned `wrangler@latest` in release tooling.

## Release

```bash
make
```

The release script performs, in order:

1. Flutter version verification
2. Cloudflare account and remote D1 access preflight
3. Flutter analyze/tests
4. Worker syntax/helper tests
5. full local D1 migration + Worker integration test
6. optimized Flutter Wasm build
7. release bundle verification
8. pinned-Wrangler deployment dry run
9. remote D1 migrations
10. Worker/assets deployment
11. production `/api/health` verification

The dry run and clean local migration rehearsal happen before remote D1 changes, reducing the chance of discovering a packaging or schema problem only after production migration.

Other useful commands:

```bash
make build      # verified local release build, no deployment
make verify     # tests only, no build/deployment
make test       # full local test suite
```

## Runtime configuration

D1 and rate-limit bindings are declared in `wrangler.toml`.

Production secrets/configuration used by the Worker include:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_WEBHOOK_SECRET`
- `WIFI_PASSWORD`
- `SUPER_ADMIN_PASSWORD` when admin deletion is enabled

The admin approval email destination is `evilssspace79@gmail.com`, configured through the Cloudflare Email Service binding.

## CI

`.github/workflows/web-ci.yml` runs for `main`, `feature/**`, `agent/**`, and pull requests targeting `main`. It verifies Worker runtime integration, Flutter analysis/tests, the optimized Wasm build, generated bootstrap syntax, and the release contract/bundle budget.
