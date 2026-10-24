import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recipes/sync/http_recipe_remote.dart';
import 'package:recipes/sync/sync_exception.dart';
import 'package:recipes/time/instants.dart';

import 'support/fake_remote.dart';

void main() {
  test('index request is cache-busted and recipe request is not', () async {
    final now = DateTime.utc(2026, 10, 23, 16);
    final client = ScriptedClient((request) async {
      if (request.url.path.endsWith('/index.json')) {
        return http.Response(
          jsonEncode({
            'generated_at': '2026-10-23T16:00:00Z',
            'recipes': [
              {
                'id': 'soup',
                'updated_at': '2026-10-23T15:00:00Z',
                'deleted': false,
                'path': 'recipes/soup.json',
              },
            ],
          }),
          200,
        );
      }
      return http.Response(_recipeJson, 200);
    });
    final remote = HttpRecipeRemote(
      client: client,
      timeout: const Duration(seconds: 5),
    );
    final index = await remote.fetchIndex(now: now);
    final recipe = await remote.fetchRecipe(index.recipes.single);

    expect(
      client.urls.first.queryParameters['t'],
      '${now.millisecondsSinceEpoch}',
    );
    expect(client.urls.first.path, '/T3ckfr3ak1/recipes/main/index.json');
    expect(client.urls.last.path, '/T3ckfr3ak1/recipes/main/recipes/soup.json');
    expect(client.urls.last.query, isEmpty);
    expect(recipe.title, 'Tomato Soup');
    expect(client.lastHeaders.containsKey('authorization'), isFalse);
    expect(
      index.generatedAt.isAtSameMomentAs(
        parseInstant('2026-10-23T11:00:00-05:00'),
      ),
      isTrue,
    );
  });

  test('a saved key is sent with the sync request', () async {
    final client = ScriptedClient((request) async {
      return http.Response(
        jsonEncode({'generated_at': '2026-10-23T16:00:00Z', 'recipes': []}),
        200,
      );
    });
    final remote = HttpRecipeRemote(
      client: client,
      timeout: const Duration(seconds: 5),
    );
    remote.accessToken = 'example-token';
    await remote.fetchIndex(now: DateTime.utc(2026, 10, 23));
    expect(
      client.lastHeaders['authorization'],
      'Bearer example-token',
    );
  });

  test('a failed download becomes a sync error', () async {
    final remote = HttpRecipeRemote(
      client: ScriptedClient((request) async => http.Response('nope', 404)),
      timeout: const Duration(seconds: 5),
    );
    expect(
      () => remote.fetchIndex(now: DateTime.utc(2026)),
      throwsA(
        isA<SyncException>().having(
          (error) => error.message,
          'message',
          contains('HTTP 404'),
        ),
      ),
    );
  });

  test('a hanging download times out', () async {
    final remote = HttpRecipeRemote(
      client: HangingClient(),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      remote.fetchIndex(now: DateTime.utc(2026)),
      throwsA(
        isA<SyncException>().having(
          (error) => error.message,
          'message',
          contains('Timed out'),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('bad recipe json does not look like a recipe', () async {
    final remote = HttpRecipeRemote(
      client: ScriptedClient((request) async => http.Response('{', 200)),
      timeout: const Duration(seconds: 5),
    );
    expect(
      () => remote.fetchRecipe(
        sampleEntry(id: 'soup', updatedAt: '2026-01-01T00:00:00Z'),
      ),
      throwsA(isA<SyncException>()),
    );
  });

  test('the tree request lists blobs and skips directories', () async {
    final client = ScriptedClient(
      (request) async => http.Response(
        jsonEncode({
          'truncated': false,
          'tree': [
            {
              'path': 'equipment/skillet.md',
              'type': 'blob',
              'sha': 'abc',
              'size': 12,
            },
            {'path': 'equipment', 'type': 'tree', 'sha': 'def'},
          ],
        }),
        200,
      ),
    );
    final remote = HttpRecipeRemote(
      client: client,
      timeout: const Duration(seconds: 5),
    );
    final tree = await remote.fetchTree();
    expect(tree.single.path, 'equipment/skillet.md');
    expect(tree.single.sha, 'abc');
    expect(client.urls.single.path, '/repos/T3ckfr3ak1/recipes/git/trees/main');
    expect(client.urls.single.queryParameters['recursive'], '1');
  });
}

const _recipeJson = '''
{
  "id": "soup",
  "title": "Tomato Soup",
  "description": "Smooth",
  "servings": 4,
  "prep_minutes": 10,
  "cook_minutes": 20,
  "ingredients": [{"quantity": "1/2", "unit": "cup", "item": "onion", "note": null}],
  "steps": ["Simmer"],
  "tags": ["comfort"],
  "category": "Soup",
  "source": "Recipe Keeper",
  "notes": "",
  "created_at": "2026-10-23T15:00:00Z",
  "updated_at": "2026-10-23T15:00:00Z",
  "deleted": false
}
''';

final class ScriptedClient extends http.BaseClient {
  ScriptedClient(this.onRequest);

  final Future<http.Response> Function(http.Request request) onRequest;
  final urls = <Uri>[];
  Map<String, String> lastHeaders = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);
    lastHeaders = request.headers;
    final response = await onRequest(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
    );
  }
}

final class HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Future<http.StreamedResponse>.delayed(
      const Duration(milliseconds: 40),
      () => http.StreamedResponse(const Stream.empty(), 200),
    );
  }
}
