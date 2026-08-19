import 'dart:convert';

import 'package:flutter/services.dart';

enum DeskState {
  available,
  occupied,
  reserved,
  offline;

  static DeskState fromJson(String? value) {
    return switch (value?.toLowerCase()) {
      'available' => DeskState.available,
      'occupied' => DeskState.occupied,
      'reserved' => DeskState.reserved,
      'offline' => DeskState.offline,
      _ => DeskState.offline,
    };
  }
}

class DeskInfo {
  const DeskInfo({
    required this.id,
    required this.label,
    required this.zone,
    required this.state,
  });

  final String id;
  final String label;
  final String zone;
  final DeskState state;

  factory DeskInfo.fromJson(Map<String, dynamic> json) {
    return DeskInfo(
      id: json['id'] as String? ?? 'unknown',
      label: json['label'] as String? ?? 'DESK',
      zone: json['zone'] as String? ?? 'OPEN SPACE',
      state: DeskState.fromJson(json['state'] as String?),
    );
  }
}

class CoworkingStatus {
  const CoworkingStatus({
    required this.desks,
    required this.updatedLabel,
  });

  final List<DeskInfo> desks;
  final String updatedLabel;

  int get total => desks.length;

  int get available =>
      desks.where((desk) => desk.state == DeskState.available).length;

  DeskInfo? deskById(String? id) {
    if (id == null) {
      return null;
    }
    for (final desk in desks) {
      if (desk.id == id) {
        return desk;
      }
    }
    return null;
  }

  factory CoworkingStatus.fromJson(Map<String, dynamic> json) {
    final rawDesks = json['desks'] as List<dynamic>? ?? const [];
    final desks = rawDesks
        .whereType<Map<String, dynamic>>()
        .map(DeskInfo.fromJson)
        .toList(growable: false);

    return CoworkingStatus(
      desks: desks.isEmpty ? demo.desks : desks,
      updatedLabel: json['updated'] as String? ?? 'LOCAL',
    );
  }

  static const CoworkingStatus demo = CoworkingStatus(
    updatedLabel: 'DEMO',
    desks: [
      DeskInfo(
        id: 'd1',
        label: 'D1',
        zone: 'WINDOW',
        state: DeskState.available,
      ),
      DeskInfo(
        id: 'd2',
        label: 'D2',
        zone: 'WINDOW',
        state: DeskState.available,
      ),
      DeskInfo(
        id: 'd3',
        label: 'D3',
        zone: 'WINDOW',
        state: DeskState.occupied,
      ),
      DeskInfo(
        id: 'd4',
        label: 'D4',
        zone: 'WINDOW',
        state: DeskState.available,
      ),
      DeskInfo(
        id: 'd5',
        label: 'D5',
        zone: 'CENTER',
        state: DeskState.available,
      ),
      DeskInfo(
        id: 'd6',
        label: 'D6',
        zone: 'CENTER',
        state: DeskState.reserved,
      ),
      DeskInfo(
        id: 'd7',
        label: 'D7',
        zone: 'CENTER',
        state: DeskState.available,
      ),
      DeskInfo(
        id: 'd8',
        label: 'D8',
        zone: 'CENTER',
        state: DeskState.available,
      ),
      DeskInfo(
        id: 'd9',
        label: 'D9',
        zone: 'QUIET',
        state: DeskState.occupied,
      ),
      DeskInfo(
        id: 'd10',
        label: 'D10',
        zone: 'QUIET',
        state: DeskState.available,
      ),
    ],
  );
}

class CoworkingStatusRepository {
  CoworkingStatusRepository._();

  static Future<CoworkingStatus> load(
    AssetBundle bundle, {
    String assetPath = 'assets/content/status.json',
  }) async {
    try {
      final raw = await bundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CoworkingStatus.fromJson(decoded);
      }
    } catch (_) {
      // The local demo state keeps the website useful when the optional status
      // file is absent or temporarily malformed.
    }
    return CoworkingStatus.demo;
  }
}

class PricingOption {
  const PricingOption({
    required this.key,
    required this.priceVnd,
  });

  final String key;
  final int priceVnd;
}

class PricingResult {
  const PricingResult({
    required this.days,
    required this.options,
    required this.bestKey,
  });

  final int days;
  final List<PricingOption> options;
  final String bestKey;

  PricingOption get best => options.firstWhere((option) => option.key == bestKey);
}

class PricingCalculator {
  PricingCalculator._();

  static PricingResult forDays(int requestedDays) {
    final days = requestedDays.clamp(1, 30).toInt();
    final weeks = (days / 7).ceil();
    final options = <PricingOption>[
      PricingOption(key: 'desk_day', priceVnd: days * 250000),
      PricingOption(key: 'desk_week', priceVnd: weeks * 1000000),
      const PricingOption(key: 'desk_hot', priceVnd: 3200000),
      const PricingOption(key: 'desk_private', priceVnd: 3500000),
    ];

    PricingOption best = options.first;
    for (final option in options.skip(1)) {
      if (option.priceVnd < best.priceVnd) {
        best = option;
      }
    }

    return PricingResult(
      days: days,
      options: options,
      bestKey: best.key,
    );
  }

  static String compactVnd(int value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      final text = millions == millions.roundToDouble()
          ? millions.toStringAsFixed(0)
          : millions.toStringAsFixed(1);
      return '${text}M';
    }
    return '${(value / 1000).round()}K';
  }
}
