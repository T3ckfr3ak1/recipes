import 'dart:convert';

import 'sync_exception.dart';

final class RepoBlob {
  const RepoBlob({required this.path, required this.sha, this.size});

  final String path;
  final String sha;
  final int? size;
}

/// Git tree listing for the recipe repo. Directories are dropped.
List<RepoBlob> parseRepoTree(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (error) {
    throw SyncException(
      'The recipe repo listing could not be read. ${error.message}',
    );
  }
  if (decoded is! Map) {
    throw SyncException('The recipe repo listing could not be read.');
  }
  final map = decoded.map((key, value) => MapEntry(key.toString(), value));
  if (map['truncated'] == true) {
    throw SyncException(
      'The recipe repo listing was incomplete, so notes were left unchanged.',
    );
  }
  final tree = map['tree'];
  if (tree is! List) {
    throw SyncException('The recipe repo listing could not be read.');
  }
  final blobs = <RepoBlob>[];
  for (final entry in tree) {
    if (entry is! Map) continue;
    final item = entry.map((key, value) => MapEntry(key.toString(), value));
    if (item['type'] != 'blob') continue;
    final path = item['path'];
    final sha = item['sha'];
    if (path is! String || path.trim().isEmpty) continue;
    if (sha is! String || sha.trim().isEmpty) continue;
    final size = item['size'];
    blobs.add(
      RepoBlob(
        path: path.trim(),
        sha: sha.trim(),
        size: size is num ? size.toInt() : null,
      ),
    );
  }
  return blobs;
}
