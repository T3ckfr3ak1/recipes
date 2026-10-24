import 'package:intl/intl.dart';

import '../models/recipe.dart';
import '../time/instants.dart';

String formatSyncTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Not synced yet';
  try {
    final local = parseInstant(raw).toLocal();
    return 'Last sync ${DateFormat('MMM d, yyyy, h:mm a').format(local)}';
  } on FormatException {
    return 'Last sync $raw';
  }
}

String cookTimeLabel(Recipe recipe) {
  final parts = <String>[];
  if (recipe.prepMinutes != null) parts.add('${recipe.prepMinutes} min prep');
  if (recipe.cookMinutes != null) parts.add('${recipe.cookMinutes} min cook');
  return parts.join(' · ');
}
