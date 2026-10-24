import 'package:path/path.dart' as p;

import '../db/recipe_store.dart';
import '../models/index_document.dart';
import '../models/recipe.dart';
import '../storage/safe_path.dart';
import '../time/instants.dart';
import 'recipe_remote.dart';
import 'sync_exception.dart';
import 'sync_result.dart';

final class SyncService {
  SyncService({
    required this.store,
    required this.remote,
    this.supportDirectory,
  });

  final RecipeStore store;
  final RecipeRemote remote;
  final String? supportDirectory;

  /// Downloads index.json, then recipes newer than the saved cursor.
  ///
  /// A recipe that is not stored locally is downloaded even when its
  /// updated_at is older than the cursor, so a newly published backfill
  /// still arrives. The cursor stays put when any recipe download or parse
  /// fails. An empty cursor pulls every index entry. Times are compared as
  /// instants.
  Future<SyncResult> sync({DateTime? now}) async {
    final clock = now ?? DateTime.now().toUtc();
    final previousCursor = await store.getMeta(MetaKeys.lastPullAt);
    try {
      final index = await remote.fetchIndex(now: clock);
      final cursor = _cursor(previousCursor);
      final storedIds = {
        for (final recipe in await store.allRecipes()) recipe.id,
      };
      final changed = [
        for (final entry in index.recipes)
          if (isNewerThanCursor(entry.updatedAt, cursor) ||
              (!entry.deleted && !storedIds.contains(entry.id)))
            entry,
      ];
      final errors = <String>[];
      var upserted = 0;
      var removed = 0;
      for (final entry in changed) {
        try {
          final outcome = await _apply(entry);
          upserted += outcome.upserted;
          removed += outcome.removed;
          if (outcome.error != null) errors.add(outcome.error!);
        } catch (error) {
          errors.add('${entry.id}: ${describeSyncError(error)}');
        }
      }
      if (errors.isNotEmpty) {
        final message = errors.join('\n');
        await store.setMeta(MetaKeys.lastSyncError, message);
        return SyncResult(
          advanced: false,
          lastPullAtRaw: previousCursor,
          upserted: upserted,
          removed: removed,
          fetched: changed.length,
          errors: errors,
        );
      }
      await store.setMeta(MetaKeys.lastPullAt, index.generatedAtRaw);
      await store.setMeta(MetaKeys.lastSyncError, null);
      return SyncResult(
        advanced: true,
        lastPullAtRaw: index.generatedAtRaw,
        upserted: upserted,
        removed: removed,
        fetched: changed.length,
        errors: const [],
      );
    } catch (error) {
      final message = describeSyncError(error);
      await store.setMeta(MetaKeys.lastSyncError, message);
      return SyncResult(
        advanced: false,
        lastPullAtRaw: previousCursor,
        upserted: 0,
        removed: 0,
        fetched: 0,
        errors: [message],
      );
    }
  }

  DateTime? _cursor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return parseInstant(raw, field: 'last_pull_at');
    } on FormatException {
      // An unreadable cursor would stall forever. Pull the library again.
      return null;
    }
  }

  Future<({int upserted, int removed, String? error})> _apply(
    IndexEntry entry,
  ) async {
    final recipe = await remote.fetchRecipe(entry);
    if (entry.deleted || recipe.deleted) {
      await store.removeGithubRecipe(entry.id);
      if (recipe.id != entry.id) {
        await store.removeGithubRecipe(recipe.id);
      }
      return (upserted: 0, removed: 1, error: null);
    }
    if (recipe.id != entry.id) {
      return (
        upserted: 0,
        removed: 0,
        error:
            '${entry.path}: recipe id "${recipe.id}" does not match index id "${entry.id}".',
      );
    }
    final withImages = await _storeImages(recipe);
    final applied = await store.upsertGithubRecipe(withImages);
    if (!applied) {
      return (
        upserted: 0,
        removed: 0,
        error:
            '${entry.id}: a recipe imported on this computer already uses that id, so it was left unchanged.',
      );
    }
    return (upserted: 1, removed: 0, error: null);
  }

  Future<Recipe> _storeImages(Recipe recipe) async {
    final root = supportDirectory;
    if (root == null || recipe.repoImages.isEmpty) return recipe;
    final stored = <String>[];
    final safeId = recipe.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    for (final repoPath in recipe.repoImages) {
      final name = p
          .basename(repoPath)
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (name.isEmpty || name == '.' || name == '..') {
        throw SyncException('$repoPath is not a safe image path.');
      }
      final relative = 'images/$safeId/$name';
      final file = fileInside(root, relative);
      if (file == null) {
        throw SyncException('$repoPath is not a safe image path.');
      }
      final bytes = await remote.fetchBytes(repoPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      stored.add(relative);
    }
    return recipe.copyWith(imagePaths: stored);
  }
}
