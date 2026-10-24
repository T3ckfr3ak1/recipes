final _mixed = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$');
final _mixedHyphen = RegExp(r'^(\d+)\s*-\s*(\d+)\s*/\s*(\d+)$');
final _fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$');
final _decimal = RegExp(r'^(\d+)(?:\.(\d+))?$');

const _unicodeFractions = {
  '½': '1/2',
  '⅓': '1/3',
  '⅔': '2/3',
  '¼': '1/4',
  '¾': '3/4',
  '⅛': '1/8',
  '⅜': '3/8',
  '⅝': '5/8',
  '⅞': '7/8',
};

/// Reads a recipe amount. Returns null when the text is not a single number
/// or fraction, so phrases like "to taste" stay unscaled.
double? tryParseQuantity(String? raw) {
  if (raw == null) return null;
  var text = raw.trim();
  if (text.isEmpty) return null;
  _unicodeFractions.forEach((symbol, ascii) {
    text = text.replaceAll(symbol, ascii);
  });
  text = text.replaceAll(RegExp(r'\s+'), ' ');

  final mixed = _mixed.firstMatch(text) ?? _mixedHyphen.firstMatch(text);
  if (mixed != null) {
    final whole = int.parse(mixed.group(1)!);
    final numerator = int.parse(mixed.group(2)!);
    final denominator = int.parse(mixed.group(3)!);
    if (denominator == 0) return null;
    return whole + numerator / denominator;
  }
  final fraction = _fraction.firstMatch(text);
  if (fraction != null) {
    final denominator = int.parse(fraction.group(2)!);
    if (denominator == 0) return null;
    return int.parse(fraction.group(1)!) / denominator;
  }
  if (_decimal.hasMatch(text)) return double.parse(text);
  return null;
}

String formatServings(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return _trimDecimal(value);
}

String formatQuantity(double value) {
  if (value.isNaN || value.isInfinite) return '';
  final nearest = value.roundToDouble();
  if ((value - nearest).abs() < 0.02) return nearest.toInt().toString();

  final negative = value < 0;
  final absolute = value.abs();
  final whole = absolute.floor();
  final remainder = absolute - whole;
  String? best;
  var bestError = 0.02;
  for (final denominator in [2, 3, 4, 8]) {
    final numerator = (remainder * denominator).round();
    if (numerator <= 0 || numerator >= denominator) continue;
    final error = (remainder - numerator / denominator).abs();
    if (error < bestError) {
      bestError = error;
      best = _reduce(numerator, denominator);
    }
  }
  final body = best == null
      ? _trimDecimal(absolute)
      : whole == 0
      ? best
      : '$whole $best';
  return negative ? '-$body' : body;
}

String formatDecimalQuantity(double value) {
  if (value.isNaN || value.isInfinite) return '';
  return _trimDecimal(value);
}

String _reduce(int numerator, int denominator) {
  final divisor = _gcd(numerator, denominator);
  return '${numerator ~/ divisor}/${denominator ~/ divisor}';
}

int _gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final next = x % y;
    x = y;
    y = next;
  }
  return x == 0 ? 1 : x;
}

String _trimDecimal(double value) {
  var text = value.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}
