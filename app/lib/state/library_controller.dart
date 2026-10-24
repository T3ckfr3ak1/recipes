import 'package:flutter/foundation.dart';

import '../auth/github_token_store.dart';
import '../db/recipe_store.dart';
import '../import/flavorish_importer.dart';
import '../logic/home_cooked.dart';
import '../logic/meal_pack.dart';
import '../logic/recipe_query.dart';
import '../models/app_settings.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../models/recipe_mark.dart';
import '../models/recipe_origin.dart';
import '../models/repo_doc.dart';
import '../share/incoming_share.dart';
import '../share/page_description.dart';
import '../share/share_resolver.dart';
import '../sync/github_publisher.dart';
import '../sync/github_token.dart';
import '../sync/http_recipe_remote.dart';
import '../sync/keeper_document.dart';
import '../sync/recipe_remote.dart';
import '../sync/repo_library_sync.dart';
import '../sync/sync_exception.dart';
import '../sync/sync_result.dart';
import '../sync/sync_service.dart';
import '../time/instants.dart';

enum AppPage { library, plan, kitchen, settings }

enum PlanSource { repo, device }

enum KitchenSection { equipment, methods, preferences }

final class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.store,
    required this.remote,
    required this.syncService,
    required this.importer,
    required this.supportDirectory,
    required AppSettings initialSettings,
    GithubTokenStore? tokenStore,
    this.publisher,
    ShareResolver? shareResolver,
    this.repoLibrary,
  }) : tokenStore = tokenStore ?? MemoryGithubTokenStore(),
       shareResolver =
           shareResolver ?? ShareResolver(pages: const EmptyPageDescription()),
       settings = initialSettings,
       planWeek = startOfWeek(DateTime.now());

  final RecipeStore store;
  final RecipeRemote remote;
  final SyncService syncService;
  final FlavorishImporter importer;
  final String supportDirectory;
  final GithubTokenStore tokenStore;
  final RecipePublisher? publisher;
  final ShareResolver shareResolver;
  final RepoLibrarySync? repoLibrary;

  AppSettings settings;
  List<Recipe> recipes = [];
  String? lastPullAtRaw;
  String? syncError;
  bool busy = false;
  AppPage page = AppPage.library;
  String searchText = '';
  String? categoryFilter;
  String? tagFilter;
  bool madeOnly = false;
  bool starredOnly = false;
  String? mealFilter;
  Map<String, RecipeMark> marks = const {};
  String? selectedId;
  int _markWrite = 0;
  bool githubKeySaved = false;
  String? _githubToken;
  MealPlan mealPlan = const MealPlan();
  DateTime planWeek;
  List<RepoDoc> docs = [];
  PlanSource planSource = PlanSource.repo;
  KitchenSection kitchenSection = KitchenSection.equipment;
  String? selectedDocPath;
  String? selectedPackPath;

  List<Recipe> get visible => applyQuery(
    recipes,
    RecipeQuery(
      text: searchText,
      category: categoryFilter,
      tag: tagFilter,
      sort: settings.sort,
      madeOnly: madeOnly,
      starredOnly: starredOnly,
      meal: mealFilter,
      marks: marks,
    ),
  );

  Recipe? get selected {
    for (final recipe in recipes) {
      if (recipe.id == selectedId) return recipe;
    }
    return null;
  }

  Recipe? recipeById(String id) {
    for (final recipe in recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  List<String> get categories => distinctCategories(recipes);

  List<String> get tags => commonTags(recipes);

  List<String> get mealChoices {
    return [
      for (final meal in mealFilters)
        if (recipes.any(
          (recipe) => !recipe.deleted && recipeMatchesMeal(recipe, meal),
        ))
          meal,
    ];
  }

  bool isStarred(String id) => marks[id]?.starred ?? false;

  bool isMade(String id) => marks[id]?.made ?? false;

  RepoDoc? get selectedDoc {
    for (final doc in docs) {
      if (doc.path == selectedDocPath) return doc;
    }
    return null;
  }

  List<RepoDoc> docsFor(KitchenSection section) {
    final kind = switch (section) {
      KitchenSection.equipment => RepoKind.equipment,
      KitchenSection.methods => RepoKind.method,
      KitchenSection.preferences => RepoKind.preference,
    };
    final list = [
      for (final doc in docs)
        if (doc.kind == kind) doc,
    ]..sort(compareRepoDocs);
    return list;
  }

  List<MealPack> get datedPacks {
    final packs =
        [
          for (final doc in docs)
            if (doc.kind == RepoKind.mealPlan && isDatedMealPlan(doc.path))
              parseMealPack(doc),
        ]..sort((a, b) {
          final aStart = a.start ?? DateTime(1970);
          final bStart = b.start ?? DateTime(1970);
          return bStart.compareTo(aStart);
        });
    return packs;
  }

  MealPack? get activePack {
    final packs = datedPacks;
    if (packs.isEmpty) return null;
    final chosen = selectedPackPath;
    if (chosen != null) {
      for (final pack in packs) {
        if (pack.path == chosen) return pack;
      }
    }
    final today = dateOnly(DateTime.now());
    for (final pack in packs) {
      final start = pack.start;
      final end = pack.end;
      if (start != null &&
          end != null &&
          !today.isBefore(start) &&
          !today.isAfter(end)) {
        return pack;
      }
    }
    return packs.first;
  }

  List<RepoDoc> get mealGuides {
    final list = [
      for (final doc in docs)
        if (doc.kind == RepoKind.mealPlan && !isDatedMealPlan(doc.path)) doc,
    ]..sort(compareRepoDocs);
    return list;
  }

  List<RepoDoc> get mealPdfs {
    final list = [
      for (final doc in docs)
        if (doc.kind == RepoKind.mealPdf) doc,
    ]..sort(compareRepoDocs);
    return list;
  }

  Future<void> reload() async {
    final markWrite = _markWrite;
    recipes = await store.allRecipes();
    lastPullAtRaw = await store.getMeta(MetaKeys.lastPullAt);
    syncError = await store.getMeta(MetaKeys.lastSyncError);
    final saved = await AppSettings.load(store);
    settings = saved;
    await _loadToken();
    mealPlan = MealPlan.parse(await store.getMeta(MetaKeys.mealPlan));
    final loadedMarks = parseMarks(await store.getMeta(MetaKeys.marks));
    final seeded = await _markCooked(loadedMarks);
    if (markWrite == _markWrite) marks = seeded;
    docs = await store.allDocs();
    _applyTimeout();
    if (selectedId != null && selected == null) selectedId = null;
    if (selectedDocPath != null && selectedDoc == null) selectedDocPath = null;
    notifyListeners();
  }

  void setSearch(String value) {
    searchText = value;
    notifyListeners();
  }

  void setCategory(String? value) {
    categoryFilter = value;
    notifyListeners();
  }

  void setTag(String? value) {
    tagFilter = value;
    notifyListeners();
  }

  void setMadeOnly(bool value) {
    madeOnly = value;
    notifyListeners();
  }

  void setStarredOnly(bool value) {
    starredOnly = value;
    notifyListeners();
  }

  void setMeal(String? value) {
    mealFilter = value;
    notifyListeners();
  }

  Future<Map<String, RecipeMark>> _markCooked(
    Map<String, RecipeMark> loaded,
  ) async {
    final seeded = parseSeedIds(await store.getMeta(MetaKeys.madeSeed));
    final marks = Map<String, RecipeMark>.from(loaded);
    var changed = false;
    for (final recipe in recipes) {
      if (!isHomeCooked(recipe) || seeded.contains(recipe.id)) continue;
      seeded.add(recipe.id);
      final current = marks[recipe.id] ?? const RecipeMark();
      if (!current.made) marks[recipe.id] = current.copyWith(made: true);
      changed = true;
    }
    if (changed) {
      await store.setMeta(
        MetaKeys.marks,
        marks.isEmpty ? null : encodeMarks(marks),
      );
      await store.setMeta(MetaKeys.madeSeed, encodeSeedIds(seeded));
    }
    return marks;
  }

  Future<void> toggleMade(String id) {
    return _updateMark(id, made: !isMade(id));
  }

  Future<void> toggleStarred(String id) {
    return _updateMark(id, starred: !isStarred(id));
  }

  Future<void> _updateMark(String id, {bool? starred, bool? made}) async {
    final write = ++_markWrite;
    final current = marks[id] ?? const RecipeMark();
    final next = current.copyWith(
      starred: starred ?? current.starred,
      made: made ?? current.made,
    );
    final updated = Map<String, RecipeMark>.from(marks);
    if (!next.starred && !next.made) {
      updated.remove(id);
    } else {
      updated[id] = next;
    }
    await store.setMeta(
      MetaKeys.marks,
      updated.isEmpty ? null : encodeMarks(updated),
    );
    if (write != _markWrite) return;
    marks = updated;
    notifyListeners();
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void showSettings() {
    page = AppPage.settings;
    notifyListeners();
  }

  void showPlan() {
    page = AppPage.plan;
    notifyListeners();
  }

  void showLibrary() {
    page = AppPage.library;
    notifyListeners();
  }

  void showKitchen() {
    page = AppPage.kitchen;
    notifyListeners();
  }

  void showKitchenSection(KitchenSection section) {
    kitchenSection = section;
    selectedDocPath = null;
    page = AppPage.kitchen;
    notifyListeners();
  }

  void selectDoc(String? path) {
    selectedDocPath = path;
    notifyListeners();
  }

  void showPlanSource(PlanSource source) {
    planSource = source;
    page = AppPage.plan;
    notifyListeners();
  }

  void showPack(String path) {
    selectedPackPath = path;
    notifyListeners();
  }

  /// Opens a recipe linked from a meal plan or note. Returns false when the
  /// link is not a recipe, or that recipe is not on this device yet.
  bool openLinkedRecipe(String href) {
    final id = recipeIdFromHref(href);
    if (id == null || recipeById(id) == null) return false;
    selectedId = id;
    page = AppPage.library;
    notifyListeners();
    return true;
  }

  void showWeek(DateTime day) {
    planWeek = startOfWeek(day);
    notifyListeners();
  }

  void shiftWeek(int weeks) {
    planWeek = planWeek.add(Duration(days: 7 * weeks));
    notifyListeners();
  }

  Future<void> assignMeal(DateTime day, MealSlot slot, String? recipeId) async {
    mealPlan = mealPlan.assign(day, slot, recipeId);
    await store.setMeta(MetaKeys.mealPlan, mealPlan.encode());
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    _applyTimeout();
    await next.save(store);
    notifyListeners();
  }

  Future<void> saveGithubToken(String raw) async {
    final token = raw.trim();
    if (token.length < 20 || token.contains(RegExp(r'\s'))) {
      throw SyncException(
        'That key does not look like a GitHub token. Paste the whole key, with no spaces.',
      );
    }
    await tokenStore.write(token);
    _githubToken = token;
    githubKeySaved = true;
    _applyToken();
    notifyListeners();
  }

  Future<void> clearGithubToken() async {
    await tokenStore.write(null);
    _githubToken = null;
    githubKeySaved = false;
    _applyToken();
    notifyListeners();
  }

  Future<ShareResolution> inspectShare(IncomingShare share) {
    return shareResolver.resolve(share);
  }

  /// Writes [recipe] to the repo, keeps a local copy, then syncs.
  Future<Recipe> publishRecipe(Recipe recipe) async {
    final writer = publisher;
    if (writer == null) {
      throw SyncException('Saving to the repo is not available.');
    }
    final token = _githubToken;
    if (token == null || token.isEmpty) {
      throw SyncException(
        'Add a GitHub key in Settings before saving to the repo.',
      );
    }
    if (busy) {
      throw SyncException('Wait for the current sync to finish.');
    }
    busy = true;
    notifyListeners();
    try {
      _applyTimeout();
      final taken = {for (final existing in recipes) existing.id};
      final stamp = isoWithOffset(DateTime.now());
      final instant = parseInstant(stamp);
      final saved = recipe.copyWith(
        id: uniqueRecipeId(recipe.title, taken),
        createdAt: instant,
        updatedAt: instant,
        createdAtRaw: stamp,
        updatedAtRaw: stamp,
        deleted: false,
        origin: RecipeOrigin.github,
      );
      try {
        await writer.publish([saved], supportDirectory: supportDirectory);
      } on GithubPublishException catch (error) {
        throw SyncException(error.message);
      }
      await store.upsertGithubRecipe(saved);
      final pulled = await syncService.sync();
      final noteErrors = await _pullRepoLibrary();
      if (noteErrors.isNotEmpty) {
        await store.setMeta(
          MetaKeys.lastSyncError,
          [...pulled.errors, ...noteErrors].join('\n'),
        );
      }
      return saved;
    } finally {
      busy = false;
      await reload();
    }
  }

  Future<SyncResult> syncNow() async {
    if (busy) {
      return SyncResult(
        advanced: false,
        lastPullAtRaw: lastPullAtRaw,
        upserted: 0,
        removed: 0,
        fetched: 0,
        errors: const [],
        alreadyRunning: true,
      );
    }
    busy = true;
    notifyListeners();
    try {
      _applyTimeout();
      String? publishError;
      try {
        await importer.publishPending();
      } on GithubPublishException catch (error) {
        publishError = error.message;
      } catch (error) {
        publishError = '$error';
      }
      final result = await syncService.sync();
      final noteErrors = await _pullRepoLibrary();
      if (publishError == null && noteErrors.isEmpty) return result;
      final errors = [?publishError, ...result.errors, ...noteErrors];
      await store.setMeta(MetaKeys.lastSyncError, errors.join('\n'));
      return SyncResult(
        advanced: false,
        lastPullAtRaw: result.lastPullAtRaw,
        upserted: result.upserted,
        removed: result.removed,
        fetched: result.fetched,
        errors: errors,
      );
    } finally {
      busy = false;
      await reload();
    }
  }

  Future<ImportResult> importFlavorish(List<int> bytes) async {
    if (busy) {
      throw StateError('Wait for the current sync or import to finish.');
    }
    busy = true;
    notifyListeners();
    try {
      return await importer.importBytes(bytes);
    } finally {
      busy = false;
      recipes = await store.allRecipes();
      notifyListeners();
    }
  }

  Future<List<String>> _pullRepoLibrary() async {
    final library = repoLibrary;
    if (library == null) return const [];
    try {
      return await library.sync();
    } catch (error) {
      return [describeSyncError(error)];
    }
  }

  Future<void> _loadToken() async {
    final token = await tokenStore.read();
    _githubToken = token;
    githubKeySaved = token != null && token.isNotEmpty;
    _applyToken();
  }

  void _applyToken() {
    final current = remote;
    if (current is HttpRecipeRemote) current.accessToken = _githubToken;
  }

  void _applyTimeout() {
    final timeout = Duration(seconds: settings.timeoutSeconds);
    remote.timeout = timeout;
    final pages = shareResolver.pages;
    if (pages is HttpPageDescription) pages.timeout = timeout;
  }

  Future<void> removeLocal(String id) async {
    await store.removeLocalRecipe(id);
    if (selectedId == id) selectedId = null;
    recipes = await store.allRecipes();
    notifyListeners();
  }
}
