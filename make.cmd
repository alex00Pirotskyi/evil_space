@echo off
setlocal

if "%~1"=="" goto deploy
if /I "%~1"=="deploy" goto deploy
if /I "%~1"=="build" goto build
if /I "%~1"=="verify" goto verify
if /I "%~1"=="test" goto test

echo Unknown target: %~1
echo Use: make ^| make build ^| make verify ^| make test
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
