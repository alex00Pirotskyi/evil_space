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
	node --check worker/telegram.js
	node --test worker/telegram_test.mjs

telegram-setup:
	dart run tool/telegram_setup.dart
