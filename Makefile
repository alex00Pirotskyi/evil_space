.DEFAULT_GOAL := deploy

.PHONY: deploy build verify test telegram-setup

deploy:
	dart run tool/release.dart

build:
	dart run tool/release.dart --build-only

verify:
	dart run tool/release.dart --verify-only

test:
	flutter pub get
	flutter test --no-pub
	node --check worker/index.js
	node --check worker/entry.js
	node --check worker/app.js
	node --check worker/admin_worker.js
	node --check worker/admin_review.js
	node --check worker/secure_entry.js
	node --check worker/security.js
	node --check worker/telegram.js
	node --check worker/menu.js
	node --check worker/menu_i18n.js
	node --check worker/menu_cart.js
	node --check worker/menu_telegram.js
	node --check worker/customer_account.js
	node --check worker/google_account.js
	node --check worker/vietqr.js
	node --check worker/booking_rules.js
	node --check worker/pricing.js
	node --check worker/integration_test.mjs
	node --check worker/menu_i18n_test.mjs
	node --check worker/menu_cart_test.mjs
	node --check worker/customer_account_test.mjs
	node --check worker/google_account_test.mjs
	node --check worker/vietqr_test.mjs
	node --test worker/security_test.mjs worker/telegram_test.mjs worker/booking_rules_test.mjs worker/pricing_test.mjs worker/menu_i18n_test.mjs worker/menu_cart_test.mjs worker/customer_account_test.mjs worker/google_account_test.mjs worker/vietqr_test.mjs
	node worker/integration_test.mjs

telegram-setup:
	dart run tool/telegram_setup.dart
