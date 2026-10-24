import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/logic/markdown_doc.dart';
import 'package:recipes/logic/meal_pack.dart';
import 'package:recipes/models/repo_doc.dart';
import 'package:recipes/sync/repo_library_sync.dart';
import 'package:recipes/sync/repo_tree.dart';
import 'package:recipes/sync/sync_exception.dart';

import 'support/fake_remote.dart';

void main() {
  test('meal pack days link to recipe ids', () {
    const body = '''
# Joe's Meal Plan

## The Meal Plan

| Day | Breakfast | Lunch | Dinner | Recipes |
|---|---|---|---|---|
| Tue Oct 20 | | | Hot deli | R1 |
| Fri Oct 23 (gf over) | | Extra pizza | Alfredo | R6, R9 |
| Sun Nov 1 | | Nachos | Burgers | R21 |

Snacks and drinks: Utz Pub Mix.

## Recipe ids

| Pack # | Recipe | Recipe file |
|---|---|---|
| R1 | Hot Deli | [`recipes/aaa.json`](../recipes/aaa.json) |
| R6 | Frozen Pizzas | [`recipes/bbb.json`](../recipes/bbb.json) |
| R9 | Alfredo | [`recipes/ccc.json`](../recipes/ccc.json) |
| R21 | Nachos | [`recipes/ddd.json`](../recipes/ddd.json) |
''';
    final pack = parseMealPack(
      const RepoDoc(
        path: 'meal-plan/2026-10-20_to_2026-11-04.md',
        sha: '1',
        kind: RepoKind.mealPlan,
        title: "Joe's Meal Plan",
        body: body,
      ),
    );
    expect(pack.start, DateTime(2026, 10, 20));
    expect(pack.end, DateTime(2026, 11, 4));
    expect(pack.days, hasLength(3));
    expect(pack.days.first.dinner, 'Hot deli');
    expect(pack.days.first.date, DateTime(2026, 10, 20));
    expect(pack.days[1].date, DateTime(2026, 10, 23));
    expect(pack.days[1].codes, ['R6', 'R9']);
    expect(pack.days.last.date, DateTime(2026, 11, 1));
    expect(pack.recipeFor('R6')?.recipeId, 'bbb');
    expect(pack.recipeFor('R1')?.title, 'Hot Deli');
    expect(pack.snacks, startsWith('Snacks'));
    expect(recipeIdFromHref('../recipes/bbb.json'), 'bbb');
    expect(kindForPath('equipment/../secret.md'), isNull);
    expect(kindForPath('methods/oven.md'), RepoKind.method);
  });

  test('markdown keeps headings, quotes, and links', () {
    final blocks = parseMarkdown('''
# Skillet

- **Cast iron**

> Joe said so

See [the method](methods/oven.md).
''');
    expect(blocks.first, isA<MdHeading>());
    expect(spanText((blocks[1] as MdBullet).spans), 'Cast iron');
    expect(blocks[2], isA<MdQuote>());
    final paragraph = blocks[3] as MdParagraph;
    expect(paragraph.spans.whereType<MdLink>().single.href, 'methods/oven.md');
  });

  test('a truncated repo listing is refused', () {
    expect(
      () => parseRepoTree('{"truncated":true,"tree":[]}'),
      throwsA(isA<SyncException>()),
    );
  });

  test(
    'notes sync downloads, skips an unchanged sha, and drops removals',
    () async {
      final root = await Directory.systemTemp.createTemp('recipes-notes');
      addTearDown(() => root.delete(recursive: true));
      final store = MemoryRecipeStore();
      await store.upsertDoc(
        const RepoDoc(
          path: 'methods/old.md',
          sha: 'old',
          kind: RepoKind.method,
          title: 'Old',
          body: 'gone',
        ),
      );
      const skillet = '# Skillet\n\n- Cast iron.\n';
      final remote = FakeRemote(
        index: sampleIndex('2026-01-01T00:00:00Z', const []),
        tree: const [
          RepoBlob(path: 'equipment/skillet.md', sha: 'sha-1', size: 20),
          RepoBlob(path: 'meal-plan/pack.pdf', sha: 'pdf-1', size: 4),
          RepoBlob(path: 'recipes/soup.json', sha: 'nope'),
        ],
        byPath: {
          'equipment/skillet.md': skillet,
          'meal-plan/pack.pdf': [1, 2, 3, 4],
        },
      );
      final sync = RepoLibrarySync(
        store: store,
        remote: remote,
        supportDirectory: root.path,
      );

      expect(await sync.sync(), isEmpty);
      final docs = await store.allDocs();
      expect(docs.map((doc) => doc.path), [
        'equipment/skillet.md',
        'meal-plan/pack.pdf',
      ]);
      expect(
        docs.singleWhere((doc) => doc.path.endsWith('.md')).title,
        'Skillet',
      );
      final pdf = docs.singleWhere((doc) => doc.kind == RepoKind.mealPdf);
      final file = File(
        '${root.path}/${pdf.filePath!.replaceAll('/', Platform.pathSeparator)}',
      );
      expect(await file.readAsBytes(), [1, 2, 3, 4]);

      remote.fetched.clear();
      expect(await sync.sync(), isEmpty);
      expect(remote.fetched, isEmpty);

      remote.tree = [
        const RepoBlob(path: 'equipment/skillet.md', sha: 'sha-2', size: 20),
      ];
      remote.byPath['equipment/skillet.md'] = '# Skillet\n\n- Updated.\n';
      expect(await sync.sync(), isEmpty);
      expect(remote.fetched, ['equipment/skillet.md']);
      expect(await store.allDocs(), hasLength(1));
      expect(await file.exists(), isFalse);
    },
  );

  test('a failed listing leaves saved notes alone', () async {
    final store = MemoryRecipeStore();
    await store.upsertDoc(
      const RepoDoc(
        path: 'preferences/food-preferences.md',
        sha: '1',
        kind: RepoKind.preference,
        title: 'Preferences',
        body: 'likes',
      ),
    );
    final sync = RepoLibrarySync(
      store: store,
      remote: FakeRemote(
        index: sampleIndex('2026-01-01T00:00:00Z', const []),
        treeError: SyncException('offline'),
      ),
      supportDirectory: Directory.systemTemp.path,
    );
    expect(sync.sync(), throwsA(isA<SyncException>()));
    expect((await store.allDocs()).single.title, 'Preferences');
  });
}
