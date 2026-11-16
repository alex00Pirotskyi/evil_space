# VCB browser bridge (temporary until SePay personal VCB)

The new `POST /api/webhooks/vcb-browser` endpoint accepts HMAC-SHA256-signed transaction observations from the owner-operated Chrome extension. It reuses `applyTransaction` and the existing Evil Space pending menu order, exact amount and EVIL order-code validation.

**Default is observe-only:** without `VCB_BROWSER_AUTO_CONFIRM=1` the endpoint can return `candidate` but **never marks a payment paid**. Browser-visible transactions are not bank-attested. Use a real transfer test and independent bank reconciliation before deciding whether browser-based auto-confirmation is acceptable.

## Deployment

1. Review and merge the feature branch, then use the existing Evil Space production release workflow.
2. Generate a standalone random secret locally (at least 32 characters): `python -c "import secrets; print(secrets.token_urlsafe(48))"`.
3. Set `VCB_BROWSER_HMAC_SECRET` in your Cloudflare Worker: `npx wrangler secret put VCB_BROWSER_HMAC_SECRET`. Never commit the secret. Keep `VIETQR_ACCOUNT_NUMBER` aligned with the selected receiving account.
4. Install the independently packaged Chrome extension from the provided `evil-vcb-secure-bridge.zip` by extracting it and selecting `chrome-extension` from `chrome://extensions` → Developer mode → Load unpacked.
5. Paste the standalone secret in the extension popup and click Test connection. Sign into VCB Digibank manually and open account details/transaction history with today's date range.
6. Create a pending menu checkout, transfer the exact QR amount and `EVIL XXXXXX` order reference, and verify the new observed transaction produces `candidate`. Existing transactions present when the extension starts are baseline-only.
7. Leave observe-only until field testing establishes sufficient reliability. If you explicitly accept non-bank-attested risk, you may later set `VCB_BROWSER_AUTO_CONFIRM=1` using a Cloudflare environment secret/variable. It is **not** recommended for irreversible fulfillment.

The extension does not access passwords, OTP, cookies or proprietary VCB APIs. It clicks the bank's visible Search button at random 30–60-second intervals. Session expiration is never bypassed. Background uploads use the extension's own cross-origin permission, with retry queue. The client is compatible with existing menu checkout status polling, not booking or subscription payments. No D1 migration is needed.

**Security caution:** Signed events prove possession of the bridge secret, not that Vietcombank confirmed the transaction. Compromise of the browser or secret can create fraudulent payment events. The server filters receiving account, transaction date, pending order, exact amount and replay. Use manual verification and migrate to an authorized provider feed when SePay becomes available.
