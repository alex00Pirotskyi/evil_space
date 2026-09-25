# ChatGPT booking action for Evil Space

This optional integration lets a configured ChatGPT action check live desks for
today or tomorrow in Nha Trang and submit a **pending day-pass request**.
Staff still accepts or declines each request in the existing admin/Telegram
flow. The Flutter web app, including installation as a phone PWA, is unchanged.

## Endpoints

| Method | URL | Credential | Result |
| --- | --- | --- | --- |
| GET | `https://evils.space/api/assistant/availability` | None | Two local dates, current accepted occupancy and live VND prices |
| POST | `https://evils.space/api/assistant/booking` | Assistant key | Creates a pending request after user consent |
| GET | `https://evils.space/api/assistant/booking?token=...` | Assistant key and booking token | Pending/accepted/declined/cancelled status |

The published machine-readable schema is
`https://evils.space/chatgpt-booking-openapi.json`. Only the first endpoint is
usable without a credential. The API does not return guest contact details in
booking-status responses. A booking token should be kept private.

## One-time credential setup

In the repository on your own computer, run:

```bash
git pull --ff-only origin main
bash tool/setup_chatgpt_booking.sh
```

The script uses your already signed-in GitHub CLI, generates a separate random
booking key, saves it to this repository's GitHub Actions secrets, and displays
it **once** for you to copy into your private ChatGPT action's authentication
settings. Do not paste it into a chat or commit it. This is **not** your
Cloudflare API token or an OpenAI API key. If you lose it, rerun the script to
rotate the key and update ChatGPT's settings.

Run `make` to trigger the existing production release. Its final step copies
the GitHub secret into the Cloudflare Worker's `ASSISTANT_BOOKING_KEY` secret.
Without that secret, booking and status return HTTP 503; public availability
continues working. Confirm the release succeeded in GitHub Actions. A GET to
`/api/assistant/availability` should return two local dates. An unauthenticated
POST to `/api/assistant/booking` should return 401 once configured. Do not
send production test bookings with invented contact details.

## Connect in ChatGPT

For a ChatGPT account/workspace that supports custom GPT Actions:

1. Create/edit a GPT and add an Action. Import the schema URL above, or paste
   the JSON from `docs/chatgpt-booking-openapi.json`.
2. Set action authentication to **API key, Bearer**, and paste the **assistant
   booking key** displayed by the setup script. Keep the GPT private while
   testing. Never put the key in the schema or the GPT's instructions.
3. Use these GPT instructions:

   > For Evil Space reservations, check live availability first. Use only a
   > date returned by the API, in Asia/Ho_Chi_Minh time. Before submitting,
   > show the guest the exact date, live VND price, name and contact you will
   > send to Evil Space; explain that staff must accept the request. Ask for
   > explicit agreement to submit. Set userConfirmed true only after that
   > agreement. Never invent a name, phone or Telegram handle. A 201 response
   > means pending, not confirmed. Check status using the returned token only
   > for the same guest. Reply in the guest's preferred English, Russian or
   > Vietnamese.
4. In the action preview, first ask “How many desks are free today at Evil
   Space?” Then use your **own** contact details for a single test request if
   you want to verify staff receipt and acceptance end to end.

The write operation is marked consequential in the OpenAPI schema, and the
Worker also requires `userConfirmed: true`. That boolean is a guard against
accidental calls, not proof of identity. The shared key authenticates the
configured GPT, not each customer. Keep this Action private for now; a widely
distributed ChatGPT plugin should use individual account authorization
(OAuth 2.1), a reviewed privacy policy, and its own MCP integration.

This integration does not make the API automatically available to every
ChatGPT conversation, and publishing a GPT or plugin requires separate steps
in ChatGPT. The existing public site and Google Search setup continue to work.
