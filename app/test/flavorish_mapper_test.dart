import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/import/flavorish_export_mapper.dart';
import 'package:recipes/import/flavorish_importer.dart';
import 'package:recipes/import/flavorish_mapper.dart';
import 'package:recipes/models/recipe.dart';
import 'package:recipes/sync/github_publisher.dart';
import 'package:recipes/models/recipe_origin.dart';
import 'package:recipes/sync/sync_service.dart';
import 'package:recipes/time/instants.dart';

import 'support/fake_remote.dart';
import 'support/samples.dart';

void main() {
  late Directory temp;
  late MemoryRecipeStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('recipes_flavorish_');
    store = MemoryRecipeStore();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('import copies images, tags collections, and skips known ids', () async {
    final importer = FlavorishImporter(
      store: store,
      supportDirectory: temp.path,
      mapper: const _FixtureMapper(),
    );
    final bytes = _zip(
      {
        'manifest.json': '{"version":1}',
        'recipes/abc.json': jsonEncode({
          'id': 'abc',
          'title': 'Chili',
          'collections': ['Weeknight', ' weeknight ', ''],
          'images': ['images/chili.jpg', '../secret.txt'],
          'blog': 'not the source',
        }),
        'images/chili.jpg': null,
        'secret.txt': 'nope',
      },
      binary: {
        'images/chili.jpg': [9, 8, 7, 6],
      },
    );

    final first = await importer.importBytes(bytes);
    expect(first.imported, 1);
    expect(first.skipped, 0);
    expect(first.warnings.single, contains('missing image'));

    final recipe = (await store.allRecipes()).single;
    expect(recipe.id, 'flavorish:abc');
    expect(recipe.flavorishId, 'abc');
    expect(recipe.source, 'Flavorish');
    expect(recipe.origin, RecipeOrigin.local);
    expect(recipe.tags, ['Weeknight']);
    expect(recipe.imagePaths, hasLength(1));
    final image = File('${temp.path}/${recipe.imagePaths.single}');
    expect(await image.readAsBytes(), [9, 8, 7, 6]);
    expect(await File('${temp.path}/secret.txt').exists(), isFalse);
    expect(
      temp
          .listSync(recursive: true)
          .where((entity) => entity.path.contains('secret')),
      isEmpty,
    );

    final second = await importer.importBytes(bytes);
    expect(second.imported, 0);
    expect(second.skipped, 1);
    expect(await store.allRecipes(), hasLength(1));
  });

  test('github sync does not delete an imported flavorish recipe', () async {
    final importer = FlavorishImporter(
      store: store,
      supportDirectory: temp.path,
      mapper: const _FixtureMapper(),
    );
    await importer.importBytes(
      _zip({
        'manifest.json': '{}',
        'recipes/abc.json': jsonEncode({
          'id': 'abc',
          'title': 'Chili',
          'collections': ['Weeknight'],
        }),
      }),
    );
    final remote = FakeRemote(
      index: sampleIndex('2026-10-01T00:00:00Z', [
        sampleEntry(
          id: 'flavorish:abc',
          updatedAt: '2026-10-01T00:00:00Z',
          deleted: true,
        ),
        sampleEntry(
          id: 'abc',
          updatedAt: '2026-10-01T00:00:00Z',
          deleted: true,
        ),
      ]),
      byPath: {
        'recipes/flavorish:abc.json': sampleRecipe(
          id: 'flavorish:abc',
          deleted: true,
          updatedAt: '2026-10-01T00:00:00Z',
        ),
        'recipes/abc.json': sampleRecipe(
          id: 'abc',
          deleted: true,
          updatedAt: '2026-10-01T00:00:00Z',
        ),
      },
    );

    final result = await SyncService(store: store, remote: remote).sync();

    expect(result.advanced, isTrue);
    expect((await store.allRecipes()).single.title, 'Chili');
    expect((await store.allRecipes()).single.source, 'Flavorish');
  });

  test('a zip without the flavorish container is rejected', () async {
    final importer = FlavorishImporter(
      store: store,
      supportDirectory: temp.path,
      mapper: const _FixtureMapper(),
    );
    expect(
      () => importer.importBytes(_zip({'readme.txt': 'hi'})),
      throwsA(
        isA<FlavorishImportException>().having(
          (error) => error.message,
          'message',
          contains('manifest.json'),
        ),
      ),
    );
    expect(
      () => importer.importBytes(_zip({'manifest.json': '{}'})),
      throwsA(
        isA<FlavorishImportException>().having(
          (error) => error.message,
          'message',
          contains('recipes'),
        ),
      ),
    );
  });

  test('import publishes a flavorish recipe under its flavorish id', () async {
    final publisher = _RecordingPublisher();
    final importer = FlavorishImporter(
      store: store,
      supportDirectory: temp.path,
      mapper: const FlavorishExportMapper(),
      publisher: publisher,
    );
    final result = await importer.importBytes(
      _zip({
        'manifest.json': '{"version":"2.0"}',
        'recipes/good.json': jsonEncode(_flavorishRecipe()),
      }),
    );
    expect(result.errors, isEmpty);
    expect(result.published, 1);
    expect(publisher.ids, ['good']);
    final recipe = (await store.allRecipes()).single;
    expect(recipe.id, 'good');
    expect(recipe.origin, RecipeOrigin.github);
    expect(recipe.flavorishId, 'good');
    expect(recipe.source, 'Flavorish');
    expect(await store.hasFlavorishId('good'), isTrue);
  });

  test('a file that is not a Flavorish recipe is skipped', () async {
    final importer = FlavorishImporter(
      store: store,
      supportDirectory: temp.path,
      mapper: const FlavorishExportMapper(),
    );
    final result = await importer.importBytes(
      _zip(
        {
          'manifest.json': '{"version":"2.0"}',
          'recipes/bad.json': '{"id":"bad","title":"Nope"}',
          'recipes/good.json': jsonEncode(_flavorishRecipe()),
        },
        binary: {
          'images/good.jpg': [1, 2, 3],
        },
      ),
    );
    expect(result.imported, 1);
    expect(result.errors.single, contains('bad.json'));
    expect((await store.allRecipes()).single.title, 'Chili');
  });
}

final class _RecordingPublisher implements RecipePublisher {
  final List<String> ids = [];

  @override
  Future<void> publish(
    List<Recipe> recipes, {
    required String supportDirectory,
  }) async {
    ids.addAll(recipes.map((recipe) => recipe.flavorishId ?? recipe.id));
  }
}

final class _FixtureMapper implements FlavorishMapper {
  const _FixtureMapper();

  @override
  MappedFlavorishRecipe map({
    required String archivePath,
    required Map<String, Object?> json,
    required Map<String, Object?>? manifest,
  }) {
    const stamp = '2026-03-01T12:00:00Z';
    final collections = json['collections'];
    final images = json['images'];
    return MappedFlavorishRecipe(
      flavorishId: json['id']! as String,
      title: json['title']! as String,
      tags: [
        if (collections is List)
          for (final item in collections) '$item',
      ],
      imageArchivePaths: [
        if (images is List)
          for (final item in images) '$item',
      ],
      createdAt: parseInstant(stamp),
      updatedAt: parseInstant(stamp),
      createdAtRaw: stamp,
      updatedAtRaw: stamp,
    );
  }
}

Map<String, Object?> _flavorishRecipe() {
  return {
    'imageFilename': 'good.jpg',
    'collections': ['Weeknight'],
    'recipe': {
      'id': 'good',
      'title': 'Chili',
      'description': 'Spicy',
      'servings': 4,
      'prep_time_minutes': 10,
      'cook_time_minutes': 30,
      'category': ['Dinner'],
      'created_at': '2026-03-01T12:00:00Z',
      'updated_at': '2026-03-01T12:00:00Z',
    },
    'ingredients': [
      {
        'sort_order': 1,
        'text': '1 cup beans',
        'description': 'beans',
        'quantity': 1,
        'unit_of_measure': 'cup',
        'is_group_header': false,
      },
    ],
    'instructions': [
      {'sort_order': 1, 'text': 'Simmer.', 'is_group_header': false},
    ],
  };
}

List<int> _zip(
  Map<String, String?> files, {
  Map<String, List<int>> binary = const {},
}) {
  final archive = Archive();
  files.forEach((name, content) {
    if (content == null) return;
    archive.addFile(ArchiveFile.string(name, content));
  });
  binary.forEach((name, content) {
    archive.addFile(ArchiveFile.bytes(name, content));
  });
  return ZipEncoder().encode(archive);
}
