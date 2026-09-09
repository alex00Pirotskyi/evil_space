// ignore_for_file: depend_on_referenced_packages

import 'package:web/web.dart' as web;

const _storageKey = 'evil_space_language_v1';

String? readSavedLanguage() {
  try {
    return web.window.localStorage.getItem(_storageKey);
  } catch (_) {
    return null;
  }
}

void saveLanguage(String code) {
  try {
    web.window.localStorage.setItem(_storageKey, code);
  } catch (_) {}
}
