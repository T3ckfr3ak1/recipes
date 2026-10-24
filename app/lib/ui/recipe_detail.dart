import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/quantities.dart';
import '../logic/scaled_recipe.dart';
import '../models/air_fry.dart';
import '../models/recipe.dart';
import '../state/library_controller.dart';
import '../storage/safe_path.dart';
import 'format.dart';
import 'print_page.dart';

class RecipeDetail extends StatefulWidget {
  const RecipeDetail({super.key, required this.recipe, this.onBack});

  final Recipe recipe;
  final VoidCallback? onBack;

  @override
  State<RecipeDetail> createState() => _RecipeDetailState();
}

class _RecipeDetailState extends State<RecipeDetail> {
  late double? _target;
  late final TextEditingController _servings;

  @override
  void initState() {
    super.initState();
    _target = widget.recipe.servings;
    _servings = TextEditingController(text: formatServings(_target));
  }

  @override
  void didUpdateWidget(RecipeDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.id != widget.recipe.id) {
      _target = widget.recipe.servings;
      _servings.text = formatServings(_target);
    }
  }

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final recipe = widget.recipe;
    final settings = controller.settings;
    final scheme = Theme.of(context).colorScheme;
    final scaled = scaleRecipe(recipe, _target, settings.quantityStyle);
    final canScale = recipe.servings != null && recipe.servings! > 0;
    final time = cookTimeLabel(recipe);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            children: [
              if (widget.onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('All recipes'),
                  ),
                ),
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    key: const Key('toggle-made'),
                    label: Text(
                      controller.isMade(recipe.id) ? 'Made' : 'Mark as made',
                    ),
                    selected: controller.isMade(recipe.id),
                    avatar: Icon(
                      controller.isMade(recipe.id)
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 18,
                    ),
                    onSelected: (_) => controller.toggleMade(recipe.id),
                  ),
                  FilterChip(
                    key: const Key('toggle-star'),
                    label: Text(
                      controller.isStarred(recipe.id) ? 'Starred' : 'Star',
                    ),
                    selected: controller.isStarred(recipe.id),
                    avatar: Icon(
                      controller.isStarred(recipe.id)
                          ? Icons.star
                          : Icons.star_border,
                      size: 18,
                    ),
                    onSelected: (_) => controller.toggleStarred(recipe.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Banner(readOnly: recipe.isReadOnly),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (recipe.category.trim().isNotEmpty)
                    ActionChip(
                      label: Text(recipe.category.trim()),
                      onPressed: () =>
                          controller.setCategory(recipe.category.trim()),
                    ),
                  if (time.isNotEmpty)
                    Chip(
                      label: Text(time),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (recipe.source.trim().isNotEmpty)
                    Chip(
                      label: Text(recipe.source.trim()),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (recipe.imagePaths.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recipe.imagePaths.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final file = fileInside(
                        controller.supportDirectory,
                        recipe.imagePaths[index],
                      );
                      if (file == null) return const SizedBox.shrink();
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          file,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox(
                                width: 180,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (canScale)
                _ServingsScaler(
                  controller: _servings,
                  base: recipe.servings!,
                  target: _target,
                  onChanged: (value) => setState(() => _target = value),
                )
              else
                Text(
                  'Servings are not set, so amounts stay as written.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              if (scaled.isScaled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Scaled from ${formatServings(recipe.servings)} to ${formatServings(_target)}.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (scaled.leftSomeUnscaled)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Some amounts aren't numeric and were left as written.",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (settings.showDescription &&
                  recipe.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(recipe.description),
              ],
              const SizedBox(height: 24),
              const _SectionTitle('Ingredients'),
              const SizedBox(height: 8),
              for (final ingredient in scaled.ingredients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ingredient.line),
                      if (ingredient.note != null &&
                          ingredient.note!.trim().isNotEmpty)
                        Text(
                          ingredient.note!,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const _SectionTitle('Steps'),
              const SizedBox(height: 8),
              for (var i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: Text(recipe.steps[i])),
                    ],
                  ),
                ),
              if (settings.showAirFry && recipe.airFry != null) ...[
                const SizedBox(height: 8),
                _AirFryCard(airFry: recipe.airFry!),
              ],
              if (settings.showNotes && recipe.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Notes'),
                const SizedBox(height: 8),
                Text(recipe.notes),
              ],
              if (recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in recipe.tags)
                      ActionChip(
                        label: Text(tag),
                        onPressed: () => controller.setTag(tag),
                      ),
                  ],
                ),
              ],
              if (!recipe.isReadOnly) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('remove-local'),
                    onPressed: () => _remove(context, recipe),
                    child: const Text('Remove from this computer'),
                  ),
                ),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('print-recipe'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => PrintPage(
                        view: scaled,
                        settings: settings,
                        supportDirectory: controller.supportDirectory,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print view'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this recipe?'),
        content: const Text(
          'This removes the copy on this computer. Recipe Keeper is unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<LibraryController>().removeLocal(recipe.id);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.readOnly});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = readOnly
        ? 'Read-only. Recipe Keeper is the source of truth.'
        : 'Saved on this computer. Sync publishes it to the recipe repo.';
    return Container(
      key: Key(readOnly ? 'readonly-banner' : 'local-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }
}

class _ServingsScaler extends StatelessWidget {
  const _ServingsScaler({
    required this.controller,
    required this.base,
    required this.target,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double base;
  final double? target;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Servings'),
        const SizedBox(width: 12),
        IconButton(
          key: const Key('servings-minus'),
          tooltip: 'Fewer servings',
          onPressed: () => _step(-1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 72,
          child: TextField(
            key: const Key('servings-field'),
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onSubmitted: _commit,
            onEditingComplete: () => _commit(controller.text),
          ),
        ),
        IconButton(
          key: const Key('servings-plus'),
          tooltip: 'More servings',
          onPressed: () => _step(1),
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 8),
        Text('Recipe serves ${formatServings(base)}'),
      ],
    );
  }

  void _step(int direction) {
    final current = target ?? base;
    final next = current + direction;
    if (next <= 0 || next > 10000) return;
    controller.text = formatServings(next);
    onChanged(next);
  }

  void _commit(String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null || parsed <= 0 || parsed > 10000) {
      controller.text = formatServings(target ?? base);
      return;
    }
    controller.text = formatServings(parsed);
    onChanged(parsed);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _AirFryCard extends StatelessWidget {
  const _AirFryCard({required this.airFry});

  final AirFry airFry;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (airFry.rack != null) 'Rack ${airFry.rack}',
      if (airFry.preheat != null) airFry.preheat! ? 'Preheat' : 'No preheat',
      if (airFry.tempF != null) '${formatServings(airFry.tempF)}°F',
      if (airFry.minutes != null) '${formatServings(airFry.minutes)} min',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Air fryer'),
            const SizedBox(height: 8),
            Text(lines.join(' · ')),
          ],
        ),
      ),
    );
  }
}
