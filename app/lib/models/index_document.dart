import 'dart:convert';

import '../time/instants.dart';

final class IndexEntry {
  const IndexEntry({
    required this.id,
    required this.updatedAt,
    required this.updatedAtRaw,
    required this.deleted,
    required this.path,
  });

  final String id;
  final DateTime updatedAt;
  final String updatedAtRaw;
  final bool deleted;
  final String path;
}

final class IndexDocument {
  const IndexDocument({
    required this.generatedAt,
    required this.generatedAtRaw,
    required this.recipes,
  });

  final DateTime generatedAt;
  final String generatedAtRaw;
  final List<IndexEntry> recipes;

  static IndexDocument parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw FormatException('index.json is not valid JSON. ${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('index.json must be an object');
    }
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    final generatedRaw = map['generated_at'];
    if (generatedRaw is! String || generatedRaw.trim().isEmpty) {
      throw const FormatException(
        'index.json generated_at must be a timestamp',
      );
    }
    final recipesRaw = map['recipes'];
    if (recipesRaw is! List) {
      throw const FormatException('index.json recipes must be a list');
    }
    return IndexDocument(
      generatedAt: parseInstant(generatedRaw, field: 'generated_at'),
      generatedAtRaw: generatedRaw,
      recipes: [
        for (var i = 0; i < recipesRaw.length; i++) _entry(recipesRaw[i], i),
      ],
    );
  }
}

IndexEntry _entry(Object? value, int index) {
  if (value is! Map) {
    throw FormatException('index.json recipes[$index] must be an object');
  }
  final map = value.map((key, entry) => MapEntry(key.toString(), entry));
  final id = map['id'];
  final updatedRaw = map['updated_at'];
  final path = map['path'];
  if (id is! String || id.trim().isEmpty) {
    throw FormatException('index.json recipes[$index].id must be text');
  }
  if (updatedRaw is! String || updatedRaw.trim().isEmpty) {
    throw FormatException(
      'index.json recipes[$index].updated_at must be a timestamp',
    );
  }
  if (path is! String || path.trim().isEmpty) {
    throw FormatException('index.json recipes[$index].path must be text');
  }
  final deleted = map['deleted'];
  if (deleted != null && deleted is! bool) {
    throw FormatException(
      'index.json recipes[$index].deleted must be true or false',
    );
  }
  return IndexEntry(
    id: id.trim(),
    updatedAt: parseInstant(updatedRaw, field: 'recipes[$index].updated_at'),
    updatedAtRaw: updatedRaw,
    deleted: deleted == true,
    path: path.trim(),
  );
}
