import '../models/recipe.dart';

/// Recipes already cooked, so the Made filter includes them.
bool isHomeCooked(Recipe recipe) {
  final title = recipe.title.toLowerCase().replaceAll('’', "'");
  if (title.contains('not-spaghetti') || title.contains('not spaghetti')) {
    return true;
  }
  if (title.contains('pulled pork') && title.contains('joe')) return true;
  final blob = '$title ${recipe.description}'.toLowerCase().replaceAll(
    '’',
    "'",
  );
  if (blob.contains('croissant taco') || blob.contains('pizza roll')) {
    return true;
  }
  return false;
}
