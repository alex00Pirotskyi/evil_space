@echo off
setlocal

if "%~1"=="" goto deploy
if /I "%~1"=="deploy" goto deploy
if /I "%~1"=="build" goto build
if /I "%~1"=="verify" goto verify
if /I "%~1"=="test" goto test
if /I "%~1"=="telegram-setup" goto telegram_setup

echo Unknown target: %~1
echo Use: make ^| make build ^| make verify ^| make test ^| make telegram-setup
exit /b 2

:deploy
dart run tool/release.dart
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
exit /b %errorlevel%

:telegram_setup
dart run tool/telegram_setup.dart
exit /b %errorlevel%
