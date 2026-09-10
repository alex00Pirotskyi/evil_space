# Google Sign-In setup

Evil Space uses Google Identity Services (GIS) on the public web page and verifies the returned Google ID token in the Cloudflare Worker before creating or linking a customer account.

## Google Cloud / Google Auth Platform

Create an OAuth 2.0 client with application type **Web application**.

For production add this authorized JavaScript origin:

```text
https://evils.space
```

Use a separate development client/origin for local testing when needed.

The current Evil Space flow uses the GIS popup/button callback, so it does not rely on an OAuth redirect URI or put an ID token in the page URL.

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
2. Pressing **GOOGLE** opens Google Identity Services using the configured Web client ID.
3. Google returns a signed ID token to the browser callback.
4. The browser sends that ID token plus the existing first-party device profile to `POST /api/public/account/google`.
5. The Worker asks Google's token verification endpoint to validate the credential and independently checks issuer, audience, expiry, subject, and verified email.
6. If the browser already has an Evil Space customer session and the Google identity is unused, the Google identity is linked to that existing customer.
7. If the Google identity already belongs to another Evil Space customer, linking is rejected rather than silently merging accounts.
8. If no Evil Space session exists, the Google identity signs in to its existing customer or creates a new customer.
9. The Worker stores only the Google subject, verified email/display identity, customer profile data, and bounded device metadata. It creates the normal secure `HttpOnly; Secure; SameSite=Lax` Evil Space customer session.

No Google access token or refresh token is requested or stored.
