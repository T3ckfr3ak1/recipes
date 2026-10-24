import '../models/app_settings.dart';
import '../models/recipe.dart';
import '../models/recipe_mark.dart';

const mealFilters = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Snack',
  'Dessert',
  'Appetizer',
  'Side',
];

const _mealWords = {
  'Breakfast': ['breakfast'],
  'Lunch': ['lunch'],
  'Dinner': ['dinner', 'main course', 'main dish', 'main'],
  'Snack': ['snack', 'snacks'],
  'Dessert': ['dessert', 'desserts'],
  'Appetizer': ['appetizer', 'appetizers'],
  'Side': ['side dish', 'side'],
};

final class RecipeQuery {
  const RecipeQuery({
    this.text = '',
    this.category,
    this.tag,
    this.sort = RecipeSort.title,
    this.madeOnly = false,
    this.starredOnly = false,
    this.meal,
    this.marks = const {},
  });

  final String text;
  final String? category;
  final String? tag;
  final RecipeSort sort;
  final bool madeOnly;
  final bool starredOnly;
  final String? meal;
  final Map<String, RecipeMark> marks;
}

List<Recipe> applyQuery(List<Recipe> recipes, RecipeQuery query) {
  final needle = query.text.trim().toLowerCase();
  final category = query.category?.trim().toLowerCase();
  final tag = query.tag?.trim().toLowerCase();
  final matched = recipes.where((recipe) {
    if (recipe.deleted) return false;
    if (category != null &&
        category.isNotEmpty &&
        recipe.category.trim().toLowerCase() != category) {
      return false;
    }
    if (tag != null &&
        tag.isNotEmpty &&
        !recipe.tags.any((item) => item.trim().toLowerCase() == tag)) {
      return false;
    }
    if (query.madeOnly && query.marks[recipe.id]?.made != true) return false;
    if (query.starredOnly && query.marks[recipe.id]?.starred != true) {
      return false;
    }
    final meal = query.meal?.trim();
    if (meal != null && meal.isNotEmpty && !recipeMatchesMeal(recipe, meal)) {
      return false;
    }
    if (needle.isEmpty) return true;
    if (recipe.title.toLowerCase().contains(needle)) return true;
    if (recipe.tags.any((item) => item.toLowerCase().contains(needle))) {
      return true;
    }
    return recipe.ingredients.any((ingredient) {
      return ingredient.item.toLowerCase().contains(needle) ||
          (ingredient.note ?? '').toLowerCase().contains(needle);
    });
  }).toList();

  matched.sort((a, b) => _compare(a, b, query.sort));
  return matched;
}

int _compare(Recipe a, Recipe b, RecipeSort sort) {
  switch (sort) {
    case RecipeSort.title:
      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
    case RecipeSort.updated:
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      if (byTime != 0) return byTime;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    case RecipeSort.category:
      final byCategory = a.category.toLowerCase().compareTo(
        b.category.toLowerCase(),
      );
      if (byCategory != 0) return byCategory;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}

bool recipeMatchesMeal(Recipe recipe, String meal) {
  final words = _wordsForMeal(meal);
  if (words.isEmpty) return false;
  if (words.any((word) => _hasPhrase(recipe.category, word))) return true;
  return recipe.tags.any((tag) => words.any((word) => _hasPhrase(tag, word)));
}

List<String> mealsOn(Recipe recipe) {
  return [
    for (final meal in mealFilters)
      if (recipeMatchesMeal(recipe, meal)) meal,
  ];
}

List<String> _wordsForMeal(String meal) {
  for (final entry in _mealWords.entries) {
    if (entry.key.toLowerCase() == meal.trim().toLowerCase()) {
      return entry.value;
    }
  }
  final trimmed = meal.trim().toLowerCase();
  if (trimmed.isEmpty) return const [];
  return [trimmed];
}

bool _hasPhrase(String value, String phrase) {
  return RegExp(
    '\\b${RegExp.escape(phrase)}\\b',
    caseSensitive: false,
  ).hasMatch(value);
}

List<String> distinctCategories(List<Recipe> recipes) {
  return _distinct(recipes.map((recipe) => recipe.category));
}

List<String> distinctTags(List<Recipe> recipes) {
  return _distinct(recipes.expand((recipe) => recipe.tags));
}

/// Tags that show up on many recipes. One-off tags stay on the recipe
/// and out of the filter list.
List<String> commonTags(List<Recipe> recipes, {int minimum = 8}) {
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final recipe in recipes) {
    if (recipe.deleted) continue;
    final seen = <String>{};
    for (final tag in recipe.tags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      labels.putIfAbsent(key, () => trimmed);
    }
  }
  final list = [
    for (final entry in counts.entries)
      if (entry.value >= minimum) labels[entry.key]!,
  ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

List<String> _distinct(Iterable<String> values) {
  final seen = <String, String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    seen.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
  }
  final list = seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}
