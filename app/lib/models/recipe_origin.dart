enum RecipeOrigin {
  github,
  local;

  static RecipeOrigin parse(String raw) {
    return RecipeOrigin.values.firstWhere(
      (origin) => origin.name == raw,
      orElse: () => RecipeOrigin.github,
    );
  }
}
