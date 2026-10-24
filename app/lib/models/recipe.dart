import 'dart:convert';

import '../time/instants.dart';
import 'air_fry.dart';
import 'ingredient.dart';
import 'recipe_origin.dart';

final class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.description = '',
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
    this.category = '',
    this.source = '',
    this.notes = '',
    this.airFry,
    required this.createdAt,
    required this.updatedAt,
    this.createdAtRaw,
    this.updatedAtRaw,
    this.deleted = false,
    this.origin = RecipeOrigin.github,
    this.flavorishId,
    this.imagePaths = const [],
    this.repoImages = const [],
  });

  final String id;
  final String title;
  final String description;
  final double? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final String category;
  final String source;
  final String notes;
  final AirFry? airFry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdAtRaw;
  final String? updatedAtRaw;
  final bool deleted;
  final RecipeOrigin origin;
  final String? flavorishId;
  final List<String> imagePaths;

  /// Repo-relative photo paths from a recipe file. Not stored in SQLite.
  final List<String> repoImages;

  String get createdAtStored =>
      createdAtRaw ?? createdAt.toUtc().toIso8601String();

  String get updatedAtStored =>
      updatedAtRaw ?? updatedAt.toUtc().toIso8601String();

  bool get isReadOnly => origin == RecipeOrigin.github;

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    double? servings,
    int? prepMinutes,
    int? cookMinutes,
    List<Ingredient>? ingredients,
    List<String>? steps,
    List<String>? tags,
    String? category,
    String? source,
    String? notes,
    AirFry? airFry,
    bool clearAirFry = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdAtRaw,
    String? updatedAtRaw,
    bool? deleted,
    RecipeOrigin? origin,
    String? flavorishId,
    bool clearFlavorishId = false,
    List<String>? imagePaths,
    List<String>? repoImages,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      servings: servings ?? this.servings,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      airFry: clearAirFry ? null : (airFry ?? this.airFry),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAtRaw: createdAtRaw ?? this.createdAtRaw,
      updatedAtRaw: updatedAtRaw ?? this.updatedAtRaw,
      deleted: deleted ?? this.deleted,
      origin: origin ?? this.origin,
      flavorishId: clearFlavorishId ? null : (flavorishId ?? this.flavorishId),
      imagePaths: imagePaths ?? this.imagePaths,
      repoImages: repoImages ?? this.repoImages,
    );
  }

  static Recipe fromKeeperJson(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw FormatException('Recipe file is not valid JSON. ${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('Recipe file must be an object');
    }
    return fromKeeperMap(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  static Recipe fromKeeperMap(Map<String, Object?> map) {
    final id = _requiredText(map['id'], 'id');
    final title = _requiredText(map['title'], 'title');
    final createdRaw = _requiredText(map['created_at'], 'created_at');
    final updatedRaw = _requiredText(map['updated_at'], 'updated_at');
    return Recipe(
      id: id,
      title: title,
      description: _optionalText(map['description'], 'description'),
      servings: _optionalDouble(map['servings'], 'servings'),
      prepMinutes: _optionalInt(map['prep_minutes'], 'prep_minutes'),
      cookMinutes: _optionalInt(map['cook_minutes'], 'cook_minutes'),
      ingredients: _ingredients(map['ingredients']),
      steps: _stringList(map['steps'], 'steps'),
      tags: _stringList(map['tags'], 'tags'),
      category: _optionalText(map['category'], 'category'),
      source: _optionalText(map['source'], 'source'),
      notes: _optionalText(map['notes'], 'notes'),
      airFry: AirFry.fromJson(map['air_fry']),
      createdAt: parseInstant(createdRaw, field: 'created_at'),
      updatedAt: parseInstant(updatedRaw, field: 'updated_at'),
      createdAtRaw: createdRaw,
      updatedAtRaw: updatedRaw,
      deleted: _bool(map['deleted'], 'deleted'),
      origin: RecipeOrigin.github,
      repoImages: _stringList(map['images'], 'images'),
    );
  }

  /// Recipe Keeper file. Omits empty optional fields so a new file matches
  /// the repo's existing recipes.
  Map<String, Object?> toKeeperMap() {
    return {
      'id': id,
      'title': title,
      if (description.isNotEmpty) 'description': description,
      if (servings != null) 'servings': _jsonNumber(servings!),
      if (prepMinutes != null) 'prep_minutes': prepMinutes,
      if (cookMinutes != null) 'cook_minutes': cookMinutes,
      'ingredients': [
        for (final ingredient in ingredients)
          {
            'quantity': ingredient.quantity,
            'unit': ingredient.unit,
            'item': ingredient.item,
            if (ingredient.note != null && ingredient.note!.trim().isNotEmpty)
              'note': ingredient.note!.trim(),
          },
      ],
      'steps': steps,
      'tags': tags,
      if (category.isNotEmpty) 'category': category,
      if (source.isNotEmpty) 'source': source,
      if (notes.isNotEmpty) 'notes': notes,
      if (airFry != null) 'air_fry': airFry!.toJson(),
      'created_at': createdAtStored,
      'updated_at': updatedAtStored,
      'deleted': deleted,
      if (repoImages.isNotEmpty) 'images': repoImages,
    };
  }

  String toKeeperJson() {
    return '${const JsonEncoder.withIndent('  ').convert(toKeeperMap())}\n';
  }

  Map<String, Object?> toStorageMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'servings': servings,
      'prep_minutes': prepMinutes,
      'cook_minutes': cookMinutes,
      'ingredients_json': jsonEncode(
        ingredients.map((ingredient) => ingredient.toJson()).toList(),
      ),
      'steps_json': jsonEncode(steps),
      'tags_json': jsonEncode(tags),
      'category': category,
      'source': source,
      'notes': notes,
      'air_fry_json': airFry == null ? null : jsonEncode(airFry!.toJson()),
      'created_at': createdAtStored,
      'updated_at': updatedAtStored,
      'deleted': deleted ? 1 : 0,
      'origin': origin.name,
      'flavorish_id': flavorishId,
      'images_json': jsonEncode(imagePaths),
    };
  }

  static Recipe fromStorageMap(Map<String, Object?> row) {
    final createdRaw = row['created_at'] as String? ?? '';
    final updatedRaw = row['updated_at'] as String? ?? '';
    return Recipe(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      servings: (row['servings'] as num?)?.toDouble(),
      prepMinutes: (row['prep_minutes'] as num?)?.toInt(),
      cookMinutes: (row['cook_minutes'] as num?)?.toInt(),
      ingredients: _decodeIngredients(row['ingredients_json'] as String?),
      steps: _decodeStringList(row['steps_json'] as String?),
      tags: _decodeStringList(row['tags_json'] as String?),
      category: row['category'] as String? ?? '',
      source: row['source'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      airFry: _decodeAirFry(row['air_fry_json'] as String?),
      createdAt: parseInstant(createdRaw, field: 'created_at'),
      updatedAt: parseInstant(updatedRaw, field: 'updated_at'),
      createdAtRaw: createdRaw,
      updatedAtRaw: updatedRaw,
      deleted: (row['deleted'] as num?)?.toInt() == 1,
      origin: RecipeOrigin.parse(row['origin'] as String? ?? 'github'),
      flavorishId: row['flavorish_id'] as String?,
      imagePaths: _decodeStringList(row['images_json'] as String?),
    );
  }
}

List<Ingredient> _ingredients(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('ingredients must be a list');
  }
  return [
    for (var i = 0; i < value.length; i++)
      Ingredient.fromKeeperJson(value[i], index: i),
  ];
}

List<String> _stringList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List) throw FormatException('$field must be a list');
  return [
    for (var i = 0; i < value.length; i++)
      if (value[i] is String)
        (value[i] as String).trim()
      else
        throw FormatException('$field[$i] must be text'),
  ].where((item) => item.isNotEmpty).toList();
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be text');
  }
  return value.trim();
}

String _optionalText(Object? value, String field) {
  if (value == null) return '';
  if (value is! String) throw FormatException('$field must be text');
  return value;
}

double? _optionalDouble(Object? value, String field) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('$field must be a number');
}

int? _optionalInt(Object? value, String field) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  if (value is String && RegExp(r'^\d+$').hasMatch(value.trim())) {
    return int.parse(value.trim());
  }
  throw FormatException('$field must be a whole number');
}

Object _jsonNumber(double value) {
  if (value == value.roundToDouble()) return value.round();
  return value;
}

bool _bool(Object? value, String field) {
  if (value == null) return false;
  if (value is bool) return value;
  throw FormatException('$field must be true or false');
}

List<Ingredient> _decodeIngredients(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is Map)
        Ingredient.fromStorage(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
  ];
}

List<String> _decodeStringList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is String) item,
  ];
}

AirFry? _decodeAirFry(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  return AirFry.fromStorage(decoded);
}
