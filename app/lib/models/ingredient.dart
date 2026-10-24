import '../logic/quantities.dart';

final class Ingredient {
  const Ingredient({
    required this.quantity,
    required this.unit,
    required this.item,
    this.note,
    this.quantityValue,
  });

  final String quantity;
  final String unit;
  final String item;
  final String? note;

  /// Numeric reading of [quantity], when the amount can be scaled.
  final double? quantityValue;

  Map<String, Object?> toJson() => {
    'quantity': quantity,
    'unit': unit,
    'item': item,
    'note': note,
    'quantity_value': quantityValue,
  };

  static Ingredient fromKeeperJson(Object? value, {required int index}) {
    if (value is! Map) {
      throw FormatException('ingredients[$index] must be an object');
    }
    final map = value.map((key, entry) => MapEntry(key.toString(), entry));
    final item = _requiredText(map['item'], 'ingredients[$index].item');
    final unit = _optionalText(map['unit'], 'ingredients[$index].unit');
    final note = _optionalText(map['note'], 'ingredients[$index].note');
    final quantity = _quantityText(map['quantity'], index);
    return Ingredient(
      quantity: quantity,
      unit: unit,
      item: item,
      note: note.isEmpty ? null : note,
      quantityValue: tryParseQuantity(quantity),
    );
  }

  static Ingredient fromStorage(Map<String, Object?> map) {
    final quantity = map['quantity'] as String? ?? '';
    final storedValue = map['quantity_value'];
    return Ingredient(
      quantity: quantity,
      unit: map['unit'] as String? ?? '',
      item: map['item'] as String? ?? '',
      note: map['note'] as String?,
      quantityValue: storedValue is num
          ? storedValue.toDouble()
          : tryParseQuantity(quantity),
    );
  }
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be text');
  }
  return value.trim();
}

String _optionalText(Object? value, String field) {
  if (value == null) return '';
  if (value is! String) throw FormatException('$field must be text');
  return value.trim();
}

String _quantityText(Object? value, int index) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
  throw FormatException(
    'ingredients[$index].quantity must be text or a number',
  );
}
