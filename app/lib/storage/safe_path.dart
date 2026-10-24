import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves [relativePath] and returns a file only when it stays inside [root].
File? fileInside(String root, String relativePath) {
  if (relativePath.trim().isEmpty) return null;
  final normalizedRelative = p.normalize(relativePath);
  if (p.isAbsolute(normalizedRelative) ||
      normalizedRelative == '..' ||
      normalizedRelative.startsWith('..${p.separator}') ||
      normalizedRelative.split(p.separator).contains('..')) {
    return null;
  }
  final base = p.normalize(root);
  final full = p.normalize(p.join(base, normalizedRelative));
  final prefix = base.endsWith(p.separator) ? base : '$base${p.separator}';
  if (full != base && !full.startsWith(prefix)) return null;
  return File(full);
}
