import 'dart:convert';

import 'package:flutter/services.dart';

class SiteStatus {
  const SiteStatus({
    required this.total,
    required this.occupied,
    required this.updated,
  });

  final int total;
  final int occupied;
  final String updated;

  int get free => (total - occupied).clamp(0, total).toInt();

  factory SiteStatus.fromJson(Map<String, dynamic> json) {
    final rawTotal = (json['total'] as num?)?.toInt() ?? 10;
    final normalizedTotal = rawTotal.clamp(1, 999).toInt();
    final rawOccupied = (json['occupied'] as num?)?.toInt() ?? 3;

    return SiteStatus(
      total: normalizedTotal,
      occupied: rawOccupied.clamp(0, normalizedTotal).toInt(),
      updated: json['updated'] as String? ?? 'LOCAL',
    );
  }
}

class SitePrice {
  const SitePrice({required this.labelKey, required this.price});

  final String labelKey;
  final String price;

  factory SitePrice.fromJson(Map<String, dynamic> json) {
    return SitePrice(
      labelKey: json['label_key'] as String? ?? 'price_item',
      price: json['price'] as String? ?? '-',
    );
  }
}

class SiteAnnouncement {
  const SiteAnnouncement({required this.date, required this.textByLanguage});

  final String date;
  final Map<String, String> textByLanguage;

  String textFor(String languageCode) {
    return textByLanguage[languageCode] ?? textByLanguage['en'] ?? '';
  }

  factory SiteAnnouncement.fromJson(Map<String, dynamic> json) {
    final rawText = json['text'];
    final text = <String, String>{};
    if (rawText is Map<String, dynamic>) {
      for (final entry in rawText.entries) {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          text[entry.key] = value.trim();
        }
      }
    }

    return SiteAnnouncement(
      date: json['date'] as String? ?? '',
      textByLanguage: text,
    );
  }
}

class SiteOpening {
  const SiteOpening({
    required this.labelKey,
    required this.openingDate,
    required this.isOpen,
  });

  final String labelKey;
  final String openingDate;
  final bool isOpen;

  factory SiteOpening.fromJson(Map<String, dynamic> json) {
    return SiteOpening(
      labelKey: json['label_key'] as String? ?? 'opening_space',
      openingDate: json['opening_date'] as String? ?? '2026-10-20',
      isOpen: json['is_open'] as bool? ?? false,
    );
  }
}

class SiteContent {
  const SiteContent({
    required this.status,
    required this.prices,
    required this.announcements,
    required this.openings,
  });

  final SiteStatus status;
  final List<SitePrice> prices;
  final List<SiteAnnouncement> announcements;
  final List<SiteOpening> openings;

  factory SiteContent.fromJson(Map<String, dynamic> json) {
    final statusJson = json['status'];
    final rawPrices = json['prices'];
    final rawAnnouncements = json['announcements'];
    final rawOpenings = json['openings'];

    final prices = rawPrices is List
        ? rawPrices
              .whereType<Map<String, dynamic>>()
              .map(SitePrice.fromJson)
              .toList(growable: false)
        : const <SitePrice>[];
    final announcements = rawAnnouncements is List
        ? rawAnnouncements
              .whereType<Map<String, dynamic>>()
              .map(SiteAnnouncement.fromJson)
              .where((item) => item.textByLanguage.isNotEmpty)
              .toList(growable: false)
        : const <SiteAnnouncement>[];
    final openings = rawOpenings is List
        ? rawOpenings
              .whereType<Map<String, dynamic>>()
              .map(SiteOpening.fromJson)
              .toList(growable: false)
        : const <SiteOpening>[];

    return SiteContent(
      status: statusJson is Map<String, dynamic>
          ? SiteStatus.fromJson(statusJson)
          : demo.status,
      prices: prices.isEmpty ? demo.prices : prices,
      announcements: announcements.isEmpty ? demo.announcements : announcements,
      openings: openings.isEmpty ? demo.openings : openings,
    );
  }

  static const SiteContent demo = SiteContent(
    status: SiteStatus(total: 10, occupied: 3, updated: 'DEMO'),
    prices: [
      SitePrice(labelKey: 'price_day_pass', price: '250K VND'),
      SitePrice(labelKey: 'price_month', price: '2.5 MLN VND'),
    ],
    announcements: [
      SiteAnnouncement(
        date: '20 AUG',
        textByLanguage: {
          'en': 'WELCOME TO EVIL SPACE',
          'ru': 'ДОБРО ПОЖАЛОВАТЬ В EVIL SPACE',
          'vi': 'CHÀO MỪNG ĐẾN EVIL SPACE',
        },
      ),
    ],
    openings: [
      SiteOpening(
        labelKey: 'opening_studio',
        openingDate: '2026-10-20',
        isOpen: false,
      ),
      SiteOpening(
        labelKey: 'opening_lecture',
        openingDate: '2026-10-20',
        isOpen: false,
      ),
    ],
  );
}

class SiteContentRepository {
  SiteContentRepository._();

  static Future<SiteContent> load(
    AssetBundle bundle, {
    String assetPath = 'assets/content/status.json',
  }) async {
    try {
      final raw = await bundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SiteContent.fromJson(decoded);
      }
    } catch (_) {
      // The public page must remain usable if local status data is unavailable.
    }
    return SiteContent.demo;
  }
}
