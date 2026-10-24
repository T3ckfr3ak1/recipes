import '../models/recipe.dart';
import '../models/repo_doc.dart';

abstract final class MetaKeys {
  static const lastPullAt = 'last_pull_at';
  static const lastSyncError = 'last_sync_error';
  static const settings = 'settings';
  static const mealPlan = 'meal_plan';
  static const marks = 'recipe_marks';
  static const madeSeed = 'made_seed_ids';
}

abstract interface class RecipeStore {
  Future<String?> getMeta(String key);

  Future<void> setMeta(String key, String? value);

  Future<List<Recipe>> allRecipes();

  /// Inserts or replaces a Recipe Keeper recipe.
  ///
  /// Returns false when [recipe.id] already belongs to a local import.
  /// The local row is left unchanged.
  Future<bool> upsertGithubRecipe(Recipe recipe);

  /// Deletes a Recipe Keeper row. Local imports with the same id stay.
  Future<void> removeGithubRecipe(String id);

  Future<bool> hasFlavorishId(String flavorishId);

  Future<void> insertLocalRecipe(Recipe recipe);

  Future<void> removeLocalRecipe(String id);

  Future<List<RepoDoc>> allDocs();

  Future<void> upsertDoc(RepoDoc doc);

  Future<void> removeDoc(String path);
}
