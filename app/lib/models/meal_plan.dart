import 'dart:convert';

enum MealSlot {
  breakfast,
  lunch,
  dinner;

  String get label => switch (this) {
    MealSlot.breakfast => 'Breakfast',
    MealSlot.lunch => 'Lunch',
    MealSlot.dinner => 'Dinner',
  };

  static MealSlot? parse(String raw) {
    for (final slot in MealSlot.values) {
      if (slot.name == raw) return slot;
    }
    return null;
  }
}

final class MealAssignment {
  const MealAssignment({
    required this.date,
    required this.slot,
    required this.recipeId,
  });

  final DateTime date;
  final MealSlot slot;
  final String recipeId;
}

/// Meals chosen on this device. Dates are calendar days, with no time of day.
final class MealPlan {
  const MealPlan({this.assignments = const []});

  final List<MealAssignment> assignments;

  String? recipeIdFor(DateTime day, MealSlot slot) {
    final key = dateKey(day);
    for (final assignment in assignments) {
      if (dateKey(assignment.date) == key && assignment.slot == slot) {
        return assignment.recipeId;
      }
    }
    return null;
  }

  MealPlan assign(DateTime day, MealSlot slot, String? recipeId) {
    final key = dateKey(day);
    final next = [
      for (final assignment in assignments)
        if (dateKey(assignment.date) != key || assignment.slot != slot)
          assignment,
    ];
    final id = recipeId?.trim() ?? '';
    if (id.isNotEmpty) {
      next.add(MealAssignment(date: dateOnly(day), slot: slot, recipeId: id));
    }
    return MealPlan(assignments: next);
  }

  String encode() {
    return jsonEncode({
      'assignments': [
        for (final assignment in assignments)
          {
            'date': dateKey(assignment.date),
            'slot': assignment.slot.name,
            'recipe_id': assignment.recipeId,
          },
      ],
    });
  }

  static MealPlan parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const MealPlan();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const MealPlan();
      final list = decoded['assignments'];
      if (list is! List) return const MealPlan();
      final assignments = <MealAssignment>[];
      for (final item in list) {
        if (item is! Map) continue;
        final date = _parseDate(item['date']);
        final slot = item['slot'] is String
            ? MealSlot.parse(item['slot'] as String)
            : null;
        final recipeId = item['recipe_id'];
        if (date == null || slot == null) continue;
        if (recipeId is! String || recipeId.trim().isEmpty) continue;
        assignments.add(
          MealAssignment(date: date, slot: slot, recipeId: recipeId.trim()),
        );
      }
      return MealPlan(assignments: assignments);
    } on FormatException {
      return const MealPlan();
    }
  }
}

DateTime dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

/// Monday of the week that contains [day].
DateTime startOfWeek(DateTime day) {
  final date = dateOnly(day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String dateKey(DateTime day) {
  final date = dateOnly(day);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
