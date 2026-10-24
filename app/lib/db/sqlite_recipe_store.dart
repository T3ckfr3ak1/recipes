import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/recipe.dart';
import '../models/recipe_origin.dart';
import '../models/repo_doc.dart';
import 'recipe_store.dart';

final class SqliteRecipeStore implements RecipeStore {
  SqliteRecipeStore(this._db);

  final Database _db;

  static Future<SqliteRecipeStore> openFile(String supportDirectory) async {
    final db = await databaseFactory.openDatabase(
      p.join(supportDirectory, 'recipes.db'),
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: _configure,
        onCreate: (db, version) => _create(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            _upgrade(db, oldVersion, newVersion),
      ),
    );
    return SqliteRecipeStore(db);
  }

  static Future<SqliteRecipeStore> openMemory() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: _configure,
        onCreate: (db, version) => _create(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            _upgrade(db, oldVersion, newVersion),
      ),
    );
    return SqliteRecipeStore(db);
  }

  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _create(Database db) async {
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        servings REAL,
        prep_minutes INTEGER,
        cook_minutes INTEGER,
        ingredients_json TEXT NOT NULL,
        steps_json TEXT NOT NULL,
        tags_json TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        air_fry_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        origin TEXT NOT NULL,
        flavorish_id TEXT,
        images_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX recipes_flavorish_id
      ON recipes(flavorish_id)
      WHERE flavorish_id IS NOT NULL
    ''');
    await _createDocs(db);
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createDocs(db);
  }

  static Future<void> _createDocs(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS repo_docs (
        path TEXT PRIMARY KEY,
        sha TEXT NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        file_path TEXT
      )
    ''');
  }

  Future<void> close() => _db.close();

  @override
  Future<String?> getMeta(String key) async {
    final rows = await _db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await _db.delete('meta', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Recipe>> allRecipes() async {
    final rows = await _db.query('recipes', where: 'deleted = 0');
    return rows.map(Recipe.fromStorageMap).toList();
  }

  @override
  Future<bool> upsertGithubRecipe(Recipe recipe) async {
    final existing = await _find(recipe.id);
    if (existing != null && existing.origin != RecipeOrigin.github) {
      return false;
    }
    final twin = await _findLocalByFlavorish(recipe.id);
    final keepFlavorish =
        recipe.flavorishId ?? existing?.flavorishId ?? twin?.flavorishId;
    final images = recipe.imagePaths.isNotEmpty
        ? recipe.imagePaths
        : (existing != null && existing.imagePaths.isNotEmpty
              ? existing.imagePaths
              : twin?.imagePaths ?? const <String>[]);
    if (twin != null && twin.id != recipe.id) {
      await removeLocalRecipe(twin.id);
    }
    final row = recipe
        .copyWith(
          origin: RecipeOrigin.github,
          flavorishId: keepFlavorish,
          clearFlavorishId: keepFlavorish == null || keepFlavorish.isEmpty,
          deleted: false,
          imagePaths: images,
        )
        .toStorageMap();
    await _db.insert(
      'recipes',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  @override
  Future<void> removeGithubRecipe(String id) async {
    await _db.delete(
      'recipes',
      where: 'id = ? AND origin = ?',
      whereArgs: [id, RecipeOrigin.github.name],
    );
  }

  @override
  Future<bool> hasFlavorishId(String flavorishId) async {
    final rows = await _db.query(
      'recipes',
      columns: ['id'],
      where: 'flavorish_id = ? OR id = ? OR id = ?',
      whereArgs: [flavorishId, flavorishId, 'flavorish:$flavorishId'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Recipe?> _findLocalByFlavorish(String flavorishId) async {
    final rows = await _db.query(
      'recipes',
      where: 'origin = ? AND flavorish_id = ?',
      whereArgs: [RecipeOrigin.local.name, flavorishId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final recipe = Recipe.fromStorageMap(rows.first);
    if (recipe.id == flavorishId) return null;
    return recipe;
  }

  @override
  Future<void> insertLocalRecipe(Recipe recipe) async {
    final flavorishId = recipe.flavorishId;
    if (flavorishId == null || flavorishId.isEmpty) {
      throw ArgumentError('A Flavorish import needs a Flavorish id.');
    }
    if (await _find(recipe.id) != null) {
      throw StateError('A recipe with id ${recipe.id} is already stored.');
    }
    if (await hasFlavorishId(flavorishId)) {
      throw StateError('Flavorish recipe $flavorishId was already imported.');
    }
    await _db.insert(
      'recipes',
      recipe
          .copyWith(
            source: 'Flavorish',
            origin: RecipeOrigin.local,
            flavorishId: flavorishId,
            deleted: false,
          )
          .toStorageMap(),
    );
  }

  @override
  Future<void> removeLocalRecipe(String id) async {
    await _db.delete(
      'recipes',
      where: 'id = ? AND origin = ?',
      whereArgs: [id, RecipeOrigin.local.name],
    );
  }

  @override
  Future<List<RepoDoc>> allDocs() async {
    final rows = await _db.query('repo_docs');
    return rows.map(RepoDoc.fromRow).toList();
  }

  @override
  Future<void> upsertDoc(RepoDoc doc) async {
    await _db.insert(
      'repo_docs',
      doc.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeDoc(String path) async {
    await _db.delete('repo_docs', where: 'path = ?', whereArgs: [path]);
  }

  Future<Recipe?> _find(String id) async {
    final rows = await _db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Recipe.fromStorageMap(rows.first);
  }
}
