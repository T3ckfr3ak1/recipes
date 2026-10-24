import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/recipe_origin.dart';
import '../state/library_controller.dart';
import 'format.dart';
import 'recipe_detail.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final controller = context.watch<LibraryController>();
        final selected = controller.selected;
        if (!wide && selected != null) {
          return RecipeDetail(
            recipe: selected,
            onBack: () => controller.select(null),
          );
        }
        return Row(
          children: [
            SizedBox(
              width: wide ? 360 : constraints.maxWidth,
              child: const _RecipeList(),
            ),
            if (wide) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const _EmptyDetail()
                    : RecipeDetail(recipe: selected),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final visible = controller.visible;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _FilterMenu(
                  label: 'Category',
                  value: _known(
                    controller.categoryFilter,
                    controller.categories,
                  ),
                  allLabel: 'All categories',
                  options: controller.categories,
                  onChanged: controller.setCategory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterMenu(
                  label: 'Tag',
                  value: _known(controller.tagFilter, controller.tags),
                  allLabel: 'All tags',
                  options: controller.tags,
                  onChanged: controller.setTag,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _Choice(
                chipKey: const Key('filter-made'),
                label: 'Made',
                selected: controller.madeOnly,
                onSelected: controller.setMadeOnly,
              ),
              const SizedBox(width: 8),
              _Choice(
                chipKey: const Key('filter-starred'),
                label: 'Starred',
                selected: controller.starredOnly,
                onSelected: controller.setStarredOnly,
              ),
              for (final meal in controller.mealChoices) ...[
                const SizedBox(width: 8),
                _Choice(
                  chipKey: Key('filter-meal-$meal'),
                  label: meal,
                  selected: controller.mealFilter == meal,
                  onSelected: (selected) =>
                      controller.setMeal(selected ? meal : null),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${visible.length} ${visible.length == 1 ? 'recipe' : 'recipes'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      controller.recipes.isEmpty
                          ? 'No recipes yet. Sync from Recipe Keeper, or import a Flavorish export. Saved recipes stay available offline.'
                          : 'Nothing matches those filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: scheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final recipe = visible[index];
                    final selected = recipe.id == controller.selectedId;
                    return _RecipeTile(recipe: recipe, selected: selected);
                  },
                ),
        ),
      ],
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe, required this.selected});

  final Recipe recipe;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<LibraryController>();
    final scheme = Theme.of(context).colorScheme;
    final time = cookTimeLabel(recipe);
    final made = controller.isMade(recipe.id);
    final starred = controller.isStarred(recipe.id);
    final subtitle = [
      if (recipe.category.trim().isNotEmpty) recipe.category.trim(),
      if (time.isNotEmpty) time,
    ].join(' · ');
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      child: InkWell(
        key: Key('recipe-${recipe.id}'),
        onTap: () => controller.select(recipe.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (made) Icon(Icons.check, size: 16, color: scheme.primary),
                  if (starred)
                    Icon(Icons.star, size: 16, color: scheme.primary),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (recipe.origin == RecipeOrigin.local) ...[
                const SizedBox(height: 4),
                Text(
                  'Flavorish',
                  style: TextStyle(
                    color: scheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FilterChip(
        key: chipKey,
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: onSelected,
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String allLabel;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: Key('filter-$label'),
          value: value,
          isExpanded: true,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            for (final option in options)
              DropdownMenuItem<String?>(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select a recipe',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

String? _known(String? value, List<String> options) {
  if (value == null) return null;
  return options.contains(value) ? value : null;
}
