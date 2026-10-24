import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/config/repo_config.dart';
import 'package:recipes/sync/sync_exception.dart';

void main() {
  test('index url cache-busts and recipe urls do not', () {
    final now = DateTime.utc(2026, 10, 23, 15, 4, 5);
    final index = RepoConfig.indexUri(now);
    expect(
      index.toString(),
      'https://raw.githubusercontent.com/T3ckfr3ak1/recipes/main/index.json?t=${now.millisecondsSinceEpoch}',
    );
    expect(index.queryParameters.keys, ['t']);

    final recipe = RepoConfig.recipeUri('recipes/a b.json');
    expect(recipe.query, isEmpty);
    expect(
      recipe.toString(),
      'https://raw.githubusercontent.com/T3ckfr3ak1/recipes/main/recipes/a%20b.json',
    );
  });

  test('recipe paths cannot leave the repo', () {
    expect(
      () => RepoConfig.recipeUri('../secret.json'),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => RepoConfig.recipeUri('https://example.com/x.json'),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => RepoConfig.recipeUri('/recipes/x.json'),
      throwsA(isA<SyncException>()),
    );
  });

  test('the tree listing is one recursive call', () {
    final tree = RepoConfig.treeUri();
    expect(
      tree.toString(),
      'https://api.github.com/repos/T3ckfr3ak1/recipes/git/trees/main?recursive=1',
    );
  });
}
