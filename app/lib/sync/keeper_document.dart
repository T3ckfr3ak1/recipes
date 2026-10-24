/// A repo file name from a title. Taken ids get `-2`, `-3`, and so on.
String uniqueRecipeId(String title, Set<String> taken) {
  final slug = _slug(title);
  if (!taken.contains(slug)) return slug;
  var suffix = 2;
  while (taken.contains('$slug-$suffix')) {
    suffix++;
  }
  return '$slug-$suffix';
}

String _slug(String title) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'recipe';
  if (slug.length <= 60) return slug;
  final cut = slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
  return cut.isEmpty ? 'recipe' : cut;
}
