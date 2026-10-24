import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../share/incoming_share.dart';
import '../share/share_resolver.dart';
import '../state/library_controller.dart';
import '../sync/sync_exception.dart';

class SharedRecipePage extends StatefulWidget {
  const SharedRecipePage({super.key, required this.share});

  final IncomingShare share;

  @override
  State<SharedRecipePage> createState() => _SharedRecipePageState();
}

class _SharedRecipePageState extends State<SharedRecipePage> {
  ShareResolution? _resolution;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final resolution = await context.read<LibraryController>().inspectShare(
        widget.share,
      );
      if (!mounted) return;
      setState(() => _resolution = resolution);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolution = _resolution;
    final recipe = resolution?.recipe;
    final controller = context.watch<LibraryController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Shared video')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_error != null && resolution == null)
            Text(_error!, key: const Key('share-detail'))
          else if (resolution == null)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Reading the description…'),
              ],
            )
          else if (recipe == null)
            Text(resolution.detail, key: const Key('share-detail'))
          else ...[
            Text(
              recipe.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Found in the video description. Saving writes it to the recipe repo.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (recipe.servings != null ||
                recipe.prepMinutes != null ||
                recipe.cookMinutes != null) ...[
              const SizedBox(height: 12),
              Text(
                _meta(recipe.servings, recipe.prepMinutes, recipe.cookMinutes),
              ),
            ],
            const SizedBox(height: 16),
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final ingredient in recipe.ingredients)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _ingredientLine(
                    ingredient.quantity,
                    ingredient.unit,
                    ingredient.item,
                  ),
                ),
              ),
            if (recipe.steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Steps', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${i + 1}. ${recipe.steps[i]}'),
                ),
            ],
            if (!controller.githubKeySaved) ...[
              const SizedBox(height: 16),
              Text(
                'Add a GitHub key in Settings before this can be saved.',
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  controller.showSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('Open settings'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('share-save-error'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('share-save'),
              onPressed:
                  _saving || controller.busy || !controller.githubKeySaved
                  ? null
                  : () => _save(controller),
              child: Text(_saving ? 'Saving…' : 'Save to repo'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(LibraryController controller) async {
    final recipe = _resolution?.recipe;
    if (recipe == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await controller.publishRecipe(recipe);
      if (!mounted) return;
      controller.select(saved.id);
      controller.showLibrary();
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Saved "${saved.title}" to the recipe repo.')),
      );
    } on SyncException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }
}

String _meta(double? servings, int? prep, int? cook) {
  return [
    if (servings != null) 'Serves ${_trim(servings)}',
    if (prep != null) 'Prep $prep min',
    if (cook != null) 'Cook $cook min',
  ].join(' · ');
}

String _trim(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}

String _ingredientLine(String quantity, String unit, String item) {
  return [
    quantity.trim(),
    unit.trim(),
    item.trim(),
  ].where((part) => part.isNotEmpty).join(' ');
}
