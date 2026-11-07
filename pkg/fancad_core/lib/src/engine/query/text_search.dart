import '../../geometry/bounds.dart';
import '../../geometry/vector.dart';
import '../document.dart';

/// What a canvas text search hit is, so the UI can label it without
/// re-reading the entity.
enum TextSearchKind { text, mtext, attribute, mleader, dimension }

/// One piece of text that is actually drawn in the current space.
///
/// [selectId] is the object the user can select: the text itself, or the
/// insert that carries a block's text. [bounds] and [height] are in the same
/// coordinates as the canvas, after the block base point and insert transform.
class TextSearchHit {
  const TextSearchHit({
    required this.selectId,
    required this.kind,
    required this.text,
    required this.layer,
    required this.bounds,
    required this.height,
    required this.anchor,
    this.tag,
  });

  final int selectId;
  final TextSearchKind kind;
  final String text;
  final String layer;
  final String? tag;
  final Bounds2 bounds;
  final double height;

  /// Sort key. Y is up, so a larger Y is higher on the sheet.
  final Vec2 anchor;
}

/// The standard text-search contract for a drawing.
///
/// The engine defines the result shape; the host implements the walk. A
/// headless app, a renderer or an AI bridge can provide its own search without
/// putting presentation or indexing policy into the document model.
abstract interface class TextSearchService {
  /// All visible text in the document's current layout or edited block,
  /// ordered top-to-bottom then left-to-right.
  List<TextSearchHit> hits(CadDocument document);

  /// Case-insensitive substring search. An empty query matches nothing.
  List<TextSearchHit> search(CadDocument document, String query);
}
