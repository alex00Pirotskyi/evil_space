.DEFAULT_GOAL := deploy

.PHONY: deploy build verify test

deploy:
	dart run tool/release.dart

build:
	dart run tool/release.dart --build-only

verify:
	dart run tool/release.dart --verify-only

test:
	flutter pub get
	flutter test --no-pub
