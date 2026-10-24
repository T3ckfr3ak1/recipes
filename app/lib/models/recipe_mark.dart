import 'dart:convert';

final class RecipeMark {
  const RecipeMark({this.starred = false, this.made = false});

  final bool starred;
  final bool made;

  RecipeMark copyWith({bool? starred, bool? made}) {
    return RecipeMark(
      starred: starred ?? this.starred,
      made: made ?? this.made,
    );
  }
}

Map<String, RecipeMark> parseMarks(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};
  final marks = <String, RecipeMark>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final starred = value['starred'] == true;
    final made = value['made'] == true;
    if (!starred && !made) continue;
    marks[entry.key.toString()] = RecipeMark(starred: starred, made: made);
  }
  return marks;
}

Set<String> parseSeedIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return {};
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return {};
  }
  if (decoded is! List) return {};
  return {for (final item in decoded) item.toString()};
}

String encodeSeedIds(Set<String> ids) => jsonEncode(ids.toList());

String encodeMarks(Map<String, RecipeMark> marks) {
  final encoded = <String, Map<String, bool>>{};
  for (final entry in marks.entries) {
    if (!entry.value.starred && !entry.value.made) continue;
    encoded[entry.key] = {
      if (entry.value.starred) 'starred': true,
      if (entry.value.made) 'made': true,
    };
  }
  return jsonEncode(encoded);
}
