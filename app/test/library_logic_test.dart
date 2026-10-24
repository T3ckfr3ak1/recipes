import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:recipes/logic/home_cooked.dart';
import 'package:recipes/logic/quantities.dart';
import 'package:recipes/logic/recipe_query.dart';
import 'package:recipes/logic/scaled_recipe.dart';
import 'package:recipes/models/app_settings.dart';
import 'package:recipes/models/ingredient.dart';
import 'package:recipes/models/recipe_mark.dart';
import 'package:recipes/print/recipe_pdf.dart';

import 'support/samples.dart';

void main() {
  test('quantities parse fractions and leave phrases alone', () {
    expect(tryParseQuantity('1/2'), 0.5);
    expect(tryParseQuantity('1 1/2'), 1.5);
    expect(tryParseQuantity('1-1/2'), 1.5);
    expect(tryParseQuantity('½'), 0.5);
    expect(tryParseQuantity('2'), 2);
    expect(tryParseQuantity('to taste'), isNull);
    expect(formatQuantity(0.5), '1/2');
    expect(formatQuantity(1.5), '1 1/2');
    expect(formatQuantity(2), '2');
    expect(formatQuantity(1 / 3), '1/3');
  });

  test(
    'servings scaler preserves the original text until the count changes',
    () {
      final recipe = sampleRecipe(
        id: 'soup',
        servings: 4,
        ingredients: const [
          Ingredient(
            quantity: '1/2',
            unit: 'cup',
            item: 'onion',
            quantityValue: 0.5,
          ),
          Ingredient(quantity: 'pinch', unit: '', item: 'pepper'),
        ],
      );
      final same = scaleRecipe(recipe, 4, QuantityStyle.fraction);
      expect(same.ingredients.first.quantity, '1/2');
      expect(same.isScaled, isFalse);

      final doubled = scaleRecipe(recipe, 8, QuantityStyle.fraction);
      expect(doubled.ingredients.first.line, '1 cup onion');
      expect(doubled.ingredients.last.quantity, 'pinch');
      expect(doubled.leftSomeUnscaled, isTrue);

      final decimal = scaleRecipe(recipe, 6, QuantityStyle.decimal);
      expect(decimal.ingredients.first.quantity, '0.75');
    },
  );

  test('search matches title, ingredient, and tag, then filters combine', () {
    final soup = sampleRecipe(
      id: 'soup',
      title: 'Tomato Soup',
      category: 'Soup',
      tags: const ['comfort'],
      ingredients: const [kale],
      updatedAt: '2026-02-01T00:00:00Z',
    );
    final pie = sampleRecipe(
      id: 'pie',
      title: 'Apple Pie',
      category: 'Dessert',
      tags: const ['bake'],
      ingredients: const [
        Ingredient(quantity: '1', unit: '', item: 'apple', note: 'Honeycrisp'),
      ],
      updatedAt: '2026-05-01T00:00:00Z',
    );
    final recipes = [soup, pie];

    expect(
      applyQuery(recipes, const RecipeQuery(text: 'kale')).single.id,
      'soup',
    );
    expect(
      applyQuery(recipes, const RecipeQuery(text: 'comfort')).single.id,
      'soup',
    );
    expect(
      applyQuery(recipes, const RecipeQuery(text: 'honey')).single.id,
      'pie',
    );
    expect(
      applyQuery(recipes, const RecipeQuery(text: 'apple', category: 'Soup')),
      isEmpty,
    );
    expect(
      applyQuery(
        recipes,
        const RecipeQuery(category: 'Dessert', tag: 'bake'),
      ).single.id,
      'pie',
    );
    expect(
      applyQuery(recipes, const RecipeQuery(tag: 'BAKE')).single.id,
      'pie',
    );
    expect(
      applyQuery(
        recipes,
        const RecipeQuery(sort: RecipeSort.updated),
      ).map((recipe) => recipe.id),
      ['pie', 'soup'],
    );

    const marks = {'soup': RecipeMark(made: true, starred: true)};
    expect(
      applyQuery(
        recipes,
        const RecipeQuery(madeOnly: true, marks: marks),
      ).single.id,
      'soup',
    );
    expect(
      applyQuery(
        recipes,
        const RecipeQuery(starredOnly: true, marks: marks),
      ).single.id,
      'soup',
    );
    final breakfast = sampleRecipe(
      id: 'eggs',
      title: 'Eggs',
      category: 'Breakfast',
    );
    final dinner = sampleRecipe(
      id: 'stew',
      title: 'Stew',
      category: 'Main Course',
      tags: const ['dinner'],
    );
    expect(
      applyQuery([
        breakfast,
        dinner,
        pie,
      ], const RecipeQuery(meal: 'Breakfast')).single.id,
      'eggs',
    );
    expect(
      applyQuery([
        breakfast,
        dinner,
        pie,
      ], const RecipeQuery(meal: 'Dinner')).single.id,
      'stew',
    );
    expect(recipeMatchesMeal(pie, 'Dessert'), isTrue);

    final tagged = [
      for (var i = 0; i < 8; i++)
        sampleRecipe(id: 'often-$i', title: 'Often $i', tags: const ['dinner']),
      sampleRecipe(id: 'once', title: 'Once', tags: const ['rare-tag']),
    ];
    expect(commonTags(tagged), ['dinner']);
    expect(
      isHomeCooked(sampleRecipe(id: 'ns', title: 'Not-Spaghetti')),
      isTrue,
    );
    expect(
      isHomeCooked(
        sampleRecipe(id: 'pork', title: "Joe's Slow Cooker Pulled Pork"),
      ),
      isTrue,
    );
    expect(
      isHomeCooked(sampleRecipe(id: 'other', title: 'Instant Pot Pulled Pork')),
      isFalse,
    );
  });

  test('settings round-trip and pdf bytes', () async {
    final settings = AppSettings.defaults
        .copyWith(timeoutSeconds: 45, themeMode: ThemeMode.dark)
        .toJson();
    final restored = AppSettings.fromJson(settings);
    expect(restored.timeoutSeconds, 45);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.syncOnLaunch, isTrue);

    final regular = File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync();
    final bold = File('assets/fonts/NotoSans-Bold.ttf').readAsBytesSync();
    final bytes = await buildRecipePdf(
      view: scaleRecipe(
        sampleRecipe(id: 'soup', title: 'Jalapeño Soup'),
        4,
        QuantityStyle.fraction,
      ),
      settings: AppSettings.defaults,
      format: PdfPageFormat.letter,
      regularFont: regular,
      boldFont: bold,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
