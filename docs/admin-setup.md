# Evil Space admin activation

The repository now contains the admin product shell, the Postgres schema, row-level security policies, audit logging, Realtime tables, and the server-side push fan-out function. The public build keeps `/admin` locked until a real Supabase/Firebase connection is added; there is no local password fallback.

## Security boundary

| Concern | Authority |
| --- | --- |
| Staff identity | Supabase Auth email magic link |
| Owner / manager / staff role | `public.profiles.role` behind RLS |
| Customer, payment, and purchase data | Postgres behind RLS |
| Live in-app events | Supabase Realtime |
| Background device notifications | Firebase Cloud Messaging via an Edge Function |
| UI preferences | Local device storage is acceptable |

Never store an admin password, an authorization role, or a service-role key in SharedPreferences, LocalStorage, the Flutter asset bundle, or a `--dart-define`. A browser-held session identifies the user; Postgres RLS still decides what that user may read or change.

## 1. Create and migrate Supabase

Use a dedicated Supabase project, then apply:

```text
supabase/migrations/202608290001_admin_foundation.sql
```

With the Supabase CLI linked to the project:

```bash
supabase db push
```

The migration creates:

- staff profiles with `viewer`, `staff`, `manager`, and `owner` roles
- the public desk status, exact display labels `250K VND` and `2.5 MLN VND`, and both 20 October openings
- customers and pass periods
- an integer-VND payment ledger with due, paid, refunded, and void states
- purchase requests from needed through bought
- notifications, device tokens, per-device delivery records, and audit history
- Realtime publication entries for public status, purchases, and notifications

## 2. Configure staff identity

Enable email magic links in Supabase Auth. Staff accounts should be invited by an owner; the client must request OTP with user creation disabled. Add the production callback URL for `/admin` to the Auth redirect allowlist.

Every new Auth user receives a `viewer` profile and therefore has no operational access. After creating the first trusted account, bootstrap exactly one owner from the SQL editor:

```sql
select id, email from auth.users order by created_at;

update public.profiles
set role = 'owner'
where id = '<verified-user-id>';
```

After bootstrap, use the `set_staff_access` RPC. Only an existing owner can call it. Managers can operate the space but cannot promote accounts.

## 3. Connect the Flutter client

Add the official `supabase_flutter` client and initialize it with the project URL and publishable key. These two values are public client configuration; the service-role key must never enter Flutter.

The production flow should be:

1. `/admin` requests a magic link for an already invited email.
2. Supabase restores the browser session after the callback.
3. The app loads the caller's profile.
4. `viewer`, missing, or inactive profiles are denied.
5. Staff queries go through the RLS-protected tables.
6. Realtime refreshes status, purchase, payment, and notification views.

The current gate intentionally stays closed until this adapter and the project configuration exist. For UI review only, sample data can be enabled locally:

```bash
flutter run -d chrome --dart-define=EVIL_SPACE_ADMIN_PREVIEW=true
```

Never use that preview define for production. It writes nothing and labels itself as sample data.

## 4. Enable background notifications

Create a Firebase project and web app, enable Cloud Messaging, and deploy:

```text
supabase/functions/push-notifications/index.ts
```

Required Edge Function secrets:

```text
PUSH_WEBHOOK_SECRET
FIREBASE_SERVICE_ACCOUNT_JSON
ADMIN_URL
```

Supabase automatically supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to deployed functions. `ADMIN_URL` must be the full HTTPS admin address.

Create a Supabase Database Webhook for `INSERT` on `public.notifications`:

- method: `POST`
- target: the deployed `push-notifications` function URL
- header: `x-webhook-secret: <PUSH_WEBHOOK_SECRET>`

The function accepts both a normal database-webhook body and a direct `{ "notification_id": "..." }` request. It selects only active devices in the event audience, sends FCM HTTP v1 messages, records each result, and marks fully delivered events as dispatched.

The Flutter client still needs Firebase configuration files, notification permission UX, token registration in `device_tokens`, and a service worker for web background delivery. Realtime should remain the foreground path; FCM is the background path.

## 5. Production checks

- Build without `EVIL_SPACE_ADMIN_PREVIEW`.
- Verify anonymous users can read only `site_state`.
- Verify a `viewer` cannot read customers, payments, purchases, or notifications.
- Verify staff cannot verify payments or delete financial/customer records.
- Verify only owners can change staff access or delete records.
- Verify device tokens are visible only to their owner and the server-side service role.
- Confirm every payment and purchase mutation appears in `audit_log`.
- Test notification delivery and revocation on web, Android, and iOS separately.

For stronger separation, host the admin at `admin.evils.space` and optionally place Cloudflare Access in front of it. Supabase Auth and RLS remain required even when that outer gate is enabled.
