import 'package:flutter/widgets.dart';

import 'package:evil_space/language_preference.dart';
import 'package:evil_space/localization.dart';

class PersistentLocalizationController extends LocalizationController {
  PersistentLocalizationController._(
    AppLanguage language,
    this._hasSavedLanguage,
  ) : super(language);

  factory PersistentLocalizationController.fromPlatform() {
    final saved = readSavedLanguage();
    if (saved != null) {
      for (final language in AppLanguage.values) {
        if (language.code == saved) {
          return PersistentLocalizationController._(language, true);
        }
      }
    }

    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return PersistentLocalizationController._(
      AppLanguage.fromLocale(locale),
      false,
    );
  }

  bool _hasSavedLanguage;

  bool get hasSavedLanguage => _hasSavedLanguage;

  @override
  void setLanguage(AppLanguage language) {
    final firstChoice = !_hasSavedLanguage;
    _hasSavedLanguage = true;
    saveLanguage(language.code);

    if (this.language == language) {
      if (firstChoice) notifyListeners();
      return;
    }

    super.setLanguage(language);
  }
}
