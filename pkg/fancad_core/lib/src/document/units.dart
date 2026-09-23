/// Drawing insertion units, matching DXF `$INSUNITS`.
///
/// Coordinates in the document stay in these units. The enum exists so a
/// command, an importer and a dimension formatter cannot disagree about what
/// `$INSUNITS` 4 means.
enum InsUnits {
  unitless(0, 'unitless', 0),
  inches(1, 'inches', 0.0254),
  feet(2, 'feet', 0.3048),
  miles(3, 'miles', 1609.344),
  millimeters(4, 'millimeters', 0.001),
  centimeters(5, 'centimeters', 0.01),
  meters(6, 'meters', 1),
  kilometers(7, 'kilometers', 1000);

  const InsUnits(this.code, this.label, this.metersPerUnit);

  /// DXF group 70 value for `$INSUNITS`.
  final int code;
  final String label;

  /// How many metres one drawing unit is. Zero for [unitless].
  final double metersPerUnit;

  static const List<InsUnits> known = InsUnits.values;

  static InsUnits fromCode(int code) {
    for (final unit in values) {
      if (unit.code == code) return unit;
    }
    return InsUnits.unitless;
  }

  static InsUnits fromHeader(String? raw) {
    final code = int.tryParse(raw ?? '') ?? 0;
    return fromCode(code);
  }

  /// Accepts a DXF code (`4`) or a unique prefix of the label (`mm`, `in`).
  static InsUnits? parse(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    final code = int.tryParse(trimmed);
    if (code != null) return fromCode(code);
    const aliases = <String, InsUnits>{
      'unitless': InsUnits.unitless,
      'none': InsUnits.unitless,
      'in': InsUnits.inches,
      'inch': InsUnits.inches,
      'inches': InsUnits.inches,
      'ft': InsUnits.feet,
      'foot': InsUnits.feet,
      'feet': InsUnits.feet,
      'mi': InsUnits.miles,
      'mile': InsUnits.miles,
      'miles': InsUnits.miles,
      'mm': InsUnits.millimeters,
      'millimeter': InsUnits.millimeters,
      'millimeters': InsUnits.millimeters,
      'cm': InsUnits.centimeters,
      'centimeter': InsUnits.centimeters,
      'centimeters': InsUnits.centimeters,
      'm': InsUnits.meters,
      'meter': InsUnits.meters,
      'metre': InsUnits.meters,
      'meters': InsUnits.meters,
      'metres': InsUnits.meters,
      'km': InsUnits.kilometers,
      'kilometer': InsUnits.kilometers,
      'kilometers': InsUnits.kilometers,
    };
    final exact = aliases[trimmed];
    if (exact != null) return exact;
    InsUnits? match;
    for (final entry in aliases.entries) {
      if (!entry.key.startsWith(trimmed)) continue;
      if (match != null && match != entry.value) return null;
      match = entry.value;
    }
    return match;
  }

  double toMeters(double value) => value * metersPerUnit;

  double fromMeters(double meters) =>
      metersPerUnit == 0 ? meters : meters / metersPerUnit;

  /// Converts [value] from this unit into [other]. Unitless values pass through.
  double convertTo(double value, InsUnits other) {
    if (this == other || metersPerUnit == 0 || other.metersPerUnit == 0) {
      return value;
    }
    return other.fromMeters(toMeters(value));
  }
}
