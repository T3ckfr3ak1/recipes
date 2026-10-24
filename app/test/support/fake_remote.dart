import 'dart:convert';

import 'package:recipes/models/index_document.dart';
import 'package:recipes/models/recipe.dart';
import 'package:recipes/sync/recipe_remote.dart';
import 'package:recipes/sync/repo_tree.dart';
import 'package:recipes/sync/sync_exception.dart';
import 'package:recipes/time/instants.dart';

IndexDocument sampleIndex(String generatedAt, List<IndexEntry> recipes) {
  return IndexDocument(
    generatedAt: parseInstant(generatedAt),
    generatedAtRaw: generatedAt,
    recipes: recipes,
  );
}

IndexEntry sampleEntry({
  required String id,
  required String updatedAt,
  bool deleted = false,
  String? path,
}) {
  return IndexEntry(
    id: id,
    updatedAt: parseInstant(updatedAt),
    updatedAtRaw: updatedAt,
    deleted: deleted,
    path: path ?? 'recipes/$id.json',
  );
}

final class FakeRemote implements RecipeRemote {
  FakeRemote({
    required this.index,
    this.byPath = const {},
    this.indexError,
    this.tree = const [],
    this.treeError,
  });

  IndexDocument index;
  Object? indexError;
  Map<String, Object> byPath;
  List<RepoBlob> tree;
  Object? treeError;
  final List<String> fetched = [];
  DateTime? seenNow;
  int indexCalls = 0;

  @override
  Duration timeout = const Duration(seconds: 20);

  @override
  Future<IndexDocument> fetchIndex({required DateTime now}) async {
    indexCalls++;
    seenNow = now;
    final error = indexError;
    if (error != null) throw error;
    return index;
  }

  @override
  Future<Recipe> fetchRecipe(IndexEntry entry) async {
    fetched.add(entry.path);
    final value = byPath[entry.path];
    if (value is Recipe) return value;
    if (value is Exception) throw value;
    throw SyncException('missing ${entry.path}');
  }

  @override
  Future<List<int>> fetchBytes(String path) async {
    fetched.add(path);
    final value = byPath[path];
    if (value is List<int>) return value;
    if (value is String) return utf8.encode(value);
    throw SyncException('missing $path');
  }

  @override
  Future<List<RepoBlob>> fetchTree() async {
    final error = treeError;
    if (error != null) throw error;
    return tree;
  }
}
