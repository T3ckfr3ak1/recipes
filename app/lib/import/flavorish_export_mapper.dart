import '../logic/quantities.dart';
import '../models/ingredient.dart';
import '../time/instants.dart';
import 'flavorish_mapper.dart';

/// Maps a Flavorish 2.0 export recipe (`manifest.json` version 2.0).
///
/// Each zip entry looks like `{ recipe, ingredients, instructions, collections, imageFilename }`.
/// Collections, extra categories, cuisines, and keywords become tags.
final class FlavorishExportMapper implements FlavorishMapper {
  const FlavorishExportMapper();

  @override
  MappedFlavorishRecipe map({
    required String archivePath,
    required Map<String, Object?> json,
    required Map<String, Object?>? manifest,
  }) {
    final recipe = _object(json['recipe']);
    if (recipe == null) {
      throw FormatException('$archivePath is not a Flavorish recipe');
    }
    final id = _text(recipe['id']);
    final title = _text(recipe['title']);
    if (id.isEmpty || title.isEmpty) {
      throw FormatException('$archivePath is missing a Flavorish id or title');
    }
    final createdRaw = _text(recipe['created_at']);
    final updatedRaw = _text(recipe['updated_at']).isEmpty
        ? createdRaw
        : _text(recipe['updated_at']);
    if (createdRaw.isEmpty) {
      throw FormatException('$archivePath is missing created_at');
    }

    final categories = _strings(recipe['category']);
    final ingredients = _objects(json['ingredients'])
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    final steps = _objects(json['instructions'])
      ..sort((a, b) => _order(a).compareTo(_order(b)));

    return MappedFlavorishRecipe(
      flavorishId: id,
      title: title,
      description: _text(recipe['description']),
      servings: _number(recipe['servings']),
      prepMinutes: _minutes(
        recipe['prep_time_hours'],
        recipe['prep_time_minutes'],
      ),
      cookMinutes: _minutes(
        recipe['cook_time_hours'],
        recipe['cook_time_minutes'],
      ),
      ingredients: [for (final item in ingredients) _ingredient(item)],
      steps: [
        for (final step in steps)
          if (_text(step['text']).isNotEmpty) _text(step['text']),
      ],
      tags: [
        ..._strings(json['collections']),
        if (categories.length > 1) ...categories.skip(1),
        ..._strings(recipe['cuisine']),
        ..._strings(recipe['keywords']),
      ],
      category: categories.isEmpty ? '' : categories.first,
      notes: _notes(recipe),
      createdAt: parseInstant(createdRaw, field: 'created_at'),
      updatedAt: parseInstant(updatedRaw, field: 'updated_at'),
      createdAtRaw: createdRaw,
      updatedAtRaw: updatedRaw,
      imageArchivePaths: [?_imagePath(json['imageFilename'])],
    );
  }
}

Ingredient _ingredient(Map<String, Object?> item) {
  if (item['is_group_header'] == true) {
    final label = _text(item['text']).isEmpty
        ? _text(item['description'])
        : _text(item['text']);
    return Ingredient(quantity: '', unit: '', item: label);
  }
  final quantity = _number(item['quantity']);
  final quantityEnd = _number(item['quantity2']);
  final name = _text(item['description']).isEmpty
      ? _text(item['text'])
      : _text(item['description']);
  return Ingredient(
    quantity: _quantityText(quantity, quantityEnd),
    unit: _text(item['unit_of_measure']),
    item: name,
    quantityValue: quantityEnd == null ? quantity : null,
  );
}

String _quantityText(double? start, double? end) {
  if (start == null) return '';
  if (end == null) return formatQuantity(start);
  return '${formatQuantity(start)}-${formatQuantity(end)}';
}

String _notes(Map<String, Object?> recipe) {
  final notes = _text(recipe['notes']);
  final sourceUrl = _text(recipe['source_url']);
  final nutrition = _nutrition(recipe);
  return [
    if (notes.isNotEmpty) notes,
    if (sourceUrl.isNotEmpty && !notes.contains(sourceUrl))
      'Source: $sourceUrl',
    if (nutrition.isNotEmpty) nutrition,
  ].join('\n\n');
}

String _nutrition(Map<String, Object?> recipe) {
  const fields = {
    'nutrition_serving_size': 'Serving',
    'nutrition_calories': 'Calories',
    'nutrition_fat_content': 'Fat',
    'nutrition_saturated_fat_content': 'Saturated fat',
    'nutrition_unsaturated_fat_content': 'Unsaturated fat',
    'nutrition_trans_fat_content': 'Trans fat',
    'nutrition_cholesterol_content': 'Cholesterol',
    'nutrition_sodium_content': 'Sodium',
    'nutrition_carbohydrate_content': 'Carbs',
    'nutrition_fiber_content': 'Fiber',
    'nutrition_sugar_content': 'Sugar',
    'nutrition_protein_content': 'Protein',
  };
  final parts = [
    for (final entry in fields.entries)
      if (_text(recipe[entry.key]).isNotEmpty)
        '${entry.value} ${_text(recipe[entry.key])}',
  ];
  if (parts.isEmpty) return '';
  return 'Nutrition: ${parts.join(' · ')}';
}

int? _minutes(Object? hours, Object? minutes) {
  if (hours == null && minutes == null) return null;
  final hourValue = _number(hours) ?? 0;
  final minuteValue = _number(minutes) ?? 0;
  return hourValue.round() * 60 + minuteValue.round();
}

String? _imagePath(Object? filename) {
  if (filename is! String) return null;
  final name = filename.trim();
  if (name.isEmpty ||
      name.contains('/') ||
      name.contains('\\') ||
      name.contains('..')) {
    return null;
  }
  return 'images/$name';
}

Map<String, Object?>? _object(Object? value) {
  if (value is! Map) return null;
  return value.map((key, entry) => MapEntry(key.toString(), entry));
}

List<Map<String, Object?>> _objects(Object? value) {
  if (value is! List) return [];
  return [for (final item in value) ?_object(item)];
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

String _text(Object? value) {
  if (value is! String) return '';
  return value.trim();
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int _order(Map<String, Object?> item) =>
    _number(item['sort_order'])?.round() ?? 0;
