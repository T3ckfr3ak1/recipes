import 'dart:convert';

import '../models/index_document.dart';

final class IndexUpdate {
  const IndexUpdate({
    required this.id,
    required this.updatedAt,
    required this.deleted,
    required this.path,
  });

  final String id;
  final String updatedAt;
  final bool deleted;
  final String path;
}

/// Rebuilds index.json, replacing entries with the same id and keeping the rest.
String mergeIndexJson({
  required String? current,
  required List<IndexUpdate> updates,
  required String generatedAt,
}) {
  final byId = <String, IndexUpdate>{};
  final order = <String>[];
  if (current != null && current.trim().isNotEmpty) {
    for (final entry in IndexDocument.parse(current).recipes) {
      order.add(entry.id);
      byId[entry.id] = IndexUpdate(
        id: entry.id,
        updatedAt: entry.updatedAtRaw,
        deleted: entry.deleted,
        path: entry.path,
      );
    }
  }
  for (final update in updates) {
    if (!byId.containsKey(update.id)) order.add(update.id);
    byId[update.id] = update;
  }
  final recipes = [
    for (final id in order)
      {
        'id': byId[id]!.id,
        'updated_at': byId[id]!.updatedAt,
        'deleted': byId[id]!.deleted,
        'path': byId[id]!.path,
      },
  ];
  return '${const JsonEncoder.withIndent('  ').convert({'generated_at': generatedAt, 'recipes': recipes})}\n';
}

/// The id used for `recipes/<id>.json`. Flavorish ids are the UUID, not `flavorish:`.
String repoIdFor({required String id, String? flavorishId}) {
  final raw = (flavorishId ?? id).trim();
  final repoId = raw.startsWith('flavorish:')
      ? raw.substring('flavorish:'.length)
      : raw;
  if (repoId.isEmpty ||
      repoId.contains('/') ||
      repoId.contains('\\') ||
      repoId.contains('..') ||
      repoId.contains(':')) {
    throw FormatException('Recipe id cannot be stored in the repo.');
  }
  return repoId;
}
