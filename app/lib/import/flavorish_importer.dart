import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../db/recipe_store.dart';
import '../models/recipe.dart';
import '../models/recipe_origin.dart';
import '../storage/safe_path.dart';
import '../sync/github_publisher.dart';
import '../sync/index_merge.dart';
import 'flavorish_mapper.dart';

final class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.warnings,
    required this.errors,
    this.published = 0,
  });

  final int imported;
  final int skipped;
  final int published;
  final List<String> warnings;
  final List<String> errors;

  String get summary {
    final lines = <String>[
      'Imported $imported.',
      if (published > 0) 'Published $published to the recipe repo.',
      if (skipped > 0) 'Skipped $skipped already imported.',
      ...warnings,
      ...errors,
    ];
    return lines.join('\n');
  }
}

final class FlavorishImporter {
  FlavorishImporter({
    required this.store,
    required this.supportDirectory,
    required this.mapper,
    this.publisher,
  });

  final RecipeStore store;
  final String supportDirectory;
  final FlavorishMapper mapper;
  final RecipePublisher? publisher;

  Future<ImportResult> importBytes(List<int> bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw FlavorishImportException(
        'That file is not a readable zip archive.',
      );
    }
    final layout = FlavorishArchiveLayout.parse(archive);
    final manifest = _manifest(layout);
    final warnings = <String>[];
    final errors = <String>[];
    var imported = 0;
    var skipped = 0;

    for (final entry in layout.recipeFiles) {
      final Map<String, Object?> json;
      try {
        json = _decodeRecipe(entry.value.content, entry.key);
      } on FormatException catch (error) {
        errors.add('${entry.key}: ${error.message}');
        continue;
      }

      final MappedFlavorishRecipe mapped;
      try {
        mapped = mapper.map(
          archivePath: entry.key,
          json: json,
          manifest: manifest,
        );
      } on FlavorishMappingException {
        rethrow;
      } catch (error) {
        errors.add('${entry.key}: $error');
        continue;
      }

      final flavorishId = mapped.flavorishId.trim();
      if (flavorishId.isEmpty) {
        errors.add('${entry.key}: the Flavorish id is missing.');
        continue;
      }
      final title = mapped.title.trim();
      if (title.isEmpty) {
        errors.add('${entry.key}: the title is missing.');
        continue;
      }
      if (await store.hasFlavorishId(flavorishId)) {
        skipped++;
        continue;
      }

      final images = await _copyImages(
        flavorishId: flavorishId,
        title: title,
        requested: mapped.imageArchivePaths,
        layout: layout,
        warnings: warnings,
      );
      try {
        await store.insertLocalRecipe(
          Recipe(
            id: localIdForFlavorish(flavorishId),
            title: title,
            description: mapped.description,
            servings: mapped.servings,
            prepMinutes: mapped.prepMinutes,
            cookMinutes: mapped.cookMinutes,
            ingredients: mapped.ingredients,
            steps: mapped.steps,
            tags: cleanTags(mapped.tags),
            category: mapped.category.trim(),
            source: flavorishSource,
            notes: mapped.notes,
            airFry: mapped.airFry,
            createdAt: mapped.createdAt,
            updatedAt: mapped.updatedAt,
            createdAtRaw: mapped.createdAtRaw,
            updatedAtRaw: mapped.updatedAtRaw,
            origin: RecipeOrigin.local,
            flavorishId: flavorishId,
            imagePaths: images,
          ),
        );
        imported++;
      } catch (error) {
        errors.add('$title: $error');
      }
    }

    var published = 0;
    if (publisher != null) {
      try {
        published = await publishPending();
      } catch (error) {
        errors.add('$error');
      }
    }

    return ImportResult(
      imported: imported,
      skipped: skipped,
      warnings: warnings,
      errors: errors,
      published: published,
    );
  }

  /// Publishes local Flavorish recipes that are not on the repo yet.
  Future<int> publishPending() async {
    final publisher = this.publisher;
    if (publisher == null) return 0;
    final pending = [
      for (final recipe in await store.allRecipes())
        if (recipe.origin == RecipeOrigin.local) recipe,
    ];
    if (pending.isEmpty) return 0;
    await publisher.publish(pending, supportDirectory: supportDirectory);
    for (final recipe in pending) {
      final repoId = repoIdFor(id: recipe.id, flavorishId: recipe.flavorishId);
      await store.removeLocalRecipe(recipe.id);
      final saved = await store.upsertGithubRecipe(
        recipe.copyWith(id: repoId, flavorishId: recipe.flavorishId ?? repoId),
      );
      if (!saved) {
        throw StateError(
          'Published recipe $repoId could not be saved locally.',
        );
      }
    }
    return pending.length;
  }

  Map<String, Object?>? _manifest(FlavorishArchiveLayout layout) {
    final file = layout.files['${layout.prefix}manifest.json'];
    if (file == null || !file.isFile) return null;
    try {
      final decoded = jsonDecode(_text(file.content));
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<List<String>> _copyImages({
    required String flavorishId,
    required String title,
    required List<String> requested,
    required FlavorishArchiveLayout layout,
    required List<String> warnings,
  }) async {
    final written = <String>[];
    final usedNames = <String>{};
    final folder = folderForFlavorish(flavorishId);
    for (final request in requested) {
      final bytes = layout.bytesForImage(request);
      if (bytes == null) {
        warnings.add('$title: missing image $request.');
        continue;
      }
      final storedName = _uniqueName(request, usedNames);
      final relative = p
          .join('images', folder, storedName)
          .replaceAll('\\', '/');
      final file = fileInside(supportDirectory, relative);
      if (file == null) {
        warnings.add('$title: skipped an unsafe image path.');
        continue;
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      written.add(relative);
    }
    return written;
  }
}

String localIdForFlavorish(String flavorishId) => 'flavorish:$flavorishId';

String folderForFlavorish(String flavorishId) {
  final readable = flavorishId.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final prefix = readable.isEmpty
      ? 'recipe'
      : readable.substring(0, readable.length < 24 ? readable.length : 24);
  return '${prefix}_${_fnv(flavorishId).toRadixString(16)}';
}

List<String> cleanTags(List<String> tags) {
  final seen = <String>{};
  final result = <String>[];
  for (final tag in tags) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) continue;
    if (seen.add(trimmed.toLowerCase())) result.add(trimmed);
  }
  return result;
}

int _fnv(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _uniqueName(String request, Set<String> usedNames) {
  var name = p.basename(normalizeZipPath(request));
  name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  if (name.isEmpty || name == '.' || name == '..') name = 'image';
  var candidate = name;
  var suffix = 2;
  while (!usedNames.add(candidate.toLowerCase())) {
    final extension = p.extension(name);
    final stem = p.basenameWithoutExtension(name);
    candidate = '$stem-$suffix$extension';
    suffix++;
  }
  return candidate;
}

Map<String, Object?> _decodeRecipe(Uint8List bytes, String path) {
  final Object? decoded;
  try {
    decoded = jsonDecode(_text(bytes));
  } on FormatException catch (error) {
    throw FormatException('$path is not valid JSON. ${error.message}');
  }
  if (decoded is! Map) {
    throw FormatException('$path is not a recipe object');
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

String _text(Uint8List bytes) {
  var text = utf8.decode(bytes);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text;
}

String normalizeZipPath(String name) {
  var value = name.replaceAll('\\', '/');
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  return value;
}

final class FlavorishArchiveLayout {
  FlavorishArchiveLayout({required this.prefix, required this.files});

  final String prefix;
  final Map<String, ArchiveFile> files;

  String get recipesPrefix => '${prefix}recipes/';

  String get imagesPrefix => '${prefix}images/';

  List<MapEntry<String, ArchiveFile>> get recipeFiles {
    final entries = files.entries.where((entry) {
      if (!entry.value.isFile) return false;
      final name = entry.key;
      if (!name.startsWith(recipesPrefix)) return false;
      if (!name.toLowerCase().endsWith('.json')) return false;
      final rest = name.substring(recipesPrefix.length);
      return rest.isNotEmpty && !rest.contains('/');
    }).toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  Uint8List? bytesForImage(String requested) {
    final normal = normalizeZipPath(requested);
    if (normal.isEmpty || normal.contains('..') || normal.contains(':')) {
      return null;
    }
    final candidates = <String>[
      if (normal.startsWith(imagesPrefix)) normal,
      if (!normal.startsWith(imagesPrefix)) '$imagesPrefix$normal',
    ];
    for (final candidate in candidates) {
      if (!candidate.startsWith(imagesPrefix) || candidate.contains('..')) {
        continue;
      }
      final file = files[candidate];
      if (file != null && file.isFile) return file.content;
    }
    return null;
  }

  static FlavorishArchiveLayout parse(Archive archive) {
    final files = <String, ArchiveFile>{};
    for (final file in archive.files) {
      final name = normalizeZipPath(file.name);
      if (name.isEmpty || _ignored(name)) continue;
      files[name] = file;
    }
    final manifests =
        files.keys
            .where(
              (name) =>
                  name == 'manifest.json' || name.endsWith('/manifest.json'),
            )
            .toList()
          ..sort((a, b) => a.length.compareTo(b.length));
    if (manifests.isEmpty) {
      throw FlavorishImportException('The zip needs a manifest.json.');
    }

    String prefixFor(String manifest) {
      if (manifest == 'manifest.json') return '';
      return manifest.substring(0, manifest.length - 'manifest.json'.length);
    }

    String? prefix;
    for (final manifest in manifests) {
      final candidate = prefixFor(manifest);
      if (_hasRecipes(files, candidate)) {
        prefix = candidate;
        break;
      }
    }
    if (prefix == null) {
      throw FlavorishImportException('The zip needs a recipes folder.');
    }
    return FlavorishArchiveLayout(prefix: prefix, files: files);
  }
}

bool _hasRecipes(Map<String, ArchiveFile> files, String prefix) {
  final folder = '${prefix}recipes';
  return files.keys.any(
    (name) => name == folder || name.startsWith('$folder/'),
  );
}

bool _ignored(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('__macosx/') ||
      lower.contains('/__macosx/') ||
      lower.endsWith('.ds_store');
}
