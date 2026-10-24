# Recipes

Recipe library for Windows and Android. The repo `T3ckfr3ak1/recipes` on branch `main` is the source of truth. Flavorish imports and recipes saved from a shared video are published there, then synced back down. A recipe that could not be published stays on this computer until the next sync.

Sync also loads the rest of the repo on both apps: dated meal plans and the meal-pack PDF, equipment notes, cooking methods, and food preferences. Those stay available offline after a sync. The app opens in a dark theme. Settings can switch it to light or follow the system.

Share a video into the Android app. When the description already contains a recipe, confirm it and the app adds that recipe to the repo. Windows publishing uses the GitHub sign-in already stored for Git. The phone needs a key with read and write access, saved in Settings, and that key stays on the phone. Sync can read a public repo without a key, and sends the key when one is saved.

```powershell
flutter test
flutter run -d windows
flutter build apk --release
```

The library is a SQLite database in the app's local support folder. The app keeps working from that database when the network is down.
