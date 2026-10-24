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
  r'^(?:serves|servings|yield|makes)\s*[:\-–]?\s*(\d+(?:\.\d+)?)(?:\s*(?:to|-|–)\s*\d+(?:\.\d+)?)?',
  caseSensitive: false,
);
final _duration = RegExp(
  r'(?:^|\|)\s*(prep|cook|cooking)(?:\s*time)?\s*[:\-–]?\s*'
  r'(\d+(?:\s+\d+/\d+)?|\d+/\d+)'
  r'(?:\s*(?:to|-|–)\s*(?:\d+(?:\s+\d+/\d+)?|\d+/\d+))?\s*'
  r'(minutes|mins?|hours?|hrs?|hr|h|m)\b',
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
  'kilograms',
  'kilogram',
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
  var mode = 'open';
  var sawIngredientHeader = false;

  for (final line in lines) {
    if (_isNoise(line)) continue;
    final labeled = _labeledGroup(line);
    if (labeled != null) {
      if (labeled.kind == 'steps') {
        mode = 'steps';
        if (labeled.body.isNotEmpty) steps.add(labeled.body);
      } else {
        mode = 'ingredients';
        sawIngredientHeader = true;
        final body = _ingredient(labeled.body, requireQuantity: true);
        if (body != null) ingredients.add(body);
      }
      continue;
    }
    final kind = _section(line);
    if (kind == 'ingredients') {
      mode = 'ingredients';
      sawIngredientHeader = true;
      continue;
    }
    if (kind == 'steps') {
      mode = 'steps';
      continue;
    }
    if (mode != 'steps' &&
        _readMeta(
          line,
          servings: (value) => servings = value,
          prepMinutes: (value) => prepMinutes = value,
          cookMinutes: (value) => cookMinutes = value,
        )) {
      continue;
    }
    if (mode == 'steps') {
      final step = _step(line);
      if (step.isNotEmpty) steps.add(step);
      continue;
    }
    final measured = _ingredient(line, requireQuantity: true);
    if (measured != null) {
      mode = 'ingredients';
      ingredients.add(measured);
      continue;
    }
    if (mode == 'ingredients' && _isBareIngredient(line)) {
      final bare = _ingredient(line, requireQuantity: false);
      if (bare != null) ingredients.add(bare);
      continue;
    }
    if (mode == 'ingredients') {
      final step = _step(line);
      if (step.isNotEmpty) {
        mode = 'steps';
        steps.add(step);
      }
      continue;
    }
    titleLines.add(line);
  }

  if (!sawIngredientHeader && ingredients.length < 2) return null;
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
  text = text.replaceAllMapped(
    RegExp(
      r'(?<=\s)((?:[A-Za-z][\w,]*|\d+/\d+)(?:\s+(?:[A-Za-z][\w,]*|\d+/\d+)){0,3}\s+\d+(?:\.\d+)?(?:g|kg|ml)\b)',
    ),
    (match) => '\n${match.group(1)}',
  );
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

bool _readMeta(
  String line, {
  required void Function(double value) servings,
  required void Function(int value) prepMinutes,
  required void Function(int value) cookMinutes,
}) {
  var used = false;
  final served = _serves.firstMatch(line);
  if (served != null) {
    final value = double.tryParse(served.group(1)!);
    if (value != null) servings(value);
    used = true;
  }
  for (final match in _duration.allMatches(line)) {
    final minutes = _asMinutes(match.group(2)!, match.group(3)!);
    if (minutes == null) continue;
    final label = match.group(1)!.toLowerCase();
    if (label.startsWith('prep')) {
      prepMinutes(minutes);
    } else {
      cookMinutes(minutes);
    }
    used = true;
  }
  if (!used) return false;
  final stripped = line
      .replaceFirst(_serves, '')
      .replaceAll(_duration, '')
      .replaceAll(RegExp(r'[|•]'), '')
      .trim();
  return stripped.isEmpty;
}

int? _asMinutes(String amount, String unit) {
  final value = tryParseQuantity(amount);
  if (value == null) return null;
  final minutes = unit.toLowerCase().startsWith('h') ? value * 60 : value;
  return minutes.round();
}

final class _Labeled {
  const _Labeled(this.kind, this.body);

  final String kind;
  final String body;
}

const _ingredientGroups = {
  'base',
  'seasoning',
  'chili seasoning',
  'spice blend',
  'spices',
  'thickener',
  'slurry',
};

const _stepGroups = {'pro tips', 'pro tip', 'tips'};

_Labeled? _labeledGroup(String line) {
  final colon = line.indexOf(':');
  final head = (colon == -1 ? line : line.substring(0, colon)).trim();
  final body = colon == -1 ? '' : line.substring(colon + 1).trim();
  final letters = _letters(head.replaceAll(RegExp(r'\([^)]*\)'), ''));
  if (letters.isEmpty || letters.length > 40) return null;
  if (_ingredientGroups.contains(letters)) return _Labeled('ingredients', body);
  if (_stepGroups.contains(letters)) return _Labeled('steps', body);
  return null;
}

String _letters(String line) {
  return line
      .replaceAll(RegExp("[’']"), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

bool _isNoise(String line) {
  final lower = line.toLowerCase();
  if (lower.startsWith("today's verse") || lower.startsWith('todays verse')) {
    return true;
  }
  if (RegExp(r'\bpsalm\s+\d+', caseSensitive: false).hasMatch(line)) {
    return true;
  }
  return RegExp(r'#\w+').allMatches(line).length >= 2;
}

bool _isBareIngredient(String line) {
  if (line.length > 48 || line.contains('.')) return false;
  return _labeledGroup(line) == null && _section(line) == null;
}

final _embeddedMeasure = RegExp(
  r'^(.+?)\s+(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)\s*'
  r'(tablespoons?|teaspoons?|pounds?|cloves?|cups?|tbsp|tsp|lbs?|oz|kg|ml|cans?|g)\b'
  r'\s*(?:\(([^)]*)\))?\s*(.*)$',
  caseSensitive: false,
);

Ingredient? _ingredient(String line, {required bool requireQuantity}) {
  var text = _normalizeFractions(line.replaceFirst(_listMarker, '').trim());
  text = text.replaceFirst(RegExp(r'^[^0-9½⅓⅔¼¾⅛⅜⅝⅞A-Za-z]+'), '').trim();
  if (text.isEmpty) return null;
  final leading = _fromAmount(text);
  if (leading != null) return leading;
  final embedded = _embeddedMeasure.firstMatch(text);
  if (embedded != null) {
    final fromCard = _household(embedded.group(4));
    final metric = '${embedded.group(2)} ${embedded.group(3)}'.trim();
    final tail = embedded.group(5)!.trim();
    final note = [
      if (fromCard != null) metric,
      if (fromCard == null && embedded.group(4)?.trim().isNotEmpty == true)
        embedded.group(4)!.trim(),
      if (tail.isNotEmpty) tail,
    ].join('; ');
    if (fromCard != null) {
      return Ingredient(
        quantity: fromCard.quantity,
        unit: fromCard.unit,
        item: embedded.group(1)!.trim(),
        note: note.isEmpty ? null : note,
        quantityValue: fromCard.quantityValue,
      );
    }
    return Ingredient(
      quantity: embedded.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim(),
      unit: embedded.group(3)!,
      item: embedded.group(1)!.trim(),
      note: note.isEmpty ? null : note,
      quantityValue: tryParseQuantity(embedded.group(2)!),
    );
  }
  if (requireQuantity || text.isEmpty) return null;
  return Ingredient(quantity: '', unit: '', item: text);
}

Ingredient? _household(String? paren) {
  final text = paren?.trim() ?? '';
  if (text.isEmpty) return null;
  final amount = _quantity.firstMatch(text);
  if (amount == null) return null;
  final quantity = amount.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  final rest = text.substring(amount.end).trim();
  final unit = _takeUnit(rest);
  if (unit == null || unit.rest.isNotEmpty) return null;
  return Ingredient(
    quantity: quantity,
    unit: unit.unit,
    item: '',
    quantityValue: tryParseQuantity(quantity),
  );
}

Ingredient? _fromAmount(String text) {
  final amount = _quantity.firstMatch(text);
  if (amount == null) return null;
  final quantity = amount.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  final taken = _takeUnit(text.substring(amount.end).trim());
  var item = taken == null ? text.substring(amount.end).trim() : taken.rest;
  var unit = taken?.unit ?? '';
  String? note;
  final parenthetical = RegExp(
    r'^(.*?)(?:\s*\(([^)]*)\))\s*$',
  ).firstMatch(item);
  if (parenthetical != null) {
    item = parenthetical.group(1)!.trim();
    final rawNote = parenthetical.group(2)!.trim();
    if (rawNote.isNotEmpty) note = rawNote;
  }
  if (item.isEmpty) return null;
  return Ingredient(
    quantity: quantity,
    unit: unit,
    item: item,
    note: note,
    quantityValue: tryParseQuantity(quantity),
  );
}

final class _UnitSplit {
  const _UnitSplit(this.unit, this.rest);

  final String unit;
  final String rest;
}

_UnitSplit? _takeUnit(String text) {
  final lower = text.toLowerCase();
  for (final candidate in _units) {
    final exact = lower == candidate;
    final spaced = lower.startsWith('$candidate ');
    final dotted = lower.startsWith('$candidate.');
    if (!exact && !spaced && !dotted) continue;
    final skip = dotted ? candidate.length + 1 : candidate.length;
    return _UnitSplit(
      text.substring(0, candidate.length),
      text.substring(skip).trim(),
    );
  }
  return null;
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
  String? fallback;
  for (final line in lines) {
    if (_urlOnly(line) || _isNoise(line)) continue;
    fallback ??= line;
    final sentence = line.contains('. ') || line.endsWith('.');
    if (!sentence && line.length <= 60) return line;
  }
  final chosen = fallback;
  if (chosen != null) {
    if (chosen.length > 120) return '${chosen.substring(0, 120).trim()}…';
    return chosen;
  }
  final subjectTitle = subject.trim();
  if (subjectTitle.isNotEmpty && !_urlOnly(subjectTitle)) {
    if (subjectTitle.length > 120) {
      return '${subjectTitle.substring(0, 120).trim()}…';
    }
    return subjectTitle;
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
