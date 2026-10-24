# Recipes

Maintained by Recipe Keeper. The Windows and Android apps are the same Flutter project in `app/`. They read this repo and publish every recipe here, including Flavorish imports. The app source has no account keys. A GitHub token is entered in the app and stays on that device.

- `index.json`: `generated_at` plus one entry per recipe: `id`, `updated_at`, `deleted`, `path`.
- `recipes/<id>.json`: id, title, description, servings, prep_minutes, cook_minutes, ingredients [{quantity, unit, item, note}], steps [string], tags [string], category, source, notes, air_fry {rack, preheat, temp_f, minutes} (optional), nutrition {healthy [string], not_healthy [string]} (optional; short plain reasons a dish is or isn't healthy, no numbers), created_at, updated_at, deleted.

- `images/` holds optional photos. A recipe can list them in `images` as repo paths.

All times are ISO 8601 with offset. Deleted recipes stay with `deleted: true` and a new `updated_at`.
- `meal-plan/`: dated meal plans (`<start>_to_<end>.md`) plus the original meal pack PDF. Not read as recipes.
- `equipment/`: one markdown file per cooking tool or appliance Joe owns, with model and known settings or quirks.
- `methods/`: one markdown file per cooking method, conversion rule, or lesson learned, citing which bot and date it came from.
- `preferences/`: Joe's food likes, dislikes and brand rules (`food-preferences.md`), and the kids' food profile (`kids-profile.md`).
- `appliance-manuals/`: owner's manuals for appliances in `equipment/`. The app does not load this folder.
