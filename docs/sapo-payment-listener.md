# Sapo S6 Max — Evil Space Payment Listener (Flutter Android)

A **dedicated Flutter entrypoint in the existing repository**:
lib/payment_listener_main.dart. Its background notification listener is
implemented in native Android Kotlin. Production web builds continue using
lib/main.dart and are not changed.

## Purpose

The official Vietcombank VCB Digibank Android app (package com.VCB) displays
incoming transfer notifications. Android NotificationListenerService reads
them after you enable notification access. Only notifications containing an
incoming amount, the receiving account, timestamp, and an EVIL order reference
are queued. HTTPS uploads to Cloudflare Worker match the pending order using
the existing payment processor. The web checkout polls its payment status.

Notifications are not bank-attested proof. Missed pushes or Android battery
limits may cause missed confirmations. Keep manual payment verification.

## One-time Cloudflare setup

Generate a random shared secret (never commit it):

    python -c "import secrets; print(secrets.token_urlsafe(48))"

Add that value as a Cloudflare Worker secret:

    npx wrangler secret put VCB_DEVICE_HMAC_SECRET

Set the SAME secret on the Sapo payment listener screen. Confirm your existing
VIETQR_ACCOUNT_NUMBER matches the VCB receiving account. Deploy the new Worker
using your standard release process. Until deployed and configured, the
endpoint returns 503 or 404. No new D1 migration is required.

## One-time Wi-Fi ADB setup

Workstation: Flutter 3.47+, Android SDK/ADB, Android build toolchain, GNU Make.

For Android 11+: Sapo Settings > Developer options > Wireless debugging >
Pair device using pairing code. On the PC:

    adb pair SAPO_IP:PAIRING_PORT
    adb connect SAPO_IP:DEBUG_PORT
    adb devices

Pairing and debugging ports are DIFFERENT. The debug port may change after a
restart. Wireless debugging requires Android 11+ and local network access.

For Android 10 or older, use USB for first pairing, then:

    adb devices
    adb tcpip 5555
    adb connect SAPO_IP:5555

Once ADB is authorized, from the repository root:

    make android SAPO_IP=192.168.1.40:37523

Or use make android if exactly one authorized ADB device is already connected.
Build without installing:

    make android-build

APK path: build/app/outputs/flutter-apk/app-release.apk.

The command installs an APK. It does NOT flash firmware, erase Android, or use
fastboot. Android package id: space.evils.paymentlistener. Current Flutter
template signs release builds with its debug key. Configure a stable private
release signing key before production distribution.

## Sapo first run

1. Open Evil Space Payments and grant notification access.
2. Paste VCB_DEVICE_HMAC_SECRET into the app and save.
3. Test server: should display "Cloudflare connection verified".
4. Check Sapo battery/background settings for both VCB and the listener.
5. Enable VCB incoming transfer OTT notifications.
6. Pay a small genuine checkout QR with the exact EVIL reference.
7. Confirm the app reports matched and the web checkout becomes paid.
8. Retest after locking the device, disconnecting/reconnecting Wi-Fi and reboot.

The app never reads or stores VCB credentials or banking sessions. The locally
queued events contain only amount, transfer reference, receiving account and
time, without the account balance. Device secret is encrypted with Android
Keystore AES-GCM. JobScheduler uploads events and retries after network errors.

Unmatched orders, wrong amounts, missing refs and cancelled orders remain
unpaid. It is essential to maintain manual fallback for missing bank alerts.

Troubleshooting: HTTP 503 = backend secret missing; HTTP 401 = wrong secret or
clock; HTTP 404 = Worker not deployed. If payment notifications are ignored,
check package name com.VCB and the text format. Reconnect ADB over Wi-Fi
before make android whenever the Sapo changes its debug port.
