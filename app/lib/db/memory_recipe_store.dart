import '../models/recipe.dart';
import '../models/recipe_origin.dart';
import '../models/repo_doc.dart';
import 'recipe_store.dart';

final class MemoryRecipeStore implements RecipeStore {
  final Map<String, String> _meta = {};
  final List<Recipe> _recipes = [];
  final Map<String, RepoDoc> _docs = {};

  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      _meta.remove(key);
    } else {
      _meta[key] = value;
    }
  }

  @override
  Future<List<Recipe>> allRecipes() async {
    return _recipes.where((recipe) => !recipe.deleted).toList();
  }

  @override
  Future<bool> upsertGithubRecipe(Recipe recipe) async {
    final index = _indexOf(recipe.id);
    if (index >= 0 && _recipes[index].origin != RecipeOrigin.github) {
      return false;
    }
    Recipe? twin;
    for (final item in _recipes) {
      if (item.origin == RecipeOrigin.local &&
          item.flavorishId == recipe.id &&
          item.id != recipe.id) {
        twin = item;
        break;
      }
    }
    final keepFlavorish =
        recipe.flavorishId ??
        (index >= 0 ? _recipes[index].flavorishId : null) ??
        twin?.flavorishId;
    final images = recipe.imagePaths.isNotEmpty
        ? recipe.imagePaths
        : (index >= 0 && _recipes[index].imagePaths.isNotEmpty
              ? _recipes[index].imagePaths
              : twin?.imagePaths ?? const <String>[]);
    if (twin != null) {
      _recipes.removeWhere((item) => item.id == twin!.id);
    }
    final stored = recipe.copyWith(
      origin: RecipeOrigin.github,
      flavorishId: keepFlavorish,
      clearFlavorishId: keepFlavorish == null || keepFlavorish.isEmpty,
      deleted: false,
      imagePaths: images,
    );
    final slot = _indexOf(recipe.id);
    if (slot >= 0) {
      _recipes[slot] = stored;
    } else {
      _recipes.add(stored);
    }
    return true;
  }

  @override
  Future<void> removeGithubRecipe(String id) async {
    _recipes.removeWhere(
      (recipe) => recipe.id == id && recipe.origin == RecipeOrigin.github,
    );
  }

  @override
  Future<bool> hasFlavorishId(String flavorishId) async {
    return _recipes.any(
      (recipe) =>
          recipe.flavorishId == flavorishId ||
          recipe.id == flavorishId ||
          recipe.id == 'flavorish:$flavorishId',
    );
  }

  @override
  Future<void> insertLocalRecipe(Recipe recipe) async {
    final flavorishId = recipe.flavorishId;
    if (flavorishId == null || flavorishId.isEmpty) {
      throw ArgumentError('A Flavorish import needs a Flavorish id.');
    }
    if (_indexOf(recipe.id) >= 0) {
      throw StateError('A recipe with id ${recipe.id} is already stored.');
    }
    if (await hasFlavorishId(flavorishId)) {
      throw StateError('Flavorish recipe $flavorishId was already imported.');
    }
    _recipes.add(
      recipe.copyWith(
        source: 'Flavorish',
        origin: RecipeOrigin.local,
        flavorishId: flavorishId,
        deleted: false,
      ),
    );
  }

  @override
  Future<void> removeLocalRecipe(String id) async {
    _recipes.removeWhere(
      (recipe) => recipe.id == id && recipe.origin == RecipeOrigin.local,
    );
  }

  @override
  Future<List<RepoDoc>> allDocs() async => _docs.values.toList();

  @override
  Future<void> upsertDoc(RepoDoc doc) async {
    _docs[doc.path] = doc;
  }

  @override
  Future<void> removeDoc(String path) async {
    _docs.remove(path);
  }

  int _indexOf(String id) {
    return _recipes.indexWhere((recipe) => recipe.id == id);
  }
}
