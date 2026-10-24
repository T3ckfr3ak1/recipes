import '../models/repo_doc.dart';
import 'markdown_doc.dart';

final _datedName = RegExp(
  r'(\d{4}-\d{2}-\d{2})_to_(\d{4}-\d{2}-\d{2})\.md$',
  caseSensitive: false,
);

final _monthDay = RegExp(
  r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2})\b',
);

const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

final class MealDay {
  const MealDay({
    required this.label,
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.codes,
  });

  final String label;
  final DateTime? date;
  final String breakfast;
  final String lunch;
  final String dinner;
  final List<String> codes;
}

final class PackRecipe {
  const PackRecipe({required this.code, required this.title, this.recipeId});

  final String code;
  final String title;
  final String? recipeId;
}

final class MealPack {
  const MealPack({
    required this.path,
    required this.title,
    required this.body,
    required this.start,
    required this.end,
    required this.days,
    required this.recipes,
    this.snacks,
  });

  final String path;
  final String title;
  final String body;
  final DateTime? start;
  final DateTime? end;
  final List<MealDay> days;
  final List<PackRecipe> recipes;
  final String? snacks;

  PackRecipe? recipeFor(String code) {
    for (final recipe in recipes) {
      if (recipe.code == code) return recipe;
    }
    return null;
  }
}

bool isDatedMealPlan(String path) => _datedName.hasMatch(path.split('/').last);

MealPack parseMealPack(RepoDoc doc) {
  final range = _range(doc.path);
  final blocks = parseMarkdown(doc.body);
  MdTable? mealTable;
  final recipeRows = <List<List<MdSpan>>>[];
  String? snacks;
  var seenMeal = false;
  for (final block in blocks) {
    if (block is MdTable && mealTable == null && _isMealTable(block)) {
      mealTable = block;
      seenMeal = true;
      continue;
    }
    if (block is MdTable && _isRecipeTable(block)) {
      recipeRows.addAll(block.rows);
      continue;
    }
    if (seenMeal && snacks == null && block is MdParagraph) {
      final text = spanText(block.spans).trim();
      if (text.toLowerCase().startsWith('snacks')) snacks = text;
    }
  }
  return MealPack(
    path: doc.path,
    title: doc.title,
    body: doc.body,
    start: range?.$1,
    end: range?.$2,
    days: mealTable == null ? const [] : _days(mealTable, range),
    recipes: _recipes(recipeRows),
    snacks: snacks,
  );
}

(DateTime, DateTime)? _range(String path) {
  final match = _datedName.firstMatch(path.split('/').last);
  if (match == null) return null;
  final start = _isoDate(match.group(1)!);
  final end = _isoDate(match.group(2)!);
  if (start == null || end == null) return null;
  return (start, end);
}

DateTime? _isoDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

bool _isMealTable(MdTable table) {
  final names = [
    for (final cell in table.header) spanText(cell).trim().toLowerCase(),
  ];
  return names.contains('day') &&
      names.contains('breakfast') &&
      names.contains('lunch') &&
      names.contains('dinner');
}

bool _isRecipeTable(MdTable table) {
  final header = [
    for (final cell in table.header) spanText(cell).trim().toLowerCase(),
  ].join(' ');
  if (header.contains('recipe file') || header.contains('pack')) return true;
  for (final row in table.rows) {
    for (final cell in row) {
      if (_recipeId(cell) != null) return true;
    }
  }
  return false;
}

List<MealDay> _days(MdTable table, (DateTime, DateTime)? range) {
  final names = [
    for (final cell in table.header) spanText(cell).trim().toLowerCase(),
  ];
  int column(String name) => names.indexOf(name);
  final day = column('day');
  final breakfast = column('breakfast');
  final lunch = column('lunch');
  final dinner = column('dinner');
  final recipes = column('recipes');
  String cell(List<List<MdSpan>> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return spanText(row[index]).trim();
  }

  return [
    for (final row in table.rows)
      if (cell(row, day).isNotEmpty)
        MealDay(
          label: cell(row, day),
          date: range == null ? null : _dayInRange(cell(row, day), range),
          breakfast: cell(row, breakfast),
          lunch: cell(row, lunch),
          dinner: cell(row, dinner),
          codes: _codes(cell(row, recipes)),
        ),
  ];
}

DateTime? _dayInRange(String label, (DateTime, DateTime) range) {
  final match = _monthDay.firstMatch(label);
  if (match == null) return null;
  final month = _months[match.group(1)!];
  final day = int.tryParse(match.group(2)!);
  if (month == null || day == null) return null;
  for (var year = range.$1.year; year <= range.$2.year; year++) {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) continue;
    if (date.isBefore(range.$1) || date.isAfter(range.$2)) continue;
    return date;
  }
  return null;
}

List<String> _codes(String raw) {
  final seen = <String>{};
  final codes = <String>[];
  for (final match in RegExp(r'\bR\d+\b').allMatches(raw)) {
    final code = match.group(0)!;
    if (seen.add(code)) codes.add(code);
  }
  return codes;
}

List<PackRecipe> _recipes(List<List<List<MdSpan>>> rows) {
  final recipes = <PackRecipe>[];
  final seen = <String>{};
  for (final row in rows) {
    String? code;
    for (final cell in row) {
      final text = spanText(cell).trim();
      final match = RegExp(r'^R\d+$').firstMatch(text);
      if (match != null) {
        code = match.group(0);
        break;
      }
    }
    if (code == null || !seen.add(code)) continue;
    String? id;
    var title = '';
    for (final cell in row) {
      id ??= _recipeId(cell);
      final text = spanText(cell).trim();
      if (title.isEmpty &&
          text.isNotEmpty &&
          text != code &&
          !text.contains('.json')) {
        title = text;
      }
    }
    recipes.add(
      PackRecipe(code: code, title: title.isEmpty ? code : title, recipeId: id),
    );
  }
  return recipes;
}

String? _recipeId(List<MdSpan> spans) {
  for (final span in spans) {
    if (span is! MdLink) continue;
    final id = recipeIdFromHref(span.href);
    if (id != null) return id;
  }
  return null;
}

final _recipeHref = RegExp(r'(?:^|/)recipes/([A-Za-z0-9._-]+)\.json$');

String? recipeIdFromHref(String href) {
  final path = href.split('?').first.split('#').first.trim();
  return _recipeHref.firstMatch(path)?.group(1);
}
