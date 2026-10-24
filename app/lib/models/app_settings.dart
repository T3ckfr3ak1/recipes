import 'dart:convert';

import 'package:flutter/material.dart';

import '../db/recipe_store.dart';

enum RecipeSort { title, updated, category }

enum QuantityStyle { fraction, decimal }

final class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.textScale,
    required this.sort,
    required this.quantityStyle,
    required this.showDescription,
    required this.showNotes,
    required this.showAirFry,
    required this.printDescription,
    required this.printNotes,
    required this.printAirFry,
    required this.printImages,
    required this.syncOnLaunch,
    required this.timeoutSeconds,
  });

  static const defaults = AppSettings(
    themeMode: ThemeMode.dark,
    textScale: 1,
    sort: RecipeSort.title,
    quantityStyle: QuantityStyle.fraction,
    showDescription: true,
    showNotes: true,
    showAirFry: true,
    printDescription: true,
    printNotes: true,
    printAirFry: true,
    printImages: true,
    syncOnLaunch: true,
    timeoutSeconds: 20,
  );

  final ThemeMode themeMode;
  final double textScale;
  final RecipeSort sort;
  final QuantityStyle quantityStyle;
  final bool showDescription;
  final bool showNotes;
  final bool showAirFry;
  final bool printDescription;
  final bool printNotes;
  final bool printAirFry;
  final bool printImages;
  final bool syncOnLaunch;
  final int timeoutSeconds;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    RecipeSort? sort,
    QuantityStyle? quantityStyle,
    bool? showDescription,
    bool? showNotes,
    bool? showAirFry,
    bool? printDescription,
    bool? printNotes,
    bool? printAirFry,
    bool? printImages,
    bool? syncOnLaunch,
    int? timeoutSeconds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      sort: sort ?? this.sort,
      quantityStyle: quantityStyle ?? this.quantityStyle,
      showDescription: showDescription ?? this.showDescription,
      showNotes: showNotes ?? this.showNotes,
      showAirFry: showAirFry ?? this.showAirFry,
      printDescription: printDescription ?? this.printDescription,
      printNotes: printNotes ?? this.printNotes,
      printAirFry: printAirFry ?? this.printAirFry,
      printImages: printImages ?? this.printImages,
      syncOnLaunch: syncOnLaunch ?? this.syncOnLaunch,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  Map<String, Object?> toJson() => {
    'theme_mode': themeMode.name,
    'text_scale': textScale,
    'sort': sort.name,
    'quantity_style': quantityStyle.name,
    'show_description': showDescription,
    'show_notes': showNotes,
    'show_air_fry': showAirFry,
    'print_description': printDescription,
    'print_notes': printNotes,
    'print_air_fry': printAirFry,
    'print_images': printImages,
    'sync_on_launch': syncOnLaunch,
    'timeout_seconds': timeoutSeconds,
  };

  static AppSettings fromJson(Map<String, Object?> json) {
    return AppSettings(
      themeMode: _enum(ThemeMode.values, json['theme_mode'], ThemeMode.dark),
      textScale: _clampDouble(json['text_scale'], 1, 0.85, 1.4),
      sort: _enum(RecipeSort.values, json['sort'], RecipeSort.title),
      quantityStyle: _enum(
        QuantityStyle.values,
        json['quantity_style'],
        QuantityStyle.fraction,
      ),
      showDescription: _bool(json['show_description'], true),
      showNotes: _bool(json['show_notes'], true),
      showAirFry: _bool(json['show_air_fry'], true),
      printDescription: _bool(json['print_description'], true),
      printNotes: _bool(json['print_notes'], true),
      printAirFry: _bool(json['print_air_fry'], true),
      printImages: _bool(json['print_images'], true),
      syncOnLaunch: _bool(json['sync_on_launch'], true),
      timeoutSeconds: _clampInt(json['timeout_seconds'], 20, 5, 120),
    );
  }

  static Future<AppSettings> load(RecipeStore store) async {
    final raw = await store.getMeta(MetaKeys.settings);
    if (raw == null || raw.trim().isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return fromJson(decoded.map((key, value) => MapEntry('$key', value)));
      }
    } on FormatException {
      return defaults;
    }
    return defaults;
  }

  Future<void> save(RecipeStore store) {
    return store.setMeta(MetaKeys.settings, jsonEncode(toJson()));
  }
}

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

double _clampDouble(Object? value, double fallback, double min, double max) {
  final number = value is num ? value.toDouble() : fallback;
  return number.clamp(min, max).toDouble();
}

int _clampInt(Object? value, int fallback, int min, int max) {
  final number = value is num ? value.round() : fallback;
  return number.clamp(min, max);
}
