import 'description_recipe.dart';

final _urlPattern = RegExp(r'https?://[^\s<>"\]]+', caseSensitive: false);

/// Text a share sheet handed the app. Facebook usually sends the reel link,
/// and sometimes the caption in the same text.
final class IncomingShare {
  const IncomingShare({required this.text, this.subject = ''});

  final String text;
  final String subject;

  bool get isEmpty => text.trim().isEmpty && subject.trim().isEmpty;

  String? get url {
    final match = _urlPattern.firstMatch(text);
    if (match == null) return null;
    var raw = match.group(0)!;
    while (raw.endsWith('.') || raw.endsWith(',') || raw.endsWith(')')) {
      raw = raw.substring(0, raw.length - 1);
    }
    return raw;
  }

  /// Share text with the link removed. This is the caption when the app
  /// included one.
  String get caption {
    final withoutUrl = text.replaceAll(_urlPattern, ' ');
    return withoutUrl
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  static IncomingShare? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    final html = raw['html'];
    final subject = raw['subject'];
    final share = IncomingShare(
      text: combineShareText(
        text is String ? text : '',
        html is String ? html : '',
      ),
      subject: subject is String ? subject : '',
    );
    if (share.isEmpty) return null;
    return share;
  }
}

/// Prefers whichever share part actually contains the description.
String combineShareText(String text, String html) {
  final plain = plainShareText(text).trim();
  final fromHtml = plainShareText(html).trim();
  if (plain.isEmpty) return fromHtml;
  if (fromHtml.isEmpty) return plain;
  if (plain.contains(fromHtml)) return plain;
  if (fromHtml.contains(plain) && fromHtml.length > plain.length + 40) {
    return fromHtml;
  }
  return '$plain\n\n$fromHtml';
}
