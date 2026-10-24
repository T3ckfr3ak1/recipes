import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recipes/models/ingredient.dart';
import 'package:recipes/models/recipe_origin.dart';
import 'package:recipes/sync/github_publisher.dart';
import 'package:recipes/sync/github_token.dart';
import 'package:recipes/sync/keeper_document.dart';
import 'package:recipes/time/instants.dart';

import 'support/samples.dart';

void main() {
  test(
    'a video recipe keeps its source and a flavorish recipe is marked',
    () async {
      final client = _GitHub();
      final publisher = FlavorishRepoPublisher(
        client: client,
        token: 'example-token',
      );
      final now = DateTime.utc(2026, 10, 23, 15, 4, 5);
      final stamp = isoWithOffset(now);
      await publisher.publish([
        sampleRecipe(
          id: 'honey-garlic-chicken',
          title: 'Honey garlic chicken',
          source: 'Video description',
          ingredients: const [
            Ingredient(quantity: '1', unit: 'lb', item: 'chicken'),
          ],
          createdAt: stamp,
          updatedAt: stamp,
        ),
        sampleRecipe(
          id: 'flavorish:abc',
          title: 'Chili',
          flavorishId: 'abc',
          origin: RecipeOrigin.local,
          source: 'Somewhere',
          createdAt: stamp,
          updatedAt: stamp,
        ),
      ], supportDirectory: r'C:\temp\recipes-test');

      expect(
        client.calls.first.headers['authorization'],
        'Basic ${base64Encode(utf8.encode('T3ckfr3ak1:example-token'))}',
      );
      final tree = client.calls.lastWhere(
        (call) => call.path.endsWith('/git/trees'),
      );
      final treeBody = jsonDecode(tree.body) as Map<String, Object?>;
      final entries = treeBody['tree'] as List<Object?>;
      final paths = [for (final entry in entries) (entry as Map)['path']];
      expect(paths, contains('recipes/honey-garlic-chicken.json'));
      expect(paths, contains('recipes/abc.json'));
      expect(paths, contains('index.json'));

      final honey = _recipeFile(
        client,
        entries,
        'recipes/honey-garlic-chicken.json',
      );
      final chili = _recipeFile(client, entries, 'recipes/abc.json');
      expect(honey['source'], 'Video description');
      expect(honey['title'], 'Honey garlic chicken');
      expect(chili['source'], 'Flavorish');
      expect(chili['id'], 'abc');

      final indexEntry = entries.cast<Map<Object?, Object?>>().singleWhere(
        (entry) => entry['path'] == 'index.json',
      );
      final indexSha = indexEntry['sha'] as String;
      final index =
          jsonDecode(utf8.decode(base64.decode(client.blobs[indexSha]!)))
              as Map<String, Object?>;
      final recipes = index['recipes'] as List<Object?>;
      expect(recipes, hasLength(2));
      expect(index['generated_at'], matches(RegExp(r'[+-]\d{2}:\d{2}$')));
    },
  );

  test('a rejected key is reported', () async {
    final publisher = FlavorishRepoPublisher(
      client: _GitHub(status: 401),
      token: 'example-token',
    );
    expect(
      () => publisher.publish([
        sampleRecipe(
          id: 'soup',
          title: 'Soup',
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2026-01-01T00:00:00Z',
        ),
      ], supportDirectory: r'C:\temp\recipes-test'),
      throwsA(
        isA<GithubPublishException>().having(
          (error) => error.message,
          'message',
          contains('rejected'),
        ),
      ),
    );
  });

  test('a taken title gets the next id', () {
    expect(uniqueRecipeId('Soup', {'soup'}), 'soup-2');
    expect(uniqueRecipeId('Soup!', {}), 'soup');
  });
}

Map<String, Object?> _recipeFile(
  _GitHub client,
  List<Object?> entries,
  String path,
) {
  final entry = entries.cast<Map<Object?, Object?>>().singleWhere(
    (item) => item['path'] == path,
  );
  final sha = entry['sha'] as String;
  return jsonDecode(utf8.decode(base64.decode(client.blobs[sha]!)))
      as Map<String, Object?>;
}

final class _Call {
  _Call({required this.path, required this.headers, required this.body});

  final String path;
  final Map<String, String> headers;
  final String body;
}

final class _GitHub extends http.BaseClient {
  _GitHub({this.status = 200});

  final int status;
  final calls = <_Call>[];
  final blobs = <String, String>{};
  var _blobs = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    calls.add(_Call(path: req.url.path, headers: req.headers, body: req.body));
    final payload = _payload(req);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(payload)),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }

  String _payload(http.Request request) {
    if (status == 401) return '{"message":"no"}';
    final path = request.url.path;
    if (path.endsWith('/contents/README.md')) {
      return _file(
        '# Recipes\n\nThe Windows recipe app reads this repo and publishes every recipe here, including Flavorish imports.\n\n- `images/` holds optional photos.\n',
      );
    }
    if (path.endsWith('/contents/index.json')) {
      return _file('''
{
  "generated_at": "2026-01-01T00:00:00Z",
  "recipes": []
}
''');
    }
    if (path.endsWith('/git/ref/heads/main')) {
      return '{"object":{"sha":"parent-sha"}}';
    }
    if (path.endsWith('/git/commits/parent-sha')) {
      return '{"tree":{"sha":"base-tree"}}';
    }
    if (path.endsWith('/git/blobs')) {
      _blobs++;
      final sha = 'blob-$_blobs';
      final body = jsonDecode(request.body) as Map<String, Object?>;
      blobs[sha] = body['content'] as String;
      return '{"sha":"$sha"}';
    }
    if (path.endsWith('/git/trees')) return '{"sha":"tree-sha"}';
    if (path.endsWith('/git/commits')) return '{"sha":"commit-sha"}';
    return '{}';
  }

  String _file(String text) {
    return jsonEncode({
      'content': base64Encode(utf8.encode(text)),
      'encoding': 'base64',
    });
  }
}
