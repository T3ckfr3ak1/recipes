import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/db/memory_recipe_store.dart';
import 'package:recipes/db/recipe_store.dart';
import 'package:recipes/models/recipe_origin.dart';
import 'package:recipes/sync/sync_exception.dart';
import 'package:recipes/sync/sync_service.dart';

import 'support/fake_remote.dart';
import 'support/samples.dart';

void main() {
  late MemoryRecipeStore store;

  setUp(() {
    store = MemoryRecipeStore();
  });

  test('an empty cursor pulls every recipe and stores generated_at', () async {
    final clock = DateTime.utc(2026, 10, 23, 18);
    final soup = sampleRecipe(
      id: 'soup',
      title: 'Tomato',
      updatedAt: '2026-01-02T00:00:00Z',
    );
    final remote = FakeRemote(
      index: sampleIndex('2026-10-23T10:47:41-05:00', [
        sampleEntry(id: 'soup', updatedAt: '2026-01-02T00:00:00Z'),
      ]),
      byPath: {'recipes/soup.json': soup},
    );
    final result = await SyncService(
      store: store,
      remote: remote,
    ).sync(now: clock);

    expect(result.advanced, isTrue);
    expect(result.upserted, 1);
    expect(
      await store.getMeta(MetaKeys.lastPullAt),
      '2026-10-23T10:47:41-05:00',
    );
    expect(await store.getMeta(MetaKeys.lastSyncError), isNull);
    expect((await store.allRecipes()).single.title, 'Tomato');
    expect(remote.fetched, ['recipes/soup.json']);
    expect(remote.seenNow, clock);
  });

  test(
    'fetches an offset timestamp that is later even when the string looks older',
    () async {
      await store.setMeta(MetaKeys.lastPullAt, '2026-01-01T00:00:00Z');
      await store.upsertGithubRecipe(
        sampleRecipe(id: 'old', updatedAt: '2025-06-01T00:00:00Z'),
      );
      final olderLooking = sampleRecipe(
        id: 'chili',
        updatedAt: '2025-12-31T20:00:00-05:00',
      );
      final remote = FakeRemote(
        index: sampleIndex('2026-02-01T00:00:00Z', [
          sampleEntry(id: 'chili', updatedAt: '2025-12-31T20:00:00-05:00'),
          sampleEntry(id: 'old', updatedAt: '2025-06-01T00:00:00Z'),
        ]),
        byPath: {'recipes/chili.json': olderLooking},
      );

      final result = await SyncService(store: store, remote: remote).sync();

      expect(result.advanced, isTrue);
      expect(remote.fetched, ['recipes/chili.json']);
      expect(
        (await store.allRecipes()).map((recipe) => recipe.id),
        containsAll(['old', 'chili']),
      );
    },
  );

  test(
    'does not fetch a recipe at the same instant with a different offset',
    () async {
      await store.setMeta(MetaKeys.lastPullAt, '2026-06-01T12:00:00Z');
      await store.upsertGithubRecipe(
        sampleRecipe(id: 'same', updatedAt: '2026-06-01T08:00:00-04:00'),
      );
      final remote = FakeRemote(
        index: sampleIndex('2026-07-01T00:00:00Z', [
          sampleEntry(id: 'same', updatedAt: '2026-06-01T08:00:00-04:00'),
          sampleEntry(id: 'next', updatedAt: '2026-06-01T08:00:01-04:00'),
        ]),
        byPath: {
          'recipes/next.json': sampleRecipe(
            id: 'next',
            updatedAt: '2026-06-01T08:00:01-04:00',
          ),
        },
      );

      await SyncService(store: store, remote: remote).sync();

      expect(remote.fetched, ['recipes/next.json']);
    },
  );

  test(
    'fetches a recipe that is not stored locally even when it is older than the cursor',
    () async {
      await store.setMeta(MetaKeys.lastPullAt, '2026-10-23T16:00:00Z');
      await store.upsertGithubRecipe(
        sampleRecipe(id: 'kept', updatedAt: '2026-01-01T00:00:00Z'),
      );
      final remote = FakeRemote(
        index: sampleIndex('2026-10-23T18:00:00Z', [
          sampleEntry(id: 'kept', updatedAt: '2026-01-01T00:00:00Z'),
          sampleEntry(id: 'chili', updatedAt: '2026-08-01T00:00:00Z'),
        ]),
        byPath: {
          'recipes/chili.json': sampleRecipe(
            id: 'chili',
            title: 'Chili',
            updatedAt: '2026-08-01T00:00:00Z',
          ),
        },
      );

      final result = await SyncService(store: store, remote: remote).sync();

      expect(result.advanced, isTrue);
      expect(remote.fetched, ['recipes/chili.json']);
      expect(
        (await store.allRecipes()).map((recipe) => recipe.id),
        containsAll(['kept', 'chili']),
      );
    },
  );

  test('removes deleted github recipes and keeps the cursor', () async {
    await store.upsertGithubRecipe(sampleRecipe(id: 'soup', title: 'Old'));
    final remote = FakeRemote(
      index: sampleIndex('2026-08-01T00:00:00Z', [
        sampleEntry(
          id: 'soup',
          updatedAt: '2026-08-01T00:00:00Z',
          deleted: true,
        ),
      ]),
      byPath: {
        'recipes/soup.json': sampleRecipe(
          id: 'soup',
          deleted: true,
          updatedAt: '2026-08-01T00:00:00Z',
        ),
      },
    );

    final result = await SyncService(store: store, remote: remote).sync();

    expect(result.removed, 1);
    expect(result.advanced, isTrue);
    expect(await store.allRecipes(), isEmpty);
  });

  test(
    'a failed recipe download keeps the cursor and the recipes that did save',
    () async {
      await store.setMeta(MetaKeys.lastPullAt, '2026-01-01T00:00:00Z');
      final remote = FakeRemote(
        index: sampleIndex('2026-09-01T00:00:00Z', [
          sampleEntry(id: 'ok', updatedAt: '2026-03-01T00:00:00Z'),
          sampleEntry(id: 'bad', updatedAt: '2026-03-02T00:00:00Z'),
        ]),
        byPath: {
          'recipes/ok.json': sampleRecipe(
            id: 'ok',
            title: 'Saved',
            updatedAt: '2026-03-01T00:00:00Z',
          ),
          'recipes/bad.json': SyncException('socket down'),
        },
      );

      final result = await SyncService(store: store, remote: remote).sync();

      expect(result.advanced, isFalse);
      expect(result.upserted, 1);
      expect(await store.getMeta(MetaKeys.lastPullAt), '2026-01-01T00:00:00Z');
      expect((await store.getMeta(MetaKeys.lastSyncError))!, contains('bad'));
      expect((await store.allRecipes()).single.title, 'Saved');

      remote.byPath = {
        'recipes/ok.json': sampleRecipe(
          id: 'ok',
          title: 'Saved',
          updatedAt: '2026-03-01T00:00:00Z',
        ),
        'recipes/bad.json': sampleRecipe(
          id: 'bad',
          title: 'Recovered',
          updatedAt: '2026-03-02T00:00:00Z',
        ),
      };
      final again = await SyncService(store: store, remote: remote).sync();
      expect(again.advanced, isTrue);
      expect(await store.getMeta(MetaKeys.lastPullAt), '2026-09-01T00:00:00Z');
      expect(await store.getMeta(MetaKeys.lastSyncError), isNull);
      expect(
        (await store.allRecipes()).map((recipe) => recipe.id),
        containsAll(['ok', 'bad']),
      );
    },
  );

  test('an index failure leaves local recipes and the cursor alone', () async {
    await store.setMeta(MetaKeys.lastPullAt, '2026-01-01T00:00:00Z');
    await store.upsertGithubRecipe(
      sampleRecipe(id: 'soup', title: 'Local copy'),
    );
    final remote = FakeRemote(
      index: sampleIndex('2026-10-01T00:00:00Z', const []),
      indexError: SyncException('offline'),
    );

    final result = await SyncService(store: store, remote: remote).sync();

    expect(result.advanced, isFalse);
    expect(remote.fetched, isEmpty);
    expect(await store.getMeta(MetaKeys.lastPullAt), '2026-01-01T00:00:00Z');
    expect((await store.allRecipes()).single.title, 'Local copy');
    expect(await store.getMeta(MetaKeys.lastSyncError), 'offline');
  });

  test('an empty index still advances the cursor', () async {
    final result = await SyncService(
      store: store,
      remote: FakeRemote(
        index: sampleIndex('2026-10-23T10:47:41-05:00', const []),
      ),
    ).sync();

    expect(result.advanced, isTrue);
    expect(result.fetched, 0);
    expect(
      await store.getMeta(MetaKeys.lastPullAt),
      '2026-10-23T10:47:41-05:00',
    );
  });

  test('github sync does not delete or overwrite a flavorish recipe', () async {
    await store.insertLocalRecipe(
      sampleRecipe(
        id: 'flavorish:abc',
        title: 'Chili',
        flavorishId: 'abc',
        origin: RecipeOrigin.local,
        source: 'Blog',
      ),
    );
    await store.insertLocalRecipe(
      sampleRecipe(
        id: 'shared',
        title: 'Keep mine',
        flavorishId: 'shared-id',
        origin: RecipeOrigin.local,
      ),
    );
    final remote = FakeRemote(
      index: sampleIndex('2026-10-01T00:00:00Z', [
        sampleEntry(
          id: 'flavorish:abc',
          updatedAt: '2026-10-01T00:00:00Z',
          deleted: true,
        ),
        sampleEntry(
          id: 'abc',
          updatedAt: '2026-10-01T00:00:00Z',
          deleted: true,
        ),
        sampleEntry(id: 'shared', updatedAt: '2026-10-01T00:00:00Z'),
      ]),
      byPath: {
        'recipes/flavorish:abc.json': sampleRecipe(
          id: 'flavorish:abc',
          deleted: true,
          updatedAt: '2026-10-01T00:00:00Z',
        ),
        'recipes/abc.json': sampleRecipe(
          id: 'abc',
          deleted: true,
          updatedAt: '2026-10-01T00:00:00Z',
        ),
        'recipes/shared.json': sampleRecipe(
          id: 'shared',
          title: 'From GitHub',
          updatedAt: '2026-10-01T00:00:00Z',
        ),
      },
    );

    final result = await SyncService(store: store, remote: remote).sync();

    expect(result.advanced, isFalse);
    final titles = {
      for (final recipe in await store.allRecipes()) recipe.id: recipe.title,
    };
    expect(titles['flavorish:abc'], 'Chili');
    expect(titles['shared'], 'Keep mine');
    expect(await store.getMeta(MetaKeys.lastPullAt), isNull);
    expect(
      (await store.allRecipes()).map((recipe) => recipe.source),
      everyElement('Flavorish'),
    );
  });

  test('a recipe id that does not match the index is not saved', () async {
    final remote = FakeRemote(
      index: sampleIndex('2026-04-01T00:00:00Z', [
        sampleEntry(id: 'expected', updatedAt: '2026-04-01T00:00:00Z'),
      ]),
      byPath: {
        'recipes/expected.json': sampleRecipe(id: 'other', title: 'Nope'),
      },
    );

    final result = await SyncService(store: store, remote: remote).sync();

    expect(result.advanced, isFalse);
    expect(await store.allRecipes(), isEmpty);
    expect(await store.getMeta(MetaKeys.lastPullAt), isNull);
  });
}
