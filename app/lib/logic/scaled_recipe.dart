import '../models/app_settings.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import 'quantities.dart';

final class ScaledIngredient {
  const ScaledIngredient({
    required this.quantity,
    required this.unit,
    required this.item,
    required this.note,
    required this.scaled,
  });

  final String quantity;
  final String unit;
  final String item;
  final String? note;
  final bool scaled;

  String get line {
    final amount = [
      quantity,
      unit,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    if (amount.isEmpty) return item;
    return '$amount $item';
  }
}

final class ScaledRecipe {
  const ScaledRecipe({
    required this.recipe,
    required this.targetServings,
    required this.factor,
    required this.ingredients,
  });

  final Recipe recipe;
  final double? targetServings;
  final double factor;
  final List<ScaledIngredient> ingredients;

  bool get leftSomeUnscaled =>
      factor != 1 && ingredients.any((ingredient) => !ingredient.scaled);

  bool get isScaled => (factor - 1).abs() > 0.000001;
}

ScaledRecipe scaleRecipe(
  Recipe recipe,
  double? targetServings,
  QuantityStyle style,
) {
  final base = recipe.servings;
  final factor = base == null || base == 0 || targetServings == null
      ? 1.0
      : targetServings / base;
  return ScaledRecipe(
    recipe: recipe,
    targetServings: targetServings,
    factor: factor,
    ingredients: [
      for (final ingredient in recipe.ingredients)
        _scaleIngredient(ingredient, factor, style),
    ],
  );
}

ScaledIngredient _scaleIngredient(
  Ingredient ingredient,
  double factor,
  QuantityStyle style,
) {
  final numeric = ingredient.quantityValue;
  final unchanged = numeric == null || (factor - 1).abs() < 0.000001;
  if (unchanged) {
    return ScaledIngredient(
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      item: ingredient.item,
      note: ingredient.note,
      scaled: numeric != null || ingredient.quantity.trim().isEmpty,
    );
  }
  final scaled = numeric * factor;
  final text = style == QuantityStyle.decimal
      ? formatDecimalQuantity(scaled)
      : formatQuantity(scaled);
  return ScaledIngredient(
    quantity: text,
    unit: ingredient.unit,
    item: ingredient.item,
    note: ingredient.note,
    scaled: true,
  );
}

String ingredientLine(ScaledIngredient ingredient) => ingredient.line;
