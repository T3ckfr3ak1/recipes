import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/db/recipe_store.dart';
import 'package:recipes/db/sqlite_recipe_store.dart';
import 'package:recipes/models/recipe.dart';
import 'package:recipes/models/recipe_origin.dart';
import 'package:recipes/models/repo_doc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/samples.dart';

void main() {
  group('memory', () {
    storeContract(() async => MemoryRecipeStore());
  });

  group('sqlite', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    storeContract(() async => SqliteRecipeStore.openMemory());
  });
}

void storeContract(Future<RecipeStore> Function() open) {
  test('round-trips keeper fields and protects flavorish rows', () async {
    final store = await open();
    final keeper = Recipe.fromKeeperJson('''
{
  "id": "soup",
  "title": "Tomato Soup",
  "description": "Smooth",
  "servings": 4,
  "prep_minutes": 10,
  "cook_minutes": 25,
  "ingredients": [
    {"quantity": "1/2", "unit": "cup", "item": "onion", "note": "diced"}
  ],
  "steps": ["Simmer"],
  "tags": ["comfort"],
  "category": "Soup",
  "source": "Recipe Keeper",
  "notes": "Blend it.",
  "air_fry": {"rack": "middle", "preheat": true, "temp_f": 390, "minutes": 12},
  "created_at": "2026-06-01T08:00:00-04:00",
  "updated_at": "2026-06-01T08:00:00-04:00",
  "deleted": false
}
''');
    expect(await store.upsertGithubRecipe(keeper), isTrue);
    final loaded = (await store.allRecipes()).single;
    expect(loaded.title, 'Tomato Soup');
    expect(loaded.updatedAtRaw, '2026-06-01T08:00:00-04:00');
    expect(loaded.airFry, isNotNull);
    expect(loaded.airFry!.tempF, 390);
    expect(loaded.airFry!.preheat, isTrue);
    expect(loaded.ingredients.single.quantity, '1/2');
    expect(loaded.ingredients.single.quantityValue, 0.5);
    expect(loaded.origin, RecipeOrigin.github);
    expect(loaded.source, 'Recipe Keeper');

    await store.insertLocalRecipe(
      sampleRecipe(
        id: 'flavorish:pie',
        title: 'Apple Pie',
        flavorishId: 'pie',
        origin: RecipeOrigin.local,
        source: 'Blog',
      ),
    );
    final local = (await store.allRecipes()).singleWhere(
      (recipe) => recipe.id == 'flavorish:pie',
    );
    expect(local.source, 'Flavorish');
    expect(local.origin, RecipeOrigin.local);

    await store.removeGithubRecipe('flavorish:pie');
    expect(
      (await store.allRecipes()).where(
        (recipe) => recipe.id == 'flavorish:pie',
      ),
      isNotEmpty,
    );

    expect(
      await store.upsertGithubRecipe(
        sampleRecipe(id: 'flavorish:pie', title: 'Replaced'),
      ),
      isFalse,
    );
    expect(
      (await store.allRecipes())
          .singleWhere((recipe) => recipe.id == 'flavorish:pie')
          .title,
      'Apple Pie',
    );

    await store.removeLocalRecipe('soup');
    expect(
      (await store.allRecipes()).where((recipe) => recipe.id == 'soup'),
      isNotEmpty,
    );
    await store.removeGithubRecipe('soup');
    expect(
      (await store.allRecipes()).where((recipe) => recipe.id == 'soup'),
      isEmpty,
    );
  });

  test('round-trips a repo note', () async {
    final store = await open();
    const doc = RepoDoc(
      path: 'equipment/skillet.md',
      sha: 'abc',
      kind: RepoKind.equipment,
      title: 'Skillet',
      body: '# Skillet\n',
    );
    await store.upsertDoc(doc);
    await store.upsertDoc(
      const RepoDoc(
        path: 'equipment/skillet.md',
        sha: 'def',
        kind: RepoKind.equipment,
        title: 'Cast iron skillet',
        body: '# Cast iron skillet\n',
      ),
    );
    expect((await store.allDocs()).single.title, 'Cast iron skillet');
    expect((await store.allDocs()).single.sha, 'def');
    await store.removeDoc(doc.path);
    expect(await store.allDocs(), isEmpty);
  });
}
