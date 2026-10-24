import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'auth/github_token_store.dart';
import 'db/sqlite_recipe_store.dart';
import 'import/flavorish_export_mapper.dart';
import 'import/flavorish_importer.dart';
import 'models/app_settings.dart';
import 'share/page_description.dart';
import 'share/share_resolver.dart';
import 'state/library_controller.dart';
import 'sync/github_publisher.dart';
import 'sync/github_token.dart';
import 'sync/http_recipe_remote.dart';
import 'sync/repo_library_sync.dart';
import 'sync/sync_service.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await buildController();
  await controller.reload();
  runApp(RecipesApp(controller: controller));
}

Future<LibraryController> buildController() async {
  if (Platform.isAndroid) {
    databaseFactoryOrNull ??= mobile.databaseFactorySqflitePlugin;
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final support = await getApplicationSupportDirectory();
  await Directory(support.path).create(recursive: true);
  final store = await SqliteRecipeStore.openFile(support.path);
  final settings = await AppSettings.load(store);
  final client = http.Client();
  final timeout = Duration(seconds: settings.timeoutSeconds);
  final remote = HttpRecipeRemote(client: client, timeout: timeout);
  final pages = HttpPageDescription(client: client, timeout: timeout);
  final tokenStore = SecureGithubTokenStore();
  final publisher = FlavorishRepoPublisher(
    client: client,
    tokenReader: () => publishToken(tokenStore),
  );
  return LibraryController(
    store: store,
    remote: remote,
    syncService: SyncService(
      store: store,
      remote: remote,
      supportDirectory: support.path,
    ),
    importer: FlavorishImporter(
      store: store,
      supportDirectory: support.path,
      mapper: const FlavorishExportMapper(),
      publisher: publisher,
    ),
    supportDirectory: support.path,
    initialSettings: settings,
    tokenStore: tokenStore,
    publisher: publisher,
    shareResolver: ShareResolver(pages: pages),
    repoLibrary: RepoLibrarySync(
      store: store,
      remote: remote,
      supportDirectory: support.path,
    ),
  );
}

Future<String> publishToken(GithubTokenStore store) async {
  final saved = await store.read();
  if (saved != null && saved.isNotEmpty) return saved;
  if (Platform.isWindows) return readWindowsGitHubToken();
  throw GithubPublishException(
    'Add a GitHub key in Settings before recipes can be published.',
  );
}

class RecipesApp extends StatelessWidget {
  const RecipesApp({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<LibraryController, ThemeMode>(
      (controller) => controller.settings.themeMode,
    );
    final textScale = context.select<LibraryController, double>(
      (controller) => controller.settings.textScale,
    );
    return MaterialApp(
      title: 'Recipes',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const HomeShell(),
    );
  }
}
