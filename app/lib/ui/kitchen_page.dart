import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_controller.dart';
import 'markdown_view.dart';

class KitchenPage extends StatelessWidget {
  const KitchenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final controller = context.watch<LibraryController>();
        final selected = controller.selectedDoc;
        if (!wide && selected != null) {
          return _DocDetail(
            title: selected.title,
            body: selected.body,
            onBack: () => controller.selectDoc(null),
          );
        }
        return Row(
          children: [
            SizedBox(
              width: wide ? 360 : constraints.maxWidth,
              child: const _DocList(),
            ),
            if (wide) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const _EmptyDoc()
                    : _DocDetail(title: selected.title, body: selected.body),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DocList extends StatelessWidget {
  const _DocList();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final section = controller.kitchenSection;
    final docs = controller.docsFor(section);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Kitchen',
            key: const Key('kitchen-heading'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<KitchenSection>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: KitchenSection.equipment,
                  label: Text('Equipment'),
                ),
                ButtonSegment(
                  value: KitchenSection.methods,
                  label: Text('Methods'),
                ),
                ButtonSegment(
                  value: KitchenSection.preferences,
                  label: Text('Preferences'),
                ),
              ],
              selected: {section},
              onSelectionChanged: (selection) {
                controller.showKitchenSection(selection.first);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            docs.isEmpty
                ? 'Sync to load these from the recipe repo.'
                : '${docs.length} ${docs.length == 1 ? 'note' : 'notes'}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: scheme.outlineVariant),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final selected = doc.path == controller.selectedDocPath;
              return Material(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                child: InkWell(
                  key: Key('doc-${doc.path}'),
                  onTap: () => controller.selectDoc(doc.path),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      doc.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DocDetail extends StatelessWidget {
  const _DocDetail({required this.title, required this.body, this.onBack});

  final String title;
  final String body;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('All notes'),
            ),
          ),
        MarkdownView(
          data: body.isEmpty
              ? '# $title\n\nNothing is written in this note yet.'
              : body,
          onLink: (href) {
            final controller = context.read<LibraryController>();
            final opened = controller.openLinkedRecipe(href);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'That recipe is not on this device yet. Sync and try again.',
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _EmptyDoc extends StatelessWidget {
  const _EmptyDoc();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Choose a note.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
