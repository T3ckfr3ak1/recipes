import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../state/library_controller.dart';
import 'repo_meal_view.dart';

class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final pack = controller.activePack;
    final fromRepo = pack != null && controller.planSource == PlanSource.repo;
    final start = controller.planWeek;
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: fromRepo ? 980 : 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meal plan',
                  key: const Key('meal-plan-heading'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fromRepo
                      ? 'Meals, prep notes, and the meal pack from the recipe repo.'
                      : 'Choose a recipe for each meal. This plan stays on this device.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (pack != null) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<PlanSource>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: PlanSource.repo,
                        label: Text('Repo plan'),
                      ),
                      ButtonSegment(
                        value: PlanSource.device,
                        label: Text('My week'),
                      ),
                    ],
                    selected: {controller.planSource},
                    onSelectionChanged: (selection) {
                      controller.showPlanSource(selection.first);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                if (fromRepo)
                  RepoMealView(pack: pack)
                else ...[
                  Row(
                    children: [
                      IconButton(
                        key: const Key('meal-week-prev'),
                        tooltip: 'Previous week',
                        onPressed: () => controller.shiftWeek(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          formatWeekRange(start),
                          key: const Key('meal-week-label'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        key: const Key('meal-week-next'),
                        tooltip: 'Next week',
                        onPressed: () => controller.shiftWeek(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final day in days) ...[
                    _DayCard(day: day),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM d').format(day),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final slot in MealSlot.values) _SlotRow(day: day, slot: slot),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.day, required this.slot});

  final DateTime day;
  final MealSlot slot;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final recipeId = controller.mealPlan.recipeIdFor(day, slot);
    final recipe = recipeId == null ? null : controller.recipeById(recipeId);
    final missing = recipeId != null && recipe == null;
    final key = '${dateKey(day)}-${slot.name}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              slot.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: recipe == null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: missing
                        ? TextButton(
                            key: Key('meal-missing-$key'),
                            onPressed: () =>
                                controller.assignMeal(day, slot, null),
                            child: const Text('Recipe is gone. Clear'),
                          )
                        : TextButton(
                            key: Key('meal-add-$key'),
                            onPressed: () => _pick(context, controller),
                            child: const Text('Add recipe'),
                          ),
                  )
                : TextButton(
                    key: Key('meal-open-$key'),
                    onPressed: () {
                      controller.select(recipe.id);
                      controller.showLibrary();
                    },
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(recipe.title, overflow: TextOverflow.ellipsis),
                  ),
          ),
          if (recipe != null)
            IconButton(
              key: Key('meal-clear-$key'),
              tooltip: 'Clear ${slot.label.toLowerCase()}',
              onPressed: () => controller.assignMeal(day, slot, null),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, LibraryController controller) async {
    final id = await showDialog<String>(
      context: context,
      builder: (context) => _RecipePicker(recipes: controller.recipes),
    );
    if (id == null) return;
    await controller.assignMeal(day, slot, id);
  }
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.recipes});

  final List<Recipe> recipes;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final recipe in widget.recipes)
        if (query.isEmpty || recipe.title.toLowerCase().contains(query)) recipe,
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return AlertDialog(
      title: const Text('Choose a recipe'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              key: const Key('meal-pick-search'),
              decoration: const InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No recipes match.'))
                  : ListView(
                      children: [
                        for (final recipe in visible)
                          ListTile(
                            key: Key('meal-pick-${recipe.id}'),
                            title: Text(recipe.title),
                            onTap: () => Navigator.pop(context, recipe.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

String formatWeekRange(DateTime start) {
  final end = start.add(const Duration(days: 6));
  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat('MMM d').format(start)} – ${DateFormat('d, yyyy').format(end)}';
  }
  if (start.year == end.year) {
    return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }
  return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
}
