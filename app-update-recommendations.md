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
