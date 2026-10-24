import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/meal_pack.dart';
import '../models/meal_plan.dart';
import '../models/repo_doc.dart';
import '../state/library_controller.dart';
import '../storage/safe_path.dart';
import 'markdown_view.dart';
import 'pdf_pack_page.dart';

class RepoMealView extends StatelessWidget {
  const RepoMealView({super.key, required this.pack});

  final MealPack pack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final packs = controller.datedPacks;
    final today = dateOnly(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pack.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (packs.length > 1) ...[
          const SizedBox(height: 8),
          DropdownButton<String>(
            key: const Key('meal-pack-picker'),
            isExpanded: true,
            value: pack.path,
            items: [
              for (final item in packs)
                DropdownMenuItem(value: item.path, child: Text(item.title)),
            ],
            onChanged: (path) {
              if (path != null) controller.showPack(path);
            },
          ),
        ],
        if (pack.snacks != null) ...[
          const SizedBox(height: 8),
          Text(pack.snacks!, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('meal-read-plan'),
              onPressed: () => _read(context, pack.title, pack.body),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Read the full plan'),
            ),
            for (final pdf in controller.mealPdfs)
              OutlinedButton.icon(
                key: Key('meal-open-pdf-${pdf.path}'),
                onPressed: () => _openPdf(context, pdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(pdf.title),
              ),
            for (final guide in controller.mealGuides)
              TextButton(
                onPressed: () => _read(context, guide.title, guide.body),
                child: Text(guide.title),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (pack.days.isEmpty)
          Text(
            'This plan has no day table yet.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final two = constraints.maxWidth >= 760;
              final width = two
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final day in pack.days)
                    SizedBox(
                      width: width,
                      child: _DayCard(
                        day: day,
                        pack: pack,
                        today: day.date != null && dateOnly(day.date!) == today,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  void _read(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _NotePage(title: title, body: body),
      ),
    );
  }

  Future<void> _openPdf(BuildContext context, RepoDoc doc) async {
    final relative = doc.filePath;
    final controller = context.read<LibraryController>();
    final file = relative == null
        ? null
        : fileInside(controller.supportDirectory, relative);
    if (file == null || !await file.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The meal pack is not on this device yet. Sync and try again.',
          ),
        ),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PdfPackPage(title: doc.title, bytes: bytes),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.pack, required this.today});

  final MealDay day;
  final MealPack pack;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = day.date;
    final heading = date == null
        ? day.label
        : DateFormat('EEEE, MMM d').format(date);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: today ? scheme.primary : scheme.outlineVariant,
          width: today ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    heading,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (today)
                  Text(
                    'Today',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (date != null && day.label.contains('(')) ...[
              const SizedBox(height: 2),
              Text(
                day.label,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            _Slot(label: 'Breakfast', text: day.breakfast),
            _Slot(label: 'Lunch', text: day.lunch),
            _Slot(label: 'Dinner', text: day.dinner),
            if (day.codes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final code in day.codes)
                    _CodeChip(day: day, pack: pack, code: code),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              empty ? '—' : text,
              style: TextStyle(
                color: empty ? scheme.outline : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.day, required this.pack, required this.code});

  final MealDay day;
  final MealPack pack;
  final String code;

  @override
  Widget build(BuildContext context) {
    final linked = pack.recipeFor(code);
    final id = linked?.recipeId;
    final title = linked == null || linked.title == code
        ? code
        : '$code · ${linked.title}';
    if (id == null) {
      return Chip(label: Text(title), visualDensity: VisualDensity.compact);
    }
    final stamp = day.date == null
        ? day.label
        : '${day.date!.year}-${day.date!.month}-${day.date!.day}';
    return ActionChip(
      key: Key('meal-pack-$stamp-$code'),
      visualDensity: VisualDensity.compact,
      label: Text(title),
      onPressed: () => _open(context, id),
    );
  }

  void _open(BuildContext context, String id) {
    final controller = context.read<LibraryController>();
    final opened = controller.openLinkedRecipe('recipes/$id.json');
    if (opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'That recipe is not on this device yet. Sync and try again.',
        ),
      ),
    );
  }
}

class _NotePage extends StatelessWidget {
  const _NotePage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          MarkdownView(
            data: body,
            onLink: (href) {
              final controller = context.read<LibraryController>();
              final opened = controller.openLinkedRecipe(href);
              if (!opened) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'That recipe is not on this device yet. Sync and try again.',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
