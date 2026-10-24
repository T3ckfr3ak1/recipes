import '../models/air_fry.dart';
import '../models/ingredient.dart';

const flavorishSource = 'Flavorish';

final class MappedFlavorishRecipe {
  const MappedFlavorishRecipe({
    required this.flavorishId,
    required this.title,
    this.description = '',
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
    this.category = '',
    this.notes = '',
    this.airFry,
    required this.createdAt,
    required this.updatedAt,
    required this.createdAtRaw,
    required this.updatedAtRaw,
    this.imageArchivePaths = const [],
  });

  final String flavorishId;
  final String title;
  final String description;
  final double? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final List<Ingredient> ingredients;
  final List<String> steps;

  /// Collections from the export belong here as tags.
  final List<String> tags;
  final String category;
  final String notes;
  final AirFry? airFry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdAtRaw;
  final String updatedAtRaw;
  final List<String> imageArchivePaths;
}

abstract interface class FlavorishMapper {
  MappedFlavorishRecipe map({
    required String archivePath,
    required Map<String, Object?> json,
    required Map<String, Object?>? manifest,
  });
}

class FlavorishImportException implements Exception {
  FlavorishImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FlavorishMappingException extends FlavorishImportException {
  FlavorishMappingException(super.message);
}
