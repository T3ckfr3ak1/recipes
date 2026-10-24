import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/import/flavorish_export_mapper.dart';
import 'package:recipes/import/flavorish_importer.dart';
import 'package:recipes/sync/github_publisher.dart';
import 'package:recipes/sync/github_token.dart';

/// Publishes a Flavorish export zip to the recipe repo.
///
/// Set FLAVORISH_ZIP to the zip path. Prints counts only.
Future<void> main() async {
  final zipPath = Platform.environment['FLAVORISH_ZIP'];
  if (zipPath == null || zipPath.isEmpty) {
    stderr.writeln('Set FLAVORISH_ZIP to the export zip.');
    exitCode = 64;
    return;
  }
  final bytes = await File(zipPath).readAsBytes();
  final client = http.Client();
  final temp = await Directory.systemTemp.createTemp('recipes_publish_');
  try {
    final publisher = FlavorishRepoPublisher(
      client: client,
      tokenReader: readWindowsGitHubToken,
    );
    final importer = FlavorishImporter(
      store: MemoryRecipeStore(),
      supportDirectory: temp.path,
      mapper: const FlavorishExportMapper(),
      publisher: publisher,
    );
    final result = await importer.importBytes(bytes);
    stdout.writeln(
      'imported=${result.imported} published=${result.published} '
      'skipped=${result.skipped} errors=${result.errors.length} '
      'commit=${publisher.lastCommit ?? ''}',
    );
    for (final error in result.errors) {
      stderr.writeln(error);
    }
    if (result.errors.isNotEmpty || result.published == 0) exitCode = 1;
  } finally {
    client.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  }
}
