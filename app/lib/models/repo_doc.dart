enum RepoKind {
  equipment,
  method,
  preference,
  mealPlan,
  mealPdf;

  String get label => switch (this) {
    RepoKind.equipment => 'Equipment',
    RepoKind.method => 'Methods',
    RepoKind.preference => 'Preferences',
    RepoKind.mealPlan => 'Meal plan',
    RepoKind.mealPdf => 'Meal pack',
  };

  static RepoKind? parse(String raw) {
    for (final kind in RepoKind.values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

/// A markdown note or meal-pack file from the recipe repo.
final class RepoDoc {
  const RepoDoc({
    required this.path,
    required this.sha,
    required this.kind,
    required this.title,
    this.body = '',
    this.filePath,
  });

  final String path;
  final String sha;
  final RepoKind kind;
  final String title;
  final String body;

  /// Library-folder path for a downloaded PDF. Markdown stays in [body].
  final String? filePath;

  Map<String, Object?> toRow() => {
    'path': path,
    'sha': sha,
    'kind': kind.name,
    'title': title,
    'body': body,
    'file_path': filePath,
  };

  static RepoDoc fromRow(Map<String, Object?> row) {
    final kind = RepoKind.parse(row['kind'] as String? ?? '');
    return RepoDoc(
      path: row['path'] as String? ?? '',
      sha: row['sha'] as String? ?? '',
      kind: kind ?? RepoKind.method,
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      filePath: row['file_path'] as String?,
    );
  }
}

/// Which repo folder a file belongs in. Paths that leave the repo are ignored.
RepoKind? kindForPath(String path) {
  final normal = path.trim().replaceAll('\\', '/');
  if (normal.isEmpty ||
      normal.startsWith('/') ||
      normal.contains('..') ||
      normal.contains('://')) {
    return null;
  }
  final lower = normal.toLowerCase();
  if (lower.startsWith('equipment/') && lower.endsWith('.md')) {
    return RepoKind.equipment;
  }
  if (lower.startsWith('methods/') && lower.endsWith('.md')) {
    return RepoKind.method;
  }
  if (lower.startsWith('preferences/') && lower.endsWith('.md')) {
    return RepoKind.preference;
  }
  if (lower.startsWith('meal-plan/') && lower.endsWith('.md')) {
    return RepoKind.mealPlan;
  }
  if (lower.startsWith('meal-plan/') && lower.endsWith('.pdf')) {
    return RepoKind.mealPdf;
  }
  return null;
}

int compareRepoDocs(RepoDoc a, RepoDoc b) {
  final aReadme = a.path.toLowerCase().endsWith('/readme.md');
  final bReadme = b.path.toLowerCase().endsWith('/readme.md');
  if (aReadme != bReadme) return aReadme ? -1 : 1;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

String titleFromMarkdown(String body, String path) {
  for (final raw in body.split(RegExp(r'\r?\n'))) {
    final match = RegExp(r'^#{1,3}\s+(.+?)\s*#*$').firstMatch(raw.trim());
    if (match == null) continue;
    final title = match
        .group(1)!
        .replaceAll('**', '')
        .replaceAll('`', '')
        .trim();
    if (title.isNotEmpty) return title;
  }
  return titleFromPath(path);
}

String titleFromPath(String path) {
  final parts = path.split('/');
  final name = parts.last.replaceAll(
    RegExp(r'\.(md|pdf)$', caseSensitive: false),
    '',
  );
  if (name.toLowerCase() == 'readme' && parts.length >= 2) {
    return '${_words(parts[parts.length - 2])} notes';
  }
  return _words(name);
}

String _words(String slug) {
  final words = slug.split(RegExp(r'[-_]+')).where((word) => word.isNotEmpty);
  return words
      .map((word) {
        if (word.length <= 2) return word.toUpperCase();
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
