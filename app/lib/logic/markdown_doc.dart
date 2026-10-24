sealed class MdBlock {}

final class MdHeading extends MdBlock {
  MdHeading(this.level, this.spans);

  final int level;
  final List<MdSpan> spans;
}

final class MdParagraph extends MdBlock {
  MdParagraph(this.spans);

  final List<MdSpan> spans;
}

final class MdBullet extends MdBlock {
  MdBullet(this.spans);

  final List<MdSpan> spans;
}

final class MdQuote extends MdBlock {
  MdQuote(this.spans);

  final List<MdSpan> spans;
}

final class MdTable extends MdBlock {
  MdTable(this.header, this.rows);

  final List<List<MdSpan>> header;
  final List<List<List<MdSpan>>> rows;
}

sealed class MdSpan {}

final class MdText extends MdSpan {
  MdText(this.text);

  final String text;
}

final class MdBold extends MdSpan {
  MdBold(this.text);

  final String text;
}

final class MdCode extends MdSpan {
  MdCode(this.text);

  final String text;
}

final class MdLink extends MdSpan {
  MdLink(this.label, this.href);

  final String label;
  final String href;
}

List<MdBlock> parseMarkdown(String source) {
  final lines = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final blocks = <MdBlock>[];
  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) {
      i++;
      continue;
    }
    if (trimmed.startsWith('|')) {
      final tableLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        tableLines.add(lines[i].trim());
        i++;
      }
      final table = _table(tableLines);
      if (table != null) blocks.add(table);
      continue;
    }
    final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      blocks.add(
        MdHeading(heading.group(1)!.length, inline(heading.group(2)!)),
      );
      i++;
      continue;
    }
    if (trimmed.startsWith('>')) {
      final quotes = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quotes.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      blocks.add(MdQuote(inline(quotes.join(' '))));
      continue;
    }
    if (RegExp(r'^[-*]\s+').hasMatch(trimmed)) {
      while (i < lines.length) {
        final item = RegExp(r'^[-*]\s+(.+)$').firstMatch(lines[i].trim());
        if (item == null) break;
        blocks.add(MdBullet(inline(item.group(1)!)));
        i++;
      }
      continue;
    }
    if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
      while (i < lines.length) {
        final item = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(lines[i].trim());
        if (item == null) break;
        blocks.add(MdBullet(inline('${item.group(1)}. ${item.group(2)}')));
        i++;
      }
      continue;
    }
    final paragraph = <String>[];
    while (i < lines.length &&
        lines[i].trim().isNotEmpty &&
        !_startsBlock(lines[i].trim())) {
      paragraph.add(lines[i].trim());
      i++;
    }
    if (paragraph.isNotEmpty) {
      blocks.add(MdParagraph(inline(paragraph.join(' '))));
    }
  }
  return blocks;
}

bool _startsBlock(String trimmed) {
  return trimmed.startsWith('|') ||
      trimmed.startsWith('>') ||
      trimmed.startsWith('#') ||
      RegExp(r'^[-*]\s+').hasMatch(trimmed) ||
      RegExp(r'^\d+\.\s+').hasMatch(trimmed);
}

List<MdSpan> inline(String input) {
  final spans = <MdSpan>[];
  final buffer = StringBuffer();
  var i = 0;
  void flush() {
    if (buffer.isEmpty) return;
    spans.add(MdText(buffer.toString()));
    buffer.clear();
  }

  while (i < input.length) {
    if (input.startsWith('**', i)) {
      final end = input.indexOf('**', i + 2);
      if (end > i) {
        flush();
        spans.add(MdBold(input.substring(i + 2, end)));
        i = end + 2;
        continue;
      }
    }
    if (input.startsWith('`', i)) {
      final end = input.indexOf('`', i + 1);
      if (end > i) {
        flush();
        spans.add(MdCode(input.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
    }
    if (input.startsWith('[', i)) {
      final close = input.indexOf(']', i + 1);
      if (close > i && close + 1 < input.length && input[close + 1] == '(') {
        final end = input.indexOf(')', close + 2);
        if (end > close) {
          flush();
          final label = input.substring(i + 1, close).replaceAll('`', '');
          final href = input.substring(close + 2, end).trim();
          spans.add(MdLink(label, href));
          i = end + 1;
          continue;
        }
      }
    }
    buffer.write(input[i]);
    i++;
  }
  flush();
  return spans;
}

MdTable? _table(List<String> lines) {
  final parsed = [for (final line in lines) _cells(line)];
  if (parsed.isEmpty) return null;
  final header = [for (final cell in parsed.first) inline(cell)];
  var start = 1;
  if (parsed.length > 1 &&
      parsed[1].isNotEmpty &&
      parsed[1].every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell))) {
    start = 2;
  }
  final width = header.length;
  final rows = <List<List<MdSpan>>>[];
  for (var index = start; index < parsed.length; index++) {
    final row = [for (final cell in parsed[index]) inline(cell)];
    while (row.length < width) {
      row.add(const <MdSpan>[]);
    }
    if (row.length > width) {
      rows.add(row.sublist(0, width));
    } else {
      rows.add(row);
    }
  }
  return MdTable(header, rows);
}

List<String> _cells(String line) {
  final parts = line.split('|');
  if (parts.isNotEmpty && parts.first.trim().isEmpty) parts.removeAt(0);
  if (parts.isNotEmpty && parts.last.trim().isEmpty) parts.removeLast();
  return [for (final part in parts) part.trim()];
}

String spanText(List<MdSpan> spans) {
  final buffer = StringBuffer();
  for (final span in spans) {
    buffer.write(switch (span) {
      MdText(:final text) => text,
      MdBold(:final text) => text,
      MdCode(:final text) => text,
      MdLink(:final label) => label,
    });
  }
  return buffer.toString();
}
