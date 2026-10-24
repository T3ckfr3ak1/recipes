import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/import/flavorish_export_mapper.dart';
import 'package:recipes/import/flavorish_importer.dart';
import 'package:recipes/models/recipe_origin.dart';
import 'package:recipes/time/instants.dart';

void main() {
  const mapper = FlavorishExportMapper();

  test('maps a Flavorish 2.0 recipe onto the local schema', () {
    final mapped = mapper.map(
      archivePath: 'recipes/chili.json',
      manifest: const {'version': '2.0'},
      json: {
        'imageFilename': 'chili.jpg',
        'collections': ['Weeknight', ' weeknight '],
        'recipe': {
          'id': 'chili-1',
          'title': 'Chili',
          'description': 'A bowl of chili',
          'servings': 6,
          'prep_time_hours': 1,
          'prep_time_minutes': 15,
          'cook_time_hours': null,
          'cook_time_minutes': 30,
          'category': ['Dinner', 'Soup'],
          'cuisine': ['Tex-Mex'],
          'keywords': ['spicy', 'Dinner'],
          'notes': 'Rest it.',
          'source_url': 'https://example.com/chili',
          'nutrition_calories': '280 kcal',
          'nutrition_protein_content': '20g',
          'nutrition_serving_size': '1 bowl',
          'created_at': '2026-08-30T22:25:53.772106+00:00',
          'updated_at': '2026-08-30T17:25:53.772106-05:00',
          'user_id': 'do-not-keep',
        },
        'ingredients': [
          {
            'sort_order': 2,
            'is_group_header': false,
            'quantity': 0.25,
            'unit_of_measure': 'cup',
            'description': 'hot sauce',
            'text': '0.25 cup hot sauce',
          },
          {
            'sort_order': 0,
            'is_group_header': true,
            'text': 'For the pot',
            'description': 'For the pot',
          },
          {
            'sort_order': 1,
            'is_group_header': false,
            'quantity': 2,
            'quantity2': 3,
            'unit_of_measure': 'pounds',
            'description': 'chuck roast',
            'text': '2 to 3 pounds of chuck roast',
          },
          {
            'sort_order': 3,
            'is_group_header': false,
            'quantity': null,
            'description': 'Salt, to taste',
            'text': 'Salt, to taste',
          },
        ],
        'instructions': [
          {'sort_order': 2, 'is_group_header': false, 'text': 'Simmer.'},
          {'sort_order': 1, 'is_group_header': true, 'text': 'Prepare the pot'},
        ],
      },
    );

    expect(mapped.flavorishId, 'chili-1');
    expect(mapped.title, 'Chili');
    expect(mapped.description, 'A bowl of chili');
    expect(mapped.servings, 6);
    expect(mapped.prepMinutes, 75);
    expect(mapped.cookMinutes, 30);
    expect(mapped.category, 'Dinner');
    expect(mapped.tags, [
      'Weeknight',
      'weeknight',
      'Soup',
      'Tex-Mex',
      'spicy',
      'Dinner',
    ]);
    expect(mapped.imageArchivePaths, ['images/chili.jpg']);
    expect(
      mapped.createdAt.isAtSameMomentAs(
        parseInstant('2026-08-30T22:25:53.772106Z'),
      ),
      isTrue,
    );
    expect(mapped.createdAt.isAtSameMomentAs(mapped.updatedAt), isTrue);
    expect(mapped.createdAtRaw, '2026-08-30T22:25:53.772106+00:00');
    expect(mapped.notes, contains('Rest it.'));
    expect(mapped.notes, contains('Source: https://example.com/chili'));
    expect(mapped.notes, contains('Calories 280 kcal'));
    expect(mapped.notes, contains('Protein 20g'));
    expect(mapped.notes, isNot(contains('do-not-keep')));

    expect(mapped.ingredients.map((item) => item.item), [
      'For the pot',
      'chuck roast',
      'hot sauce',
      'Salt, to taste',
    ]);
    expect(mapped.ingredients[0].quantity, isEmpty);
    expect(mapped.ingredients[1].quantity, '2-3');
    expect(mapped.ingredients[1].unit, 'pounds');
    expect(mapped.ingredients[1].quantityValue, isNull);
    expect(mapped.ingredients[2].quantity, '1/4');
    expect(mapped.ingredients[2].quantityValue, 0.25);
    expect(mapped.ingredients[2].unit, 'cup');
    expect(mapped.ingredients[3].quantity, isEmpty);
    expect(mapped.steps, ['Prepare the pot', 'Simmer.']);
  });

  test('rejects a recipe entry that is not the Flavorish shape', () {
    expect(
      () => mapper.map(
        archivePath: 'recipes/flat.json',
        json: const {'id': 'x', 'title': 'Soup'},
        manifest: null,
      ),
      throwsFormatException,
    );
  });

  test(
    'imports every recipe in a full export when FLAVORISH_ZIP is set',
    () async {
      final zipPath = Platform.environment['FLAVORISH_ZIP'];
      if (zipPath == null || zipPath.isEmpty) {
        fail('FLAVORISH_ZIP is not set');
      }
      final temp = await Directory.systemTemp.createTemp(
        'recipes_full_export_',
      );
      try {
        final store = MemoryRecipeStore();
        final importer = FlavorishImporter(
          store: store,
          supportDirectory: temp.path,
          mapper: mapper,
        );
        final result = await importer.importBytes(
          await File(zipPath).readAsBytes(),
        );
        expect(result.errors, isEmpty, reason: result.errors.join('\n'));
        expect(result.imported, greaterThan(0));
        final recipes = await store.allRecipes();
        expect(recipes, hasLength(result.imported));
        expect(
          recipes.map((recipe) => recipe.source),
          everyElement('Flavorish'),
        );
        expect(
          recipes.map((recipe) => recipe.origin),
          everyElement(RecipeOrigin.local),
        );
        expect(
          recipes.map((recipe) => recipe.flavorishId).toSet(),
          hasLength(recipes.length),
        );
        expect(
          recipes.where((recipe) => recipe.imagePaths.isNotEmpty),
          isNotEmpty,
        );
        final again = await importer.importBytes(
          await File(zipPath).readAsBytes(),
        );
        expect(again.imported, 0);
        expect(again.skipped, recipes.length);
      } finally {
        if (await temp.exists()) await temp.delete(recursive: true);
      }
    },
    skip: (Platform.environment['FLAVORISH_ZIP'] ?? '').isEmpty
        ? 'Set FLAVORISH_ZIP to a flavorish-recipes.zip to run this check.'
        : false,
  );
}
