@echo off
setlocal

if "%~1"=="" goto deploy
if /I "%~1"=="deploy" goto deploy
if /I "%~1"=="debug" goto debug
if /I "%~1"=="debug-local" goto debug_local
if /I "%~1"=="debug-build" goto debug_build
if /I "%~1"=="build" goto build
if /I "%~1"=="verify" goto verify
if /I "%~1"=="test" goto test
if /I "%~1"=="telegram-setup" goto telegram_setup

echo Unknown target: %~1
echo Use: make ^| make debug ^| make debug-local ^| make debug-build ^| make build ^| make verify ^| make test ^| make telegram-setup
exit /b 2

:deploy
dart run tool/release.dart
exit /b %errorlevel%

:debug
gh workflow run debug.yml --ref main --repo alex00Pirotskyi/evil_space
exit /b %errorlevel%

:debug_local
dart run tool/debug.dart
exit /b %errorlevel%

:debug_build
dart run tool/debug.dart --build-only
exit /b %errorlevel%

:build
dart run tool/release.dart --build-only
exit /b %errorlevel%

:verify
dart run tool/release.dart --verify-only
exit /b %errorlevel%

:test
flutter pub get
if errorlevel 1 exit /b %errorlevel%
flutter test --no-pub
if errorlevel 1 exit /b %errorlevel%
node --check worker/telegram.js
if errorlevel 1 exit /b %errorlevel%
node --test worker/telegram_test.mjs
exit /b %errorlevel%

:telegram_setup
dart run tool/telegram_setup.dart
exit /b %errorlevel%
