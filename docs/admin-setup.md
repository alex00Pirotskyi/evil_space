# Evil Space admin setup

The admin backend is intentionally small:

- Flutter web for the public site and admin UI
- one Cloudflare Worker for `/api/*`
- one Cloudflare D1 database
- Cloudflare Email Service for owner approval
- an HttpOnly session cookie for signed-in admins

There is no Supabase, Firebase, browser-stored admin token, or plaintext password storage.

## 1. Cloudflare email setup

The approval message is sent to:

`evilssspace79@gmail.com`

In the Cloudflare dashboard:

1. Go to **Compute → Email Service → Email Routing → Destination Addresses**.
2. Add `evilssspace79@gmail.com`.
3. Open the verification email Cloudflare sends and verify the address.
4. Go to **Compute → Email Service → Email Sending**.
5. Onboard `evils.space` as a sending domain.

The Worker sends approval mail from `admin@evils.space`.

## 2. Apply D1 migrations

From the repository root:

```bat
npx wrangler d1 migrations apply evil-space --remote
```

This creates the small admin/session tables plus the basic coworking tables.

## 3. Build the Flutter admin

```bat
flutter build web --release --dart-define=EVIL_SPACE_ADMIN_PREVIEW=true
```

The flag enables the existing operations dashboard after the Worker confirms an approved session.

## 4. Deploy

```bat
npx wrangler deploy
```

Test the generated `workers.dev` URL before attaching the production domain.

## Admin approval flow

1. Open `/admin`.
2. Select **NEW ADMIN? REQUEST ACCESS**.
3. Enter the candidate admin email and password.
4. The Worker hashes the password with PBKDF2 and stores only the salt and hash.
5. Cloudflare emails the owner a one-time review link.
6. The owner opens the link and explicitly chooses **APPROVE ADMIN** or **REJECT**.
7. Approval consumes the one-time token.
8. The approved admin can sign in.
9. The Worker creates a random server-side session and gives the browser only an `HttpOnly; Secure; SameSite=Strict` cookie.

Approval links expire after 24 hours. Admin sessions expire after 14 days.

## Production domain

After the `workers.dev` deployment is confirmed, attach `evils.space` as a Worker custom domain in Cloudflare. The API remains same-origin under `/api/*`, so no CORS configuration or public API token is needed.
