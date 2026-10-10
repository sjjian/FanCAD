part of 'entity.dart';

/// TEXT, MTEXT, ATTRIB, ATTDEF and MLEADER: the note properties DDEDIT, the
/// text overlay and the properties panel read and change.
///
/// A property a type does not have reads as null, and its `with` returns
/// null. Each type lists its fields once, in its `copyWith`, so a new field
/// cannot be dropped by one of these edits.
sealed class TextLike implements CadEntity {
  /// What DDEDIT edits: the content, an attribute's value, or an attribute
  /// definition's default.
  String get content;

  /// Where the note is anchored.
  Vec2 get position;

  double get height;

  /// Radians, counter-clockwise.
  double get rotation;

  String get styleName;

  /// TEXT-style horizontal stretch. MTEXT and MLEADER have none.
  double? get widthFactor;

  /// TEXT-style slant in radians. MTEXT and MLEADER have none.
  double? get obliqueAngle;

  /// MTEXT column width; 0 is unbounded. Only MTEXT has one.
  double? get columnWidth;

  TextLike withContent(String content);

  TextLike withHeight(double height);

  /// Turns the note about [position]. An MLEADER's leader lines stay put.
  TextLike withRotation(double radians);

  TextLike withStyleName(String styleName);

  TextLike? withWidthFactor(double widthFactor);

  TextLike? withObliqueAngle(double radians);

  TextLike? withColumnWidth(double width);
}
