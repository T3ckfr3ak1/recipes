import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/db/recipe_store.dart';
import 'package:recipes/import/flavorish_export_mapper.dart';
import 'package:recipes/import/flavorish_importer.dart';
import 'package:recipes/main.dart';
import 'package:recipes/models/app_settings.dart';
import 'package:recipes/models/meal_plan.dart';
import 'package:recipes/state/library_controller.dart';
import 'package:recipes/sync/sync_service.dart';

import 'support/fake_remote.dart';
import 'support/samples.dart';

void main() {
  test('assignments round-trip and replace the same meal', () {
    const raw = '''
{"assignments":[
  {"date":"2026-10-19","slot":"dinner","recipe_id":"soup"},
  {"date":"nope","slot":"lunch","recipe_id":"pie"},
  {"date":"2026-10-20","slot":"brunch","recipe_id":"pie"}
]}
''';
    final plan = MealPlan.parse(raw);
    expect(plan.recipeIdFor(DateTime(2026, 10, 19), MealSlot.dinner), 'soup');
    expect(plan.assignments, hasLength(1));

    final replaced = plan.assign(
      DateTime(2026, 10, 19, 15),
      MealSlot.dinner,
      'chili',
    );
    expect(
      replaced.recipeIdFor(DateTime(2026, 10, 19), MealSlot.dinner),
      'chili',
    );
    final cleared = replaced.assign(
      DateTime(2026, 10, 19),
      MealSlot.dinner,
      null,
    );
    expect(
      cleared.recipeIdFor(DateTime(2026, 10, 19), MealSlot.dinner),
      isNull,
    );
    expect(MealPlan.parse('not json').assignments, isEmpty);
    expect(startOfWeek(DateTime(2026, 10, 23)), DateTime(2026, 10, 19));
  });

  testWidgets('a week can be filled from the library and kept', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryRecipeStore();
    await store.upsertGithubRecipe(
      sampleRecipe(id: 'soup', title: 'Tomato Soup'),
    );
    final controller = LibraryController(
      store: store,
      remote: FakeRemote(index: sampleIndex('2026-01-01T00:00:00Z', const [])),
      syncService: SyncService(
        store: store,
        remote: FakeRemote(
          index: sampleIndex('2026-01-01T00:00:00Z', const []),
        ),
      ),
      importer: FlavorishImporter(
        store: store,
        supportDirectory: r'C:\temp\recipes-test',
        mapper: const FlavorishExportMapper(),
      ),
      supportDirectory: r'C:\temp\recipes-test',
      initialSettings: AppSettings.defaults.copyWith(syncOnLaunch: false),
    );
    await controller.reload();
    controller.showWeek(DateTime(2026, 10, 19));

    await tester.pumpWidget(RecipesApp(controller: controller));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-meal-plan')));
    await tester.pump();

    expect(find.byKey(const Key('meal-plan-heading')), findsOneWidget);
    expect(find.text('Meal plan'), findsWidgets);
    expect(find.byKey(const Key('meal-week-label')), findsOneWidget);
    expect(find.text('Oct 19 – 25, 2026'), findsOneWidget);
    expect(find.text('Monday, Oct 19'), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal-add-2026-10-19-breakfast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal-pick-soup')));
    await tester.pumpAndSettle();

    expect(find.text('Tomato Soup'), findsOneWidget);
    expect(await store.getMeta(MetaKeys.mealPlan), contains('soup'));

    await tester.tap(find.byKey(const Key('meal-open-2026-10-19-breakfast')));
    await tester.pump();
    expect(find.byKey(const Key('recipe-soup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-meal-plan')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('meal-clear-2026-10-19-breakfast')));
    await tester.pump();
    expect(
      find.byKey(const Key('meal-add-2026-10-19-breakfast')),
      findsOneWidget,
    );
  });
}
