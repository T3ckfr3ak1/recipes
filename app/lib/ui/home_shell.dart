import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/repo_config.dart';
import '../import/flavorish_mapper.dart';
import '../share/incoming_share.dart';
import '../share/share_channel.dart';
import '../state/library_controller.dart';
import 'format.dart';
import 'library_page.dart';
import 'kitchen_page.dart';
import 'meal_plan_page.dart';
import 'settings_page.dart';
import 'shared_recipe_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final _searchFocus = FocusNode();
  late final TextEditingController _search;
  ShareChannel? _shares;
  StreamSubscription<IncomingShare>? _shareSub;
  var _resumeSync = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      final channel = ShareChannel();
      _shares = channel;
      _shareSub = channel.shares.listen((share) {
        if (!mounted) return;
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => SharedRecipePage(share: share),
            ),
          ),
        );
      });
      unawaited(channel.start());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<LibraryController>();
      if (controller.settings.syncOnLaunch) {
        unawaited(controller.syncNow());
      }
      _resumeSync = true;
    });
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    unawaited(_shareSub?.cancel());
    _shares?.close();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid || state != AppLifecycleState.resumed) return;
    if (!_resumeSync || !mounted) return;
    final controller = context.read<LibraryController>();
    if (!controller.settings.syncOnLaunch || controller.busy) return;
    unawaited(controller.syncNow());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final onSettings = controller.page == AppPage.settings;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocus.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (!controller.busy) unawaited(_sync(context));
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  search: _search,
                  searchFocus: _searchFocus,
                  onSync: () => _sync(context),
                  onImport: () => _import(context),
                ),
                if (controller.syncError != null &&
                    controller.syncError!.trim().isNotEmpty)
                  Material(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.syncError!,
                              key: const Key('sync-error'),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: switch (controller.page) {
                    AppPage.settings => const SettingsPage(),
                    AppPage.plan => const MealPlanPage(),
                    AppPage.kitchen => const KitchenPage(),
                    AppPage.library => const LibraryPage(),
                  },
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            controller.busy
                                ? 'Syncing…'
                                : formatSyncTime(controller.lastPullAtRaw),
                            key: const Key('sync-status'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          RepoConfig.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: narrow && !onSettings
              ? NavigationBar(
                  selectedIndex: switch (controller.page) {
                    AppPage.plan => 1,
                    AppPage.kitchen => 2,
                    _ => 0,
                  },
                  onDestinationSelected: (index) {
                    switch (index) {
                      case 1:
                        controller.showPlan();
                      case 2:
                        controller.showKitchen();
                      default:
                        controller.showLibrary();
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.restaurant_outlined),
                      selectedIcon: Icon(Icons.restaurant),
                      label: 'Recipes',
                    ),
                    NavigationDestination(
                      key: Key('open-meal-plan'),
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Plan',
                    ),
                    NavigationDestination(
                      key: Key('open-kitchen'),
                      icon: Icon(Icons.kitchen_outlined),
                      selectedIcon: Icon(Icons.kitchen),
                      label: 'Kitchen',
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final result = await context.read<LibraryController>().syncNow();
    if (!context.mounted || result.alreadyRunning) return;
    final message = result.advanced
        ? (result.upserted == 0 && result.removed == 0
              ? 'Already up to date.'
              : 'Synced. ${result.upserted} updated, ${result.removed} removed.')
        : 'Sync did not finish. Saved recipes are still here.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import(BuildContext context) async {
    final controller = context.read<LibraryController>();
    if (controller.busy) return;
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import Flavorish export',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    try {
      final result = await controller.importFlavorish(bytes);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Flavorish import'),
          content: Text(result.summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on FlavorishImportException catch (error) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import did not finish'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.search,
    required this.searchFocus,
    required this.onSync,
    required this.onImport,
  });

  final TextEditingController search;
  final FocusNode searchFocus;
  final VoidCallback onSync;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final showSections = MediaQuery.sizeOf(context).width >= 900;
    final onLibrary = controller.page == AppPage.library;
    final onSettings = controller.page == AppPage.settings;
    final onPlan = controller.page == AppPage.plan;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF8C6A32)
                  : scheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
          child: Row(
            children: [
              Text(
                'Recipes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 20),
              if (onLibrary)
                Expanded(
                  child: TextField(
                    key: const Key('recipe-search'),
                    controller: search,
                    focusNode: searchFocus,
                    decoration: const InputDecoration(
                      hintText: 'Search title, ingredient, or tag',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: controller.setSearch,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              _SyncButton(busy: controller.busy, wide: wide, onPressed: onSync),
              const SizedBox(width: 8),
              _ImportButton(
                busy: controller.busy,
                wide: wide,
                onPressed: onImport,
              ),
              if (showSections) ...[
                const SizedBox(width: 4),
                _SectionButton(
                  wide: wide,
                  selected: onPlan,
                  tooltip: onPlan ? 'Back to recipes' : 'Meal plan',
                  label: 'Meal plan',
                  buttonKey: const Key('open-meal-plan'),
                  icon: Icon(
                    onPlan
                        ? Icons.calendar_month
                        : Icons.calendar_month_outlined,
                  ),
                  onPressed: onPlan
                      ? controller.showLibrary
                      : controller.showPlan,
                ),
                const SizedBox(width: 4),
                _SectionButton(
                  wide: wide,
                  selected: controller.page == AppPage.kitchen,
                  tooltip: controller.page == AppPage.kitchen
                      ? 'Back to recipes'
                      : 'Kitchen',
                  label: 'Kitchen',
                  buttonKey: const Key('open-kitchen'),
                  icon: Icon(
                    controller.page == AppPage.kitchen
                        ? Icons.kitchen
                        : Icons.kitchen_outlined,
                  ),
                  onPressed: controller.page == AppPage.kitchen
                      ? controller.showLibrary
                      : controller.showKitchen,
                ),
              ],
              IconButton(
                key: const Key('open-settings'),
                tooltip: onSettings ? 'Back to recipes' : 'Settings',
                onPressed: onSettings
                    ? controller.showLibrary
                    : controller.showSettings,
                icon: Icon(
                  onSettings ? Icons.arrow_back : Icons.settings_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.wide,
    required this.selected,
    required this.tooltip,
    required this.label,
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
  });

  final bool wide;
  final bool selected;
  final String tooltip;
  final String label;
  final Key buttonKey;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        isSelected: selected,
        icon: icon,
      );
    }
    if (selected) {
      return FilledButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.busy,
    required this.wide,
    required this.onPressed,
  });

  final bool busy;
  final bool wide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'Sync';
    final icon = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.sync);
    if (!wide) {
      return IconButton(
        key: const Key('sync-button'),
        tooltip: 'Sync (F5)',
        onPressed: busy ? null : onPressed,
        icon: icon,
      );
    }
    return FilledButton.icon(
      key: const Key('sync-button'),
      onPressed: busy ? null : onPressed,
      icon: icon,
      label: const Text(label),
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({
    required this.busy,
    required this.wide,
    required this.onPressed,
  });

  final bool busy;
  final bool wide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return IconButton(
        key: const Key('import-flavorish'),
        tooltip: 'Import Flavorish export',
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.file_download_outlined),
      );
    }
    return OutlinedButton.icon(
      key: const Key('import-flavorish'),
      onPressed: busy ? null : onPressed,
      icon: const Icon(Icons.file_download_outlined),
      label: const Text('Import Flavorish export'),
    );
  }
}
