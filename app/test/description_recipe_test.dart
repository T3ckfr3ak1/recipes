import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/share/description_recipe.dart';
import 'package:recipes/share/incoming_share.dart';
import 'package:recipes/share/page_description.dart';
import 'package:recipes/share/share_resolver.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 16);

  test('a headed description becomes a recipe', () {
    final recipe = recipeFromDescription('''
Crispy honey garlic chicken

Serves 4
Prep: 10 min
Cook: 20 minutes

Ingredients
1 lb chicken thighs
2 tbsp honey
3 cloves garlic (minced)

Instructions
1. Mix the honey and garlic.
2. Cook the chicken until crisp.
''', now: now);

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Crispy honey garlic chicken');
    expect(recipe.servings, 4);
    expect(recipe.prepMinutes, 10);
    expect(recipe.cookMinutes, 20);
    expect(recipe.ingredients.map((item) => item.item), [
      'chicken thighs',
      'honey',
      'garlic',
    ]);
    expect(recipe.ingredients[1].quantity, '2');
    expect(recipe.ingredients[1].unit, 'tbsp');
    expect(recipe.ingredients[2].note, 'minced');
    expect(recipe.steps, [
      'Mix the honey and garlic.',
      'Cook the chicken until crisp.',
    ]);
    expect(recipe.source, 'Video description');
  });

  test('measured lines without headings are still a recipe', () {
    final recipe = recipeFromDescription('''
Garlic noodles
1 lb noodles
2 tbsp soy sauce
3 cloves garlic
1. Boil the noodles.
2. Toss with the soy and garlic.
''', now: now);

    expect(recipe!.title, 'Garlic noodles');
    expect(recipe.ingredients, hasLength(3));
    expect(recipe.steps, hasLength(2));
  });

  test('a caption with no recipe is left alone', () {
    expect(
      recipeFromDescription('Love this reel. Save it for later.', now: now),
      isNull,
    );
  });

  test('a share splits the caption from the reel link', () {
    const share = IncomingShare(
      text: '''
Crispy chicken

Ingredients
1 lb chicken
2 tbsp honey

Instructions
Cook it.

https://www.facebook.com/reel/12345.
''',
      subject: 'Reel',
    );

    expect(share.url, 'https://www.facebook.com/reel/12345');
    expect(share.caption, contains('1 lb chicken'));
    expect(share.caption, isNot(contains('facebook.com')));
  });

  test('the page description is used when the share is only a link', () async {
    final pages = _Pages('''
Soup

Ingredients
1 cup broth
2 carrots

Steps
Simmer.
''');
    final resolution = await ShareResolver(
      pages: pages,
      clock: () => now,
    ).resolve(const IncomingShare(text: 'https://fb.watch/abc'));

    expect(pages.lookups, ['https://fb.watch/abc']);
    expect(resolution.recipe!.title, 'Soup');
    expect(resolution.recipe!.notes, contains('https://fb.watch/abc'));
  });

  test('a link whose page has no recipe is not saved', () async {
    final resolution = await ShareResolver(
      pages: _Pages('Watch more reels on Facebook.'),
      clock: () => now,
    ).resolve(const IncomingShare(text: 'https://www.facebook.com/reel/9'));

    expect(resolution.recipe, isNull);
    expect(resolution.detail, contains("didn't include an ingredient list"));
  });

  test('each ingredient on its own line is a recipe', () {
    final recipe = recipeFromDescription('''
Honey garlic chicken

Ingredients:
▪️ 1 lb chicken thighs
▪️ 2 tbsp honey
▪️ 3 cloves garlic

Instructions:
1. Mix the honey and garlic.
2. Cook the chicken until crisp.
''', now: now);

    expect(recipe, isNotNull);
    expect(recipe!.ingredients.map((item) => item.item), [
      'chicken thighs',
      'honey',
      'garlic',
    ]);
    expect(recipe.steps, hasLength(2));
  });

  test('another recipe elsewhere on the page is ignored', () {
    const html = r'''
      <meta property="og:description" content="Honey garlic chicken&#10;&#10;Ingredients:&#10;1 lb chicken thighs&#10;2 tbsp honey&#10;3 cloves garlic&#10;&#10;Instructions:&#10;1. Mix the honey and garlic.&#10;2. Cook until crisp.">
      <script>{"message":{"text":"Beef stew\n\nIngredients:\n1 lb beef\n2 cups broth\nInstructions:\nSimmer."}}</script>
    ''';
    final description = descriptionFromHtml(html)!;
    expect(description, contains('chicken thighs'));
    expect(description, isNot(contains('beef')));
    final recipe = recipeFromDescription(description, now: now);
    expect(recipe!.ingredients.map((item) => item.item), [
      'chicken thighs',
      'honey',
      'garlic',
    ]);
  });

  test('a shared title is not replaced with a different recipe', () async {
    final resolution =
        await ShareResolver(
          pages: _Pages('''
Beef stew

Ingredients
1 lb beef
2 cups broth

Steps
Simmer.
'''),
          clock: () => now,
        ).resolve(
          const IncomingShare(
            text: 'Croissant tacos\nhttps://www.facebook.com/reel/1',
          ),
        );

    expect(resolution.recipe, isNull);
    expect(resolution.detail, contains('different recipe'));
  });

  test('og:description is read from the page', () {
    const html = '''
      <html><head>
        <meta property="og:description" content="1 lb &amp; 2 tbsp &quot;honey&quot;">
        <meta name="description" content="ignored">
      </head></html>
    ''';
    expect(descriptionFromHtml(html), '1 lb & 2 tbsp "honey"');
  });

  test('content can come before property on the meta tag', () {
    const html =
        '''<meta content="Simmer the soup." property="og:description">''';
    expect(descriptionFromHtml(html), 'Simmer the soup.');
  });
}

final class _Pages implements PageDescription {
  _Pages(this.body);

  final String? body;
  final lookups = <String>[];

  @override
  Future<String?> lookup(Uri url) async {
    lookups.add(url.toString());
    return body;
  }
}
