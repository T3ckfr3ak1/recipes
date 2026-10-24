final class AirFry {
  const AirFry({this.rack, this.preheat, this.tempF, this.minutes});

  final String? rack;
  final bool? preheat;
  final double? tempF;
  final double? minutes;

  bool get isEmpty =>
      (rack == null || rack!.trim().isEmpty) &&
      preheat == null &&
      tempF == null &&
      minutes == null;

  Map<String, Object?> toJson() => {
    'rack': rack,
    'preheat': preheat,
    'temp_f': tempF,
    'minutes': minutes,
  };

  static AirFry? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('air_fry must be an object');
    }
    final map = value.map((key, entry) => MapEntry(key.toString(), entry));
    final rackRaw = map['rack'];
    String? rack;
    if (rackRaw != null) {
      if (rackRaw is! String && rackRaw is! num) {
        throw const FormatException('air_fry.rack must be text or a number');
      }
      rack = rackRaw.toString().trim();
      if (rack.isEmpty) rack = null;
    }
    final airFry = AirFry(
      rack: rack,
      preheat: _optionalBool(map['preheat'], 'air_fry.preheat'),
      tempF: _optionalDouble(map['temp_f'], 'air_fry.temp_f'),
      minutes: _optionalDouble(map['minutes'], 'air_fry.minutes'),
    );
    return airFry.isEmpty ? null : airFry;
  }

  static AirFry? fromStorage(Object? value) {
    if (value == null) return null;
    if (value is! Map) return null;
    return fromJson(value);
  }
}

bool? _optionalBool(Object? value, String field) {
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('$field must be true or false');
}

double? _optionalDouble(Object? value, String field) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('$field must be a number');
}
