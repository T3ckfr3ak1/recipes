import '../sync/sync_exception.dart';

/// Recipe Keeper repo. This is a build-time constant, not a setting.
abstract final class RepoConfig {
  static const owner = 'T3ckfr3ak1';
  static const name = 'recipes';
  static const branch = 'main';
  static const rawHost = 'https://raw.githubusercontent.com';
  static const apiHost = 'https://api.github.com';

  static const String label = '$owner/$name';

  static final Uri rawBase = Uri.parse('$rawHost/$owner/$name/$branch/');

  /// Index downloads always include a cache-busting `t` parameter.
  /// raw.githubusercontent.com can serve a stale index for a few minutes.
  static Uri indexUri(DateTime now) {
    return rawBase
        .resolve('index.json')
        .replace(
          queryParameters: {'t': '${now.toUtc().millisecondsSinceEpoch}'},
        );
  }

  /// Recipe file downloads are not cache-busted. [path] is the repo-relative
  /// path from index.json, such as `recipes/soup.json`.
  static Uri recipeUri(String path) {
    return rawBase.resolve(_encodedPath(path));
  }

  /// Recursive git tree. One call lists recipes, notes, and meal plans.
  static Uri treeUri() {
    return Uri.parse(
      '$apiHost/repos/$owner/$name/git/trees/$branch',
    ).replace(queryParameters: const {'recursive': '1'});
  }

  /// Contents API path. [withRef] is for reads; writes send the branch in the
  /// request body instead.
  static Uri contentsUri(String path, {bool withRef = true}) {
    final uri = Uri.parse(
      '$apiHost/repos/$owner/$name/contents/${_encodedPath(path)}',
    );
    if (!withRef) return uri;
    return uri.replace(queryParameters: const {'ref': branch});
  }

  static String _encodedPath(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('..') ||
        normalized.contains('://') ||
        normalized.contains('?')) {
      throw SyncException('Recipe path is not a file in the repo: $path');
    }
    return normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
  }
}
