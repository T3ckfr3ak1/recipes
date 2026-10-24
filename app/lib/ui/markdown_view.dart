import 'package:flutter/material.dart';

import '../logic/markdown_doc.dart';
import '../logic/meal_pack.dart';

class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.data, this.onLink});

  final String data;
  final void Function(String href)? onLink;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdown(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          _block(context, block),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _block(BuildContext context, MdBlock block) {
    return switch (block) {
      MdHeading(:final level, :final spans) => Text.rich(
        _span(context, spans, heading: true),
        style: switch (level) {
          1 => Theme.of(context).textTheme.headlineSmall,
          2 => Theme.of(context).textTheme.titleLarge,
          _ => Theme.of(context).textTheme.titleMedium,
        }?.copyWith(fontWeight: FontWeight.w700),
      ),
      MdParagraph(:final spans) => Text.rich(_span(context, spans)),
      MdBullet(:final spans) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text.rich(_span(context, spans))),
        ],
      ),
      MdQuote(:final spans) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text.rich(
            _span(context, spans),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
      MdTable(:final header, :final rows) => _table(context, header, rows),
    };
  }

  Widget _table(
    BuildContext context,
    List<List<MdSpan>> header,
    List<List<List<MdSpan>>> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: scheme.outlineVariant),
        children: [
          TableRow(
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
            children: [
              for (final cell in header)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text.rich(
                    _span(context, cell),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (final cell in row)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text.rich(_span(context, cell)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  TextSpan _span(
    BuildContext context,
    List<MdSpan> spans, {
    bool heading = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextSpan(
      children: [
        for (final span in spans)
          switch (span) {
            MdText(:final text) => TextSpan(text: text),
            MdBold(:final text) => TextSpan(
              text: text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            MdCode(:final text) => TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'Consolas',
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            MdLink(:final label, :final href) => _link(
              context,
              label,
              href,
              heading,
            ),
          },
      ],
    );
  }

  InlineSpan _link(
    BuildContext context,
    String label,
    String href,
    bool heading,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final recipeId = recipeIdFromHref(href);
    if (recipeId != null && onLink != null && !heading) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => onLink!(href),
          child: Text(label.isEmpty ? recipeId : label),
        ),
      );
    }
    final shown = label.isEmpty ? href : label;
    return TextSpan(
      text: shown,
      style: TextStyle(
        color: scheme.primary,
        decoration: TextDecoration.underline,
        fontWeight: heading ? FontWeight.w700 : null,
      ),
    );
  }
}
