import 'package:recipes/models/ingredient.dart';
import 'package:recipes/models/recipe.dart';
import 'package:recipes/models/recipe_origin.dart';
import 'package:recipes/time/instants.dart';

Recipe sampleRecipe({
  required String id,
  String title = 'Soup',
  String updatedAt = '2026-01-01T00:00:00Z',
  String? createdAt,
  bool deleted = false,
  RecipeOrigin origin = RecipeOrigin.github,
  String? flavorishId,
  String source = 'Keeper',
  String category = 'Dinner',
  double? servings = 4,
  List<Ingredient> ingredients = const [],
  List<String> steps = const ['Simmer.'],
  List<String> tags = const ['weeknight'],
  String notes = '',
  String description = '',
}) {
  final created = createdAt ?? updatedAt;
  return Recipe(
    id: id,
    title: title,
    description: description,
    servings: servings,
    ingredients: ingredients,
    steps: steps,
    tags: tags,
    category: category,
    source: source,
    notes: notes,
    createdAt: parseInstant(created),
    updatedAt: parseInstant(updatedAt),
    createdAtRaw: created,
    updatedAtRaw: updatedAt,
    deleted: deleted,
    origin: origin,
    flavorishId: flavorishId,
  );
}

const kale = Ingredient(
  quantity: '1',
  unit: 'cup',
  item: 'kale',
  quantityValue: 1,
);
