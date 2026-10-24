import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

abstract interface class PageDescription {
  Future<String?> lookup(Uri url);
}

final class EmptyPageDescription implements PageDescription {
  const EmptyPageDescription();

  @override
  Future<String?> lookup(Uri url) async => null;
}

final class HttpPageDescription implements PageDescription {
  HttpPageDescription({required this.client, required this.timeout});

  final http.Client client;
  Duration timeout;

  static const _browserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';
  static const _botAgent =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';

  @override
  Future<String?> lookup(Uri url) async {
    if (url.scheme != 'http' && url.scheme != 'https') return null;
    if (_isFacebook(url)) {
      final bot = await _fetch(url, _botAgent);
      if (bot != null) return bot;
    }
    return _fetch(url, _browserAgent);
  }

  Future<String?> _fetch(Uri url, String userAgent) async {
    final http.Response response;
    try {
      response = await client
          .get(
            url,
            headers: {
              'User-Agent': userAgent,
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    }
    if (response.statusCode != 200) return null;
    final type = response.headers['content-type'] ?? '';
    if (type.contains('video') || type.contains('image')) return null;
    final body = response.body.length > 1500000
        ? response.body.substring(0, 1500000)
        : response.body;
    return descriptionFromHtml(body);
  }
}

bool _isFacebook(Uri url) {
  final host = url.host.toLowerCase();
  return host == 'fb.watch' ||
      host.endsWith('.facebook.com') ||
      host == 'facebook.com' ||
      host.endsWith('.fb.com') ||
      host == 'fb.com';
}

bool _isBoilerplate(String text) {
  final lower = text.toLowerCase();
  return lower.contains('log in to facebook') ||
      lower.contains('log into facebook') ||
      lower.contains('sign up for facebook') ||
      lower.contains('watch more reels');
}

/// The description attached to this page. Other recipes in the page are ignored.
String? descriptionFromHtml(String html) {
  final metas = RegExp(r'<meta\b[^>]*>', caseSensitive: false).allMatches(html);
  String? named;
  String? twitter;
  String? graph;
  for (final meta in metas) {
    final attrs = _attributes(meta.group(0)!);
    final key = (attrs['property'] ?? attrs['name'] ?? '').toLowerCase();
    final content = attrs['content'];
    if (content == null || content.trim().isEmpty) continue;
    final decoded = decodeHtmlEntities(content).trim();
    if (decoded.isEmpty || _isBoilerplate(decoded)) continue;
    if (key == 'og:description' && graph == null) graph = decoded;
    if (key == 'twitter:description' && twitter == null) twitter = decoded;
    if (key == 'description' && named == null) named = decoded;
  }
  return graph ?? twitter ?? named;
}

Map<String, String> _attributes(String tag) {
  final attrs = <String, String>{};
  final pattern = RegExp(
    '''([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'>]+))''',
  );
  for (final match in pattern.allMatches(tag)) {
    final name = match.group(1)!.toLowerCase();
    attrs[name] = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
  }
  return attrs;
}

String decodeHtmlEntities(String value) {
  final expanded = value.replaceAll('&amp;', '&');
  return expanded
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final code = int.tryParse(match.group(1)!, radix: 16);
        if (code == null || code < 0 || code > 0x10FFFF) {
          return match.group(0)!;
        }
        return String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1)!);
        if (code == null || code < 0 || code > 0x10FFFF) {
          return match.group(0)!;
        }
        return String.fromCharCode(code);
      })
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
