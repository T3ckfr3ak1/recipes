# App update recommendations

Suggestions for the Windows and Android app in `app/`. Super Grok and other agents append ideas here. A Cursor agent reads this file later and changes the app. Do not edit `app/` source, `recipes/`, or `index.json` to carry out a suggestion.

The recipe app does not load this file.

## How to add one

Append one block at the end. Leave existing blocks as they are. Use status `open`.

Do not include tokens, passwords, account ids, or private machine paths. The app source is public. Suggestions are public too.

```
### open — short title
- id: 2026-10-24-short-slug
- date: 2026-10-24
- area: library | share | sync | cook | print | theme | other
- suggestion: What should change, and why.
- where: Screen or file you looked at, if you know it.
```

`id` is the date plus a few words. Do not reuse an id.

## For the agent who builds the app

When a suggestion is in the app, change `open` to `done` and add a `landed` line with the date. If it should not be built, change it to `skipped` and add a `reason` line. Do not delete the block.

## Suggestions

### open — Today button on the meal plan page
- id: 2026-10-24-meal-plan-today-view
- date: 2026-10-24
- area: other
- suggestion: Add a Today button on the Meal plan page that opens a view of the current calendar day with two groups. "Food I'll eat today" lists that day's Breakfast, Lunch, and Dinner from the plan's "## The Meal Plan" table, skips empty slots, and links each R number to its recipe the same way the existing repo view does. "Prep work today" lists every prep task that falls on today: tasks under "## Prep Timeline" headings dated today, rows in "## Thaw-the-night-before reminders" whose "Move to fridge on" date is today, lines in "## Sandwich packing nights" for today, and the "Tonight:" and "Also:" lines under today's entry in "## Day by Day". A heading that covers a range, such as "Mon Oct 26 to Thu Oct 29", counts for every day in the range. If today is outside the plan's date range, show a short "No plan for today" message. If today has no prep, say "No prep today". The button should work for the repo plan and the device plan. The device plan only has the food group. Joe wants to open the app and see in one glance what he is eating and what he has to do today.
- where: MealPlanPage in app/lib/ui/meal_plan_page.dart is the Meal plan page. The repo plan is RepoMealView in app/lib/ui/repo_meal_view.dart. That view already marks today's card with a Today label, and _CodeChip opens each R number through MealPack.recipeFor. Meal days, recipe codes, and the plan start and end dates come from MealPack and parseMealPack in app/lib/logic/meal_pack.dart, which reads the "## The Meal Plan" table into MealDay and leaves the prep sections in the pack body. Those sections are in meal-plan/2026-10-20_to_2026-11-04.md: "## The Meal Plan", "## Prep Timeline", "## Thaw-the-night-before reminders", "## Sandwich packing nights", and "## Day by Day". The device plan is the week of _DayCard and _SlotRow on MealPlanPage, and it only stores breakfast, lunch, and dinner.

### open — Kids profile and a kid approved tag
- id: 2026-10-24-kids-profile-and-kid-approved-tag
- date: 2026-10-24
- area: library
- suggestion: Show Joe's kids food profile in the app, and add a kid approved tag he can filter on. (1) Recipe Keeper is saving the kids profile to the repo, likely preferences/kids-profile.md. Load and display that note the same way other preference docs already show, so Joe can check who eats what. The three kids are Warren, Augustus, and Lincoln. Warren has a nut allergy and that should be prominent. (2) Add a kid approved tag on recipes, for one kid or for all three. Store it in the recipe tags list: "kid-approved" means all three, and "kid-approved:W", "kid-approved:A", and "kid-approved:L" mean Warren, Augustus, and Lincoln. Show a badge on each recipe in the library list and on the recipe detail, and add a library filter for kid approved recipes. Tags fit this because they live on the recipe file and sync with Recipe Keeper. Starred and made stay on this device in recipe marks, so they are the wrong place for a shared kid approved flag. The Tag menu only lists a tag after it is on 8 recipes, so the filter should be its own chip, like Made and Starred, and should match "kid-approved" plus any "kid-approved:" letter. (3) Nice to have: warn on a recipe whose ingredients mention nuts or peanuts, for Warren. Joe plans meals for his three sons on his weekends and wants to pick recipes they will actually eat.
- where: Kitchen preferences already load every preferences/*.md file. kindForPath in app/lib/models/repo_doc.dart maps that folder to RepoKind.preference, RepoLibrarySync downloads it, and KitchenPage shows it under Preferences through docsFor and _DocDetail. The existing note is preferences/food-preferences.md. preferences/kids-profile.md is not in the repo yet. Recipe tags are Recipe.tags in app/lib/models/recipe.dart, read from the JSON tags array. The library list row is _RecipeTile in app/lib/ui/library_page.dart, which already shows made and starred icons. The recipe detail is RecipeDetail in app/lib/ui/recipe_detail.dart, which shows Made and Star chips and one chip per tag. Filters are RecipeQuery and commonTags in app/lib/logic/recipe_query.dart, and the Made and Starred chips are on LibraryPage. RecipeMark in app/lib/models/recipe_mark.dart only stores starred and made on the device. Ingredient wording is Ingredient.item and Ingredient.note in app/lib/models/ingredient.dart.

### open — Sync starred and made marks with the recipe repo
- id: 2026-10-24-sync-starred-made-marks
- date: 2026-10-24
- area: sync
- suggestion: Every recipe JSON in the repo now has two booleans, `starred` (the app's star) and `made` (Joe has cooked it). Recipe Keeper seeded `made: true` with the same rule as the app's isHomeCooked (Joe's pulled pork and Not-Spaghetti right now). Everything else is `made: false`, and every recipe is `starred: false`, because Joe's real stars only live on his device. (1) Read `starred` and `made` from the recipe JSON. (2) When Joe toggles Star or Made, write the new value back to that recipe file in the repo. If that's too much for now, at least merge them: treat a mark as on if the repo or the device says it's on, so the first sync doesn't wipe local stars and repo values still show up on a new device. (3) When the app re-publishes recipes (Flavorish imports), keep `starred`, `made`, and `nutrition` {healthy, not_healthy}. Today the publish path rebuilds the file from the Recipe model, which drops any field the model doesn't know about, so a re-publish would erase Recipe Keeper's nutrition notes and these marks. Joe wants his stars and cooked list on every device and backed up in the repo.
- where: RecipeMark, parseMarks, and encodeMarks in app/lib/models/recipe_mark.dart keep marks only on the device under MetaKeys.marks. In app/lib/state/library_controller.dart, _markCooked seeds made from isHomeCooked (app/lib/logic/home_cooked.dart), and toggleStarred and toggleMade both go through _updateMark. The Recipe model in app/lib/models/recipe.dart has no starred, made, or nutrition fields: Recipe.fromJson ignores them and toKeeperMap/toKeeperJson doesn't write them. FlavorishRepoPublisher.publish in app/lib/sync/github_publisher.dart writes each file with toKeeperJson. The Flavorish import path is app/lib/import/flavorish_importer.dart (publishPending), app/lib/import/flavorish_mapper.dart, and app/lib/import/flavorish_export_mapper.dart. The export mapper's _nutrition builds Flavorish's numeric nutrition text, which is separate from the repo's nutrition {healthy, not_healthy} lists.
