# Recipes

Maintained by Recipe Keeper. The Windows recipe app reads this repo.

- `index.json`: `generated_at` plus one entry per recipe: `id`, `updated_at`, `deleted`, `path`.
- `recipes/<id>.json`: id, title, description, servings, prep_minutes, cook_minutes, ingredients [{quantity, unit, item, note}], steps [string], tags [string], category, source, notes, air_fry {rack, preheat, temp_f, minutes} (optional), created_at, updated_at, deleted.

All times are ISO 8601 with offset. Deleted recipes stay with `deleted: true` and a new `updated_at`.
- `meal-plan/`: the current meal plan (`meal-plan.md`, plus the original meal pack PDF). Not read as recipes.
