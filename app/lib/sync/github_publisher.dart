import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../config/repo_config.dart';
import '../models/recipe.dart';
import '../storage/safe_path.dart';
import '../time/instants.dart';
import 'github_token.dart';
import 'index_merge.dart';

abstract interface class RecipePublisher {
  Future<void> publish(
    List<Recipe> recipes, {
    required String supportDirectory,
  });
}

/// Writes recipe files, photos, and index.json to the Recipe Keeper repo.
final class FlavorishRepoPublisher implements RecipePublisher {
  FlavorishRepoPublisher({required this.client, this.token, this.tokenReader});

  final http.Client client;
  final String? token;
  final Future<String> Function()? tokenReader;
  String? lastCommit;
  String? _cachedToken;

  static const _timeout = Duration(seconds: 60);

  @override
  Future<void> publish(
    List<Recipe> recipes, {
    required String supportDirectory,
  }) async {
    if (recipes.isEmpty) return;
    final files = <String, List<int>>{};
    final updates = <IndexUpdate>[];
    final publishedAt = isoWithOffset(DateTime.now());
    for (final recipe in recipes) {
      final id = repoIdFor(id: recipe.id, flavorishId: recipe.flavorishId);
      final imagePaths = <String>[];
      for (final relative in recipe.imagePaths) {
        final file = fileInside(supportDirectory, relative);
        if (file == null || !await file.exists()) continue;
        final name = p
            .basename(relative)
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        if (name.isEmpty || name == '.' || name == '..') continue;
        final repoPath = 'images/$id/$name';
        files[repoPath] = await file.readAsBytes();
        imagePaths.add(repoPath);
      }
      final source =
          recipe.flavorishId != null && recipe.flavorishId!.trim().isNotEmpty
          ? 'Flavorish'
          : recipe.source;
      final document = recipe
          .copyWith(id: id, repoImages: imagePaths, source: source)
          .toKeeperJson();
      files['recipes/$id.json'] = utf8.encode(document);
      updates.add(
        IndexUpdate(
          id: id,
          updatedAt: publishedAt,
          deleted: recipe.deleted,
          path: 'recipes/$id.json',
        ),
      );
    }
    final readme = await _readRepoFile('README.md');
    final noted = readme == null ? null : _withPublishNote(readme);
    if (noted != null) files['README.md'] = utf8.encode(noted);
    final index = mergeIndexJson(
      current: await _readRepoFile('index.json'),
      updates: updates,
      generatedAt: publishedAt,
    );
    files['index.json'] = utf8.encode(index);
    await _commit(files, 'Publish recipes');
  }

  Future<void> _commit(Map<String, List<int>> files, String message) async {
    final ref = await _request('GET', 'git/ref/heads/${RepoConfig.branch}');
    final parent = _sha(ref['object']);
    final commit = await _request('GET', 'git/commits/$parent');
    final baseTree = _sha(commit['tree']);
    final entries = <Map<String, String>>[];
    final jobs = files.entries.toList();
    final shas = await _pool(jobs.length, 4, (index) async {
      final blob = await _request(
        'POST',
        'git/blobs',
        body: {
          'content': base64Encode(jobs[index].value),
          'encoding': 'base64',
        },
      );
      final sha = blob['sha'];
      if (sha is! String || sha.isEmpty) {
        throw GithubPublishException('GitHub did not return a file id.');
      }
      return sha;
    });
    for (var i = 0; i < jobs.length; i++) {
      entries.add({
        'path': jobs[i].key,
        'mode': '100644',
        'type': 'blob',
        'sha': shas[i],
      });
    }
    final tree = await _request(
      'POST',
      'git/trees',
      body: {'base_tree': baseTree, 'tree': entries},
    );
    final next = await _request(
      'POST',
      'git/commits',
      body: {
        'message': message,
        'tree': _text(tree['sha'], 'tree'),
        'parents': [parent],
      },
    );
    final commitSha = _text(next['sha'], 'commit');
    await _request(
      'PATCH',
      'git/refs/heads/${RepoConfig.branch}',
      body: {'sha': commitSha},
    );
    lastCommit = commitSha;
  }

  Future<String?> _readRepoFile(String path) async {
    final response = await _send('GET', 'contents/$path');
    if (response.statusCode == 404) return null;
    final decoded = _decode(response, 'GET', 'contents/$path');
    final content = decoded['content'];
    if (content is! String) return null;
    return utf8.decode(base64.decode(content.replaceAll(RegExp(r'\s+'), '')));
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    final response = await _send(method, path, body: body);
    return _decode(response, method, path);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final secret = await _token();
    final basic = base64Encode(utf8.encode('${RepoConfig.owner}:$secret'));
    final request = http.Request(
      method,
      Uri.https(
        'api.github.com',
        '/repos/${RepoConfig.owner}/${RepoConfig.name}/$path',
      ),
    );
    request.headers.addAll({
      'Authorization': 'Basic $basic',
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'recipes-windows',
      'X-GitHub-Api-Version': '2022-11-28',
    });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await client.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }

  Future<String> _token() async {
    final supplied = token;
    if (supplied != null && supplied.isNotEmpty) return supplied;
    final cached = _cachedToken;
    if (cached != null && cached.isNotEmpty) return cached;
    final reader = tokenReader ?? readWindowsGitHubToken;
    try {
      final value = (await reader()).trim();
      if (value.isEmpty) {
        throw GithubPublishException(
          'GitHub sign-in is missing, so the recipes stayed on this computer.',
        );
      }
      _cachedToken = value;
      return value;
    } on GithubPublishException {
      rethrow;
    } catch (_) {
      throw GithubPublishException(
        'GitHub sign-in is missing, so the recipes stayed on this computer.',
      );
    }
  }

  Map<String, Object?> _decode(
    http.Response response,
    String method,
    String path,
  ) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GithubPublishException(
        'GitHub rejected the saved sign-in ($method $path, HTTP ${response.statusCode}). ${_githubMessage(response.body)}',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GithubPublishException(
        'GitHub $method $path failed (HTTP ${response.statusCode}).',
      );
    }
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw GithubPublishException('GitHub $method $path returned no object.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  String _sha(Object? value) {
    if (value is! Map) {
      throw GithubPublishException('GitHub did not return a commit.');
    }
    return _text(value['sha'], 'sha');
  }

  String _githubMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        final message = decoded['message'] as String;
        if (message.length <= 180) return message;
      }
    } on FormatException {
      return '';
    }
    return '';
  }

  String _text(Object? value, String field) {
    if (value is! String || value.isEmpty) {
      throw GithubPublishException('GitHub did not return a $field.');
    }
    return value;
  }
}

String? _withPublishNote(String readme) {
  var next = readme;
  var changed = false;
  const sentence =
      'The Windows recipe app reads this repo and publishes every recipe here, including Flavorish imports.';
  if (!next.contains('publishes every recipe here')) {
    final replaced = next.replaceFirst(
      'The Windows recipe app reads this repo.',
      sentence,
    );
    if (replaced != next) {
      next = replaced;
      changed = true;
    }
  }
  if (!next.contains('`images/`')) {
    final replaced = next.replaceFirst(
      '\nAll times are',
      '\n- `images/` holds optional photos. A recipe can list them in `images` as repo paths.\n\nAll times are',
    );
    if (replaced != next) {
      next = replaced;
      changed = true;
    }
  }
  if (!changed) return null;
  if (!next.endsWith('\n')) next = '$next\n';
  return next;
}

Future<List<T>> _pool<T>(
  int count,
  int width,
  Future<T> Function(int index) job,
) async {
  final results = List<T?>.filled(count, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final index = next;
      if (index >= count) return;
      next++;
      results[index] = await job(index);
    }
  }

  final workers = width < count ? width : count;
  await Future.wait(List.generate(workers, (_) => worker()));
  return [for (final result in results) result as T];
}
