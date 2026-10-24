import '../models/index_document.dart';
import '../models/recipe.dart';
import 'repo_tree.dart';

abstract interface class RecipeRemote {
  Duration get timeout;

  set timeout(Duration value);

  Future<IndexDocument> fetchIndex({required DateTime now});

  Future<Recipe> fetchRecipe(IndexEntry entry);

  Future<List<int>> fetchBytes(String path);

  /// Recursive git tree for the recipe repo. Directories are omitted.
  Future<List<RepoBlob>> fetchTree();
}
