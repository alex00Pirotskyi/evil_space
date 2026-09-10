# Google Sign-In setup

Evil Space uses Google Identity Services (GIS) on the public web page and verifies the returned Google ID token in the Cloudflare Worker before creating or linking a customer account.

## Google Cloud / Google Auth Platform

Create an OAuth 2.0 client with application type **Web application**.

For production add this authorized JavaScript origin:

```text
https://evils.space
```

Also add this authorized redirect URI:

```text
https://evils.space/api/public/account/google/redirect
```

The redirect URI is required for iPhone and iPad. Google requires redirect UX mode on iOS because of Intelligent Tracking Prevention (ITP). Desktop browsers keep the popup flow.

Use a separate development client/origin for local testing when needed.

## Cloudflare Worker

Configure the web client ID as the Worker secret/environment value:

```text
GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
```

Using the repository-pinned Wrangler version, run:

```bat
npx --yes wrangler@<version-from-tool/wrangler_version.txt> secret put GOOGLE_CLIENT_ID
```

Paste only the Google **Web client ID** when prompted. A client ID is not a client secret; the Worker exposes it to the browser through `/api/public/account` so GIS can initialize.

## Runtime flow

1. The public account module reads provider configuration from `/api/public/account`.
2. Pressing **GOOGLE** opens the official Google Identity Services button.
3. Desktop browsers use popup mode. Google returns a signed ID token to the browser callback, and the browser sends it to `POST /api/public/account/google`.
4. iPhone and iPad use redirect mode. Before rendering the Google button, Evil Space creates a short-lived, one-time redirect state in D1 and remembers the current customer association plus the bounded first-party device profile.
5. Google posts the redirect credential to `POST /api/public/account/google/redirect` together with `g_csrf_token`. The Worker requires the form token to match Google's CSRF cookie and requires the Evil Space redirect state to be valid, unexpired, and unused.
6. The Worker verifies the Google credential and independently checks issuer, audience, expiry, subject, and verified email.
7. If the user already has an Evil Space customer session and the Google identity is unused, the Google identity is linked to that existing customer. The redirect state preserves that relationship even though the cross-site iOS POST does not rely on the Evil Space session cookie.
8. If the Google identity already belongs to another Evil Space customer, linking is rejected rather than silently merging accounts.
9. If no Evil Space session exists, the Google identity signs in to its existing customer or creates a new customer.
10. The Worker creates the normal secure `HttpOnly; Secure; SameSite=Lax` Evil Space customer session. The iOS redirect returns to `/`, where the account module reloads as `GOOGLE ✓`.

No Google access token or refresh token is requested or stored.
