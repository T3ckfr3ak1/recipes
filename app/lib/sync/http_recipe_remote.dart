import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/repo_config.dart';
import '../models/index_document.dart';
import '../models/recipe.dart';
import 'recipe_remote.dart';
import 'repo_tree.dart';
import 'sync_exception.dart';

final class HttpRecipeRemote implements RecipeRemote {
  HttpRecipeRemote({required this.client, required this.timeout});

  final http.Client client;

  @override
  Duration timeout;

  /// Sent on reads when the phone has a key. A public repo still syncs
  /// without one.
  String? accessToken;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'User-Agent': 'recipes',
    if (accessToken != null && accessToken!.trim().isNotEmpty)
      'Authorization': 'Bearer ${accessToken!.trim()}',
  };

  @override
  Future<IndexDocument> fetchIndex({required DateTime now}) async {
    final body = (await _send(RepoConfig.indexUri(now), 'index.json')).body;
    try {
      return IndexDocument.parse(body);
    } on FormatException catch (error) {
      throw SyncException('index.json could not be read. ${error.message}');
    }
  }

  @override
  Future<Recipe> fetchRecipe(IndexEntry entry) async {
    final body = (await _send(
      RepoConfig.recipeUri(entry.path),
      entry.path,
    )).body;
    try {
      return Recipe.fromKeeperJson(body);
    } on FormatException catch (error) {
      throw SyncException('${entry.path} could not be read. ${error.message}');
    }
  }

  @override
  Future<List<int>> fetchBytes(String path) async {
    return (await _send(RepoConfig.recipeUri(path), path)).bodyBytes;
  }

  @override
  Future<List<RepoBlob>> fetchTree() async {
    final body = (await _send(RepoConfig.treeUri(), 'repository listing')).body;
    return parseRepoTree(body);
  }

  Future<http.Response> _send(Uri uri, String label) async {
    final http.Response response;
    try {
      response = await client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw SyncException('Timed out downloading $label.');
    } on SocketException catch (error) {
      throw SyncException(
        "Couldn't reach the recipe repo ($label). ${error.message}",
      );
    } on http.ClientException catch (error) {
      throw SyncException(
        "Couldn't reach the recipe repo ($label). ${error.message}",
      );
    }
    if (response.statusCode != 200) {
      throw SyncException(
        'Download of $label failed (HTTP ${response.statusCode}).',
      );
    }
    return response;
  }
}
