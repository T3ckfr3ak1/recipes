import '../logic/quantities.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_origin.dart';
import '../time/instants.dart';
import 'page_description.dart';

const _ingredientHeaders = [
  'what you will need',
  'what youll need',
  'what you need',
  'you will need',
  'youll need',
  'ingredients',
  'ingredient',
];

const _stepHeaders = [
  'how to make it',
  'how to cook it',
  'how to prepare it',
  'how to make',
  'how to cook',
  'how to prepare',
  'instructions',
  'instruction',
  'directions',
  'direction',
  'preparation',
  'methods',
  'method',
  'steps',
  'step',
];
final _serves = RegExp(
  r'^(?:serves|servings|yield|makes)\s*[:\-–]?\s*(\d+(?:\.\d+)?)',
  caseSensitive: false,
);
final _prep = RegExp(
  r'^prep(?:\s*time)?\s*[:\-–]?\s*(\d+)\s*(?:mins?|minutes|m)\b',
  caseSensitive: false,
);
final _cook = RegExp(
  r'^(?:cook|cooking)(?:\s*time)?\s*[:\-–]?\s*(\d+)\s*(?:mins?|minutes|m)\b',
  caseSensitive: false,
);
final _quantity = RegExp(
  r'^(\d+-\d+/\d+|\d+\s+\d+/\d+|\d+\s*-\s*\d+(?:\.\d+)?|\d+/\d+|\d+(?:\.\d+)?|[½⅓⅔¼¾⅛⅜⅝⅞])(?:\s+|$)',
);
final _amountThenUnit = RegExp(
  r'(?:\d+\s+\d+/\d+|\d+-\d+/\d+|\d+\s*-\s*\d+(?:\.\d+)?|\d+/\d+|\d+(?:\.\d+)?)\s*(?:tablespoons?|teaspoons?|tbsp|tsp|pounds?|lbs?|lb|ounces?|oz|grams?|kilograms?|kg|milliliters?|ml|liters?|cups?|cloves?|cans?|packages?|sticks?|pinches?|dashes?)',
  caseSensitive: false,
);
final _listMarker = RegExp(r'^(?:[-*•–]|\d+[\.)])\s+');

const _units = [
  'tablespoons',
  'tablespoon',
  'teaspoons',
  'teaspoon',
  'packages',
  'package',
  'milliliters',
  'milliliter',
  'pounds',
  'pound',
  'ounces',
  'ounce',
  'cloves',
  'clove',
  'slices',
  'slice',
  'bunches',
  'bunch',
  'sprigs',
  'sprig',
  'pinches',
  'pinch',
  'dashes',
  'dash',
  'quarts',
  'quart',
  'gallons',
  'gallon',
  'pints',
  'pint',
  'sticks',
  'stick',
  'heads',
  'head',
  'grams',
  'gram',
  'cups',
  'cup',
  'tbsp',
  'tsp',
  'lbs',
  'lb',
  'oz',
  'kg',
  'ml',
  'cans',
  'can',
  'pkg',
  'liters',
  'liter',
  'g',
  'l',
];

/// Builds a recipe when [raw] already contains one. Returns null when the
/// text is only a caption.
Recipe? recipeFromDescription(
  String raw, {
  required DateTime now,
  String subject = '',
  String? pageUrl,
}) {
  final lines = [
    for (final line in layoutDescription(
      raw,
    ).split(RegExp(r'\r?\n|\u2028|\u2029')))
      if (_clean(line).isNotEmpty) _clean(line),
  ];
  if (lines.isEmpty) return null;

  double? servings;
  int? prepMinutes;
  int? cookMinutes;
  final ingredients = <Ingredient>[];
  final steps = <String>[];
  final titleLines = <String>[];
  String? section;

  var sawIngredientHeader = false;
  for (final line in lines) {
    final kind = _section(line);
    if (kind != null) {
      section = kind;
      if (kind == 'ingredients') sawIngredientHeader = true;
      continue;
    }
    final served = _serves.firstMatch(line);
    if (served != null && section == null) {
      servings = double.tryParse(served.group(1)!);
      continue;
    }
    final prep = _prep.firstMatch(line);
    if (prep != null && section == null) {
      prepMinutes = int.tryParse(prep.group(1)!);
      continue;
    }
    final cook = _cook.firstMatch(line);
    if (cook != null && section == null) {
      cookMinutes = int.tryParse(cook.group(1)!);
      continue;
    }
    if (section == 'ingredients') {
      final ingredient = _ingredient(line, requireQuantity: false);
      if (ingredient != null) ingredients.add(ingredient);
      continue;
    }
    if (section == 'steps') {
      final step = _step(line);
      if (step.isNotEmpty) steps.add(step);
      continue;
    }
    titleLines.add(line);
  }

  if (!sawIngredientHeader) {
    ingredients.clear();
    steps.clear();
    titleLines.clear();
    var measuring = false;
    for (final line in lines) {
      if (_serves.hasMatch(line) ||
          _prep.hasMatch(line) ||
          _cook.hasMatch(line)) {
        servings ??= double.tryParse(_serves.firstMatch(line)?.group(1) ?? '');
        prepMinutes ??= int.tryParse(_prep.firstMatch(line)?.group(1) ?? '');
        cookMinutes ??= int.tryParse(_cook.firstMatch(line)?.group(1) ?? '');
        continue;
      }
      final measured = _ingredient(line, requireQuantity: true);
      if (measured != null && steps.isEmpty) {
        measuring = true;
        ingredients.add(measured);
        continue;
      }
      if (measuring) {
        final step = _step(line);
        if (step.isNotEmpty) steps.add(step);
        continue;
      }
      titleLines.add(line);
    }
    if (ingredients.length < 2) return null;
  }

  if (ingredients.isEmpty) return null;

  final title = _title(titleLines, subject);
  final stamp = isoWithOffset(now);
  final instant = parseInstant(stamp);
  final link = pageUrl?.trim() ?? '';
  final note = _notes(raw, link);
  return Recipe(
    id: '',
    title: title,
    servings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    ingredients: ingredients,
    steps: steps,
    source: 'Video description',
    notes: note,
    createdAt: instant,
    updatedAt: instant,
    createdAtRaw: stamp,
    updatedAtRaw: stamp,
    origin: RecipeOrigin.github,
  );
}

/// Keeps one ingredient per line. Also turns `<br>` and escaped newlines
/// into real line breaks when a page flattens the caption.
String layoutDescription(String raw) {
  var text = plainShareText(raw).replaceAll(r'\n', '\n').replaceAll(r'\r', '');
  if (!RegExp(
    r"\bingredients?\b|what you(?:'ll| will)? need",
    caseSensitive: false,
  ).hasMatch(text)) {
    return text;
  }
  text = text.replaceAll(RegExp(r'[ \t]*[•●▪‣∙][ \t]*'), '\n');
  text = text.replaceAllMapped(
    RegExp(
      '(?<!\\n)\\s*((?:ingredients?|instructions?|directions?|methods?|steps?|preparation|how to (?:make|cook|prepare)(?: it)?|what you(?:\'|’)?ll need|what you will need|what you need)\\s*:)',
      caseSensitive: false,
    ),
    (match) => '\n${match.group(1)}\n',
  );
  text = _separateUnits(text);
  final amount = _amountThenUnit.pattern;
  text = text.replaceAll(RegExp('\\s+(?=$amount)', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp('[,;]\\s+(?=$amount)', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(RegExp(r'[ \t]+(?=\d{1,2}[\.)]\s+\S)'), '\n');
  return text;
}

String plainShareText(String raw) {
  var text = raw;
  if (RegExp(
    r'<\s*/?\s*(br|p|div|span|a|html|body)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    text = text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
  }
  return decodeHtmlEntities(text);
}

String _separateUnits(String text) {
  return text.replaceAllMapped(
    RegExp(
      r'(\d)(?=(?:tablespoons?|teaspoons?|tbsp|tsp|pounds?|lbs?|lb|ounces?|oz|grams?|kilograms?|kg|milliliters?|ml|liters?|cups?|cloves?|cans?|packages?)\b)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)} ',
  );
}

String _clean(String line) {
  return line
      .replaceAll(RegExp(r'[*_`]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _section(String line) {
  final letters = line
      .replaceAll(RegExp("[’']"), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  if (letters.isEmpty || letters.length > 48) return null;
  if (_startsHeader(letters, _ingredientHeaders)) return 'ingredients';
  if (_startsHeader(letters, _stepHeaders)) {
    final rest = _headerRest(letters, _stepHeaders);
    if (RegExp(r'\d').hasMatch(rest)) return null;
    if (rest.split(' ').where((word) => word.isNotEmpty).length > 3) {
      return null;
    }
    return 'steps';
  }
  return null;
}

bool _startsHeader(String letters, List<String> headers) {
  for (final header in headers) {
    if (letters == header || letters.startsWith('$header ')) return true;
  }
  return false;
}

String _headerRest(String letters, List<String> headers) {
  for (final header in headers) {
    if (letters == header) return '';
    if (letters.startsWith('$header ')) {
      return letters.substring(header.length).trim();
    }
  }
  return letters;
}

Ingredient? _ingredient(String line, {required bool requireQuantity}) {
  var text = _normalizeFractions(line.replaceFirst(_listMarker, '').trim());
  text = text.replaceFirst(RegExp(r'^[^0-9½⅓⅔¼¾⅛⅜⅝⅞A-Za-z]+'), '').trim();
  if (text.isEmpty) return null;
  final amount = _quantity.firstMatch(text);
  if (amount == null) {
    if (requireQuantity) return null;
    return Ingredient(quantity: '', unit: '', item: text);
  }
  final quantity = amount.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.substring(amount.end).trim();
  var unit = '';
  final lower = text.toLowerCase();
  for (final candidate in _units) {
    final exact = lower == candidate;
    final spaced = lower.startsWith('$candidate ');
    final dotted = lower.startsWith('$candidate.');
    if (!exact && !spaced && !dotted) continue;
    unit = text.substring(0, candidate.length);
    final skip = dotted ? candidate.length + 1 : candidate.length;
    text = text.substring(skip).trim();
    break;
  }
  String? note;
  final parenthetical = RegExp(
    r'^(.*?)(?:\s*\(([^)]*)\))\s*$',
  ).firstMatch(text);
  if (parenthetical != null) {
    text = parenthetical.group(1)!.trim();
    final rawNote = parenthetical.group(2)!.trim();
    if (rawNote.isNotEmpty) note = rawNote;
  }
  if (text.isEmpty) return null;
  return Ingredient(
    quantity: quantity,
    unit: unit,
    item: text,
    note: note,
    quantityValue: tryParseQuantity(quantity),
  );
}

String _normalizeFractions(String text) {
  const symbols = {
    '½': '1/2',
    '⅓': '1/3',
    '⅔': '2/3',
    '¼': '1/4',
    '¾': '3/4',
    '⅛': '1/8',
    '⅜': '3/8',
    '⅝': '5/8',
    '⅞': '7/8',
  };
  var value = text;
  for (final entry in symbols.entries) {
    value = value.replaceAllMapped(
      RegExp('(\\d)\\s*${entry.key}'),
      (match) => '${match.group(1)} ${entry.value}',
    );
    value = value.replaceAll(entry.key, entry.value);
  }
  return value;
}

String _step(String line) {
  return line.replaceFirst(_listMarker, '').trim();
}

String _title(List<String> lines, String subject) {
  for (final line in lines) {
    if (_urlOnly(line)) continue;
    if (line.length > 120) return '${line.substring(0, 120).trim()}…';
    return line;
  }
  final fallback = subject.trim();
  if (fallback.isNotEmpty && !_urlOnly(fallback)) {
    if (fallback.length > 120) return '${fallback.substring(0, 120).trim()}…';
    return fallback;
  }
  return 'Shared recipe';
}

bool _urlOnly(String line) =>
    line.startsWith('http://') || line.startsWith('https://');

String _notes(String raw, String link) {
  final body = raw.trim();
  final clipped = body.length > 2000
      ? '${body.substring(0, 2000).trim()}…'
      : body;
  if (link.isEmpty) return clipped;
  if (clipped.isEmpty) return link;
  return '$link\n\n$clipped';
}
