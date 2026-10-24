import 'dart:convert';

import '../db/recipe_store.dart';
import '../models/repo_doc.dart';
import '../storage/safe_path.dart';
import 'recipe_remote.dart';
import 'repo_tree.dart';
import 'sync_exception.dart';

const _maxBytes = 8 * 1024 * 1024;

/// Downloads equipment, methods, preferences, meal plans, and meal-pack PDFs.
///
/// A file is skipped when its git sha is already stored. A failed download
/// leaves the previous copy in place. Files that disappear from the repo are
/// removed only after the listing itself succeeds.
final class RepoLibrarySync {
  RepoLibrarySync({
    required this.store,
    required this.remote,
    required this.supportDirectory,
  });

  final RecipeStore store;
  final RecipeRemote remote;
  final String supportDirectory;

  Future<List<String>> sync() async {
    final tree = await remote.fetchTree();
    final wanted = [
      for (final blob in tree)
        if (kindForPath(blob.path) != null) blob,
    ];
    final existing = {for (final doc in await store.allDocs()) doc.path: doc};
    final errors = <String>[];
    final keep = <String>{};
    for (final blob in wanted) {
      keep.add(blob.path);
      final current = existing[blob.path];
      if (current != null &&
          current.sha == blob.sha &&
          await _stillOnDisk(current)) {
        continue;
      }
      try {
        await _download(blob);
      } catch (error) {
        errors.add('${blob.path}: ${describeSyncError(error)}');
      }
    }
    if (errors.isNotEmpty) return errors;
    for (final doc in existing.values) {
      if (keep.contains(doc.path)) continue;
      await _deleteFile(doc);
      await store.removeDoc(doc.path);
    }
    return const [];
  }

  Future<bool> _stillOnDisk(RepoDoc doc) async {
    final relative = doc.filePath;
    if (relative == null) return true;
    final file = fileInside(supportDirectory, relative);
    return file != null && await file.exists();
  }

  Future<void> _download(RepoBlob blob) async {
    final kind = kindForPath(blob.path);
    if (kind == null) return;
    if (blob.size != null && blob.size! > _maxBytes) {
      throw SyncException('${blob.path} is too large to store.');
    }
    final bytes = await remote.fetchBytes(blob.path);
    if (bytes.length > _maxBytes) {
      throw SyncException('${blob.path} is too large to store.');
    }
    if (kind == RepoKind.mealPdf) {
      final relative = _relative(blob.path);
      final file = fileInside(supportDirectory, relative);
      if (file == null) {
        throw SyncException('${blob.path} is not a safe file path.');
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await store.upsertDoc(
        RepoDoc(
          path: blob.path,
          sha: blob.sha,
          kind: kind,
          title: titleFromPath(blob.path),
          filePath: relative,
        ),
      );
      return;
    }
    final body = utf8.decode(bytes);
    await store.upsertDoc(
      RepoDoc(
        path: blob.path,
        sha: blob.sha,
        kind: kind,
        title: titleFromMarkdown(body, blob.path),
        body: body,
      ),
    );
  }

  Future<void> _deleteFile(RepoDoc doc) async {
    final relative = doc.filePath;
    if (relative == null) return;
    final file = fileInside(supportDirectory, relative);
    if (file != null && await file.exists()) await file.delete();
  }

  String _relative(String repoPath) {
    final segments = repoPath.split('/').where((segment) => segment.isNotEmpty);
    return [
      'repo',
      for (final segment in segments) _safeSegment(segment),
    ].join('/');
  }

  String _safeSegment(String segment) {
    final cleaned = segment.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}
