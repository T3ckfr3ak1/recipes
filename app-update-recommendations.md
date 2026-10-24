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
