import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/db/recipe_store.dart';
import 'package:recipes/import/flavorish_export_mapper.dart';
import 'package:recipes/import/flavorish_importer.dart';
import 'package:recipes/main.dart';
import 'package:recipes/models/app_settings.dart';
import 'package:recipes/models/ingredient.dart';
import 'package:recipes/models/repo_doc.dart';
import 'package:recipes/state/library_controller.dart';
import 'package:recipes/sync/sync_service.dart';

import 'support/fake_remote.dart';
import 'support/samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search, scale, print view, and offline error', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryRecipeStore();
    await store.setMeta(MetaKeys.lastSyncError, 'Could not reach the repo');
    await store.upsertGithubRecipe(
      sampleRecipe(
        id: 'soup',
        title: 'Tomato Soup',
        category: 'Dinner',
        tags: const ['comfort'],
        servings: 4,
        ingredients: const [
          Ingredient(
            quantity: '1',
            unit: 'cup',
            item: 'kale',
            quantityValue: 1,
          ),
        ],
      ),
    );
    await store.insertLocalRecipe(
      sampleRecipe(
        id: 'flavorish:pie',
        title: 'Apple Pie',
        category: 'Dessert',
        tags: const ['bake'],
        flavorishId: 'pie',
        servings: 8,
      ),
    );
    final settings = AppSettings.defaults.copyWith(syncOnLaunch: false);
    await settings.save(store);
    final controller = _controller(
      store,
      settings,
      FakeRemote(index: sampleIndex('2026-01-01T00:00:00Z', const [])),
    );
    await controller.reload();

    await tester.pumpWidget(RecipesApp(controller: controller));
    await tester.pump();

    expect(find.text('Could not reach the repo'), findsOneWidget);
    expect(find.text('Tomato Soup'), findsWidgets);
    expect(find.text('Apple Pie'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('recipe-search')), 'kale');
    await tester.pump();
    expect(find.text('Apple Pie'), findsNothing);
    expect(find.text('Tomato Soup'), findsWidgets);

    await tester.enterText(find.byKey(const Key('recipe-search')), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('recipe-soup')));
    await tester.pump();
    expect(find.byKey(const Key('readonly-banner')), findsOneWidget);
    expect(find.text('1 cup kale'), findsOneWidget);

    await tester.tap(find.byKey(const Key('servings-plus')));
    await tester.pump();
    expect(find.text('1 1/4 cup kale'), findsOneWidget);

    await tester.tap(find.byKey(const Key('print-recipe')));
    await tester.pumpAndSettle();
    expect(find.text('Print view'), findsOneWidget);
    expect(find.text('• 1 1/4 cup kale'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipe-flavorish:pie')));
    await tester.pump();
    expect(find.byKey(const Key('local-banner')), findsOneWidget);
    expect(find.text('Flavorish'), findsWidgets);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pump();
    expect(find.byKey(const Key('fixed-repo')), findsOneWidget);
    expect(find.text('T3ckfr3ak1/recipes · main'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('syncs on launch when that setting is on', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryRecipeStore();
    final remote = FakeRemote(
      index: sampleIndex('2026-10-23T15:00:00Z', const []),
    );
    final controller = _controller(store, AppSettings.defaults, remote);
    await controller.reload();
    await tester.pumpWidget(RecipesApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(remote.indexCalls, 1);
    expect(controller.lastPullAtRaw, '2026-10-23T15:00:00Z');
    expect(find.text('Not synced yet'), findsNothing);
  });

  testWidgets('kitchen opens a note from the repo', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryRecipeStore();
    await store.upsertDoc(
      const RepoDoc(
        path: 'equipment/skillet.md',
        sha: '1',
        kind: RepoKind.equipment,
        title: 'Skillet',
        body: '# Skillet\n\n- Cast iron pan.\n',
      ),
    );
    final controller = _controller(
      store,
      AppSettings.defaults.copyWith(syncOnLaunch: false),
      FakeRemote(index: sampleIndex('2026-01-01T00:00:00Z', const [])),
    );
    await controller.reload();
    await tester.pumpWidget(RecipesApp(controller: controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-kitchen')));
    await tester.pump();
    expect(find.byKey(const Key('kitchen-heading')), findsOneWidget);
    expect(find.text('Skillet'), findsWidgets);

    await tester.tap(find.byKey(const Key('doc-equipment/skillet.md')));
    await tester.pump();
    expect(find.textContaining('Cast iron pan'), findsOneWidget);
  });
}

LibraryController _controller(
  MemoryRecipeStore store,
  AppSettings settings,
  FakeRemote remote,
) {
  return LibraryController(
    store: store,
    remote: remote,
    syncService: SyncService(store: store, remote: remote),
    importer: FlavorishImporter(
      store: store,
      supportDirectory: r'C:\temp\recipes-test',
      mapper: const FlavorishExportMapper(),
    ),
    supportDirectory: r'C:\temp\recipes-test',
    initialSettings: settings,
  );
}
