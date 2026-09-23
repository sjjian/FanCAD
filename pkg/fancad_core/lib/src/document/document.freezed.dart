// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BlockRecord {

 String get name; Vec2 get basePoint; List<int> get entityIds;/// True for `*Model_Space` and `*Paper_Space*`, which are containers rather
/// than insertable blocks.
 bool get isLayoutBlock;/// True for generated blocks such as the `*D` dimension geometry blocks and
/// `*U` hatch blocks, which are hidden from the block picker.
 bool get isAnonymous; String get description;/// Non-empty when this block is an external reference.
 String get xrefPath;
/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockRecordCopyWith<BlockRecord> get copyWith => _$BlockRecordCopyWithImpl<BlockRecord>(this as BlockRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlockRecord&&(identical(other.name, name) || other.name == name)&&(identical(other.basePoint, basePoint) || other.basePoint == basePoint)&&const DeepCollectionEquality().equals(other.entityIds, entityIds)&&(identical(other.isLayoutBlock, isLayoutBlock) || other.isLayoutBlock == isLayoutBlock)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.description, description) || other.description == description)&&(identical(other.xrefPath, xrefPath) || other.xrefPath == xrefPath));
}


@override
int get hashCode => Object.hash(runtimeType,name,basePoint,const DeepCollectionEquality().hash(entityIds),isLayoutBlock,isAnonymous,description,xrefPath);



}

/// @nodoc
abstract mixin class $BlockRecordCopyWith<$Res>  {
  factory $BlockRecordCopyWith(BlockRecord value, $Res Function(BlockRecord) _then) = _$BlockRecordCopyWithImpl;
@useResult
$Res call({
 String name, Vec2 basePoint, List<int> entityIds, bool isLayoutBlock, bool isAnonymous, String description, String xrefPath
});




}
/// @nodoc
class _$BlockRecordCopyWithImpl<$Res>
    implements $BlockRecordCopyWith<$Res> {
  _$BlockRecordCopyWithImpl(this._self, this._then);

  final BlockRecord _self;
  final $Res Function(BlockRecord) _then;

/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? basePoint = null,Object? entityIds = null,Object? isLayoutBlock = null,Object? isAnonymous = null,Object? description = null,Object? xrefPath = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,basePoint: null == basePoint ? _self.basePoint : basePoint // ignore: cast_nullable_to_non_nullable
as Vec2,entityIds: null == entityIds ? _self.entityIds : entityIds // ignore: cast_nullable_to_non_nullable
as List<int>,isLayoutBlock: null == isLayoutBlock ? _self.isLayoutBlock : isLayoutBlock // ignore: cast_nullable_to_non_nullable
as bool,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,xrefPath: null == xrefPath ? _self.xrefPath : xrefPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BlockRecord].
extension BlockRecordPatterns on BlockRecord {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlockRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlockRecord value)  $default,){
final _that = this;
switch (_that) {
case _BlockRecord():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlockRecord value)?  $default,){
final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  Vec2 basePoint,  List<int> entityIds,  bool isLayoutBlock,  bool isAnonymous,  String description,  String xrefPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
return $default(_that.name,_that.basePoint,_that.entityIds,_that.isLayoutBlock,_that.isAnonymous,_that.description,_that.xrefPath);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  Vec2 basePoint,  List<int> entityIds,  bool isLayoutBlock,  bool isAnonymous,  String description,  String xrefPath)  $default,) {final _that = this;
switch (_that) {
case _BlockRecord():
return $default(_that.name,_that.basePoint,_that.entityIds,_that.isLayoutBlock,_that.isAnonymous,_that.description,_that.xrefPath);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  Vec2 basePoint,  List<int> entityIds,  bool isLayoutBlock,  bool isAnonymous,  String description,  String xrefPath)?  $default,) {final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
return $default(_that.name,_that.basePoint,_that.entityIds,_that.isLayoutBlock,_that.isAnonymous,_that.description,_that.xrefPath);case _:
  return null;

}
}

}

/// @nodoc


class _BlockRecord extends BlockRecord {
  const _BlockRecord({required this.name, this.basePoint = const Vec2.zero(), final  List<int> entityIds = const [], this.isLayoutBlock = false, this.isAnonymous = false, this.description = '', this.xrefPath = ''}): _entityIds = entityIds,super._();
  

@override final  String name;
@override@JsonKey() final  Vec2 basePoint;
 final  List<int> _entityIds;
@override@JsonKey() List<int> get entityIds {
  if (_entityIds is EqualUnmodifiableListView) return _entityIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entityIds);
}

/// True for `*Model_Space` and `*Paper_Space*`, which are containers rather
/// than insertable blocks.
@override@JsonKey() final  bool isLayoutBlock;
/// True for generated blocks such as the `*D` dimension geometry blocks and
/// `*U` hatch blocks, which are hidden from the block picker.
@override@JsonKey() final  bool isAnonymous;
@override@JsonKey() final  String description;
/// Non-empty when this block is an external reference.
@override@JsonKey() final  String xrefPath;

/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockRecordCopyWith<_BlockRecord> get copyWith => __$BlockRecordCopyWithImpl<_BlockRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockRecord&&(identical(other.name, name) || other.name == name)&&(identical(other.basePoint, basePoint) || other.basePoint == basePoint)&&const DeepCollectionEquality().equals(other._entityIds, _entityIds)&&(identical(other.isLayoutBlock, isLayoutBlock) || other.isLayoutBlock == isLayoutBlock)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.description, description) || other.description == description)&&(identical(other.xrefPath, xrefPath) || other.xrefPath == xrefPath));
}


@override
int get hashCode => Object.hash(runtimeType,name,basePoint,const DeepCollectionEquality().hash(_entityIds),isLayoutBlock,isAnonymous,description,xrefPath);



}

/// @nodoc
abstract mixin class _$BlockRecordCopyWith<$Res> implements $BlockRecordCopyWith<$Res> {
  factory _$BlockRecordCopyWith(_BlockRecord value, $Res Function(_BlockRecord) _then) = __$BlockRecordCopyWithImpl;
@override @useResult
$Res call({
 String name, Vec2 basePoint, List<int> entityIds, bool isLayoutBlock, bool isAnonymous, String description, String xrefPath
});




}
/// @nodoc
class __$BlockRecordCopyWithImpl<$Res>
    implements _$BlockRecordCopyWith<$Res> {
  __$BlockRecordCopyWithImpl(this._self, this._then);

  final _BlockRecord _self;
  final $Res Function(_BlockRecord) _then;

/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? basePoint = null,Object? entityIds = null,Object? isLayoutBlock = null,Object? isAnonymous = null,Object? description = null,Object? xrefPath = null,}) {
  return _then(_BlockRecord(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,basePoint: null == basePoint ? _self.basePoint : basePoint // ignore: cast_nullable_to_non_nullable
as Vec2,entityIds: null == entityIds ? _self._entityIds : entityIds // ignore: cast_nullable_to_non_nullable
as List<int>,isLayoutBlock: null == isLayoutBlock ? _self.isLayoutBlock : isLayoutBlock // ignore: cast_nullable_to_non_nullable
as bool,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,xrefPath: null == xrefPath ? _self.xrefPath : xrefPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$Layout {

 String get name; String get blockName; bool get isModelSpace; int get tabOrder;/// Paper size in millimetres.
 double get paperWidth; double get paperHeight;/// Plot twist in degrees: 0, 90, 180 or 270. The sheet on screen stays
/// put; only SVG/PDF output rotates.
 int get plotRotation;/// Optional plot window. Null means the full sheet, or model extents.
 Bounds2? get plotWindow;/// Drawing units per plotted millimetre. Ignored when [plotFit] is set.
 double get plotScale;/// Scale the plot window (or extents) to fill the sheet.
 bool get plotFit;/// Shift of the scaled content on the sheet, in millimetres.
 double get plotOffsetX; double get plotOffsetY;/// Windows into model space. Empty on the model tab itself.
 List<PaperViewport> get viewports;
/// Create a copy of Layout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LayoutCopyWith<Layout> get copyWith => _$LayoutCopyWithImpl<Layout>(this as Layout, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Layout&&(identical(other.name, name) || other.name == name)&&(identical(other.blockName, blockName) || other.blockName == blockName)&&(identical(other.isModelSpace, isModelSpace) || other.isModelSpace == isModelSpace)&&(identical(other.tabOrder, tabOrder) || other.tabOrder == tabOrder)&&(identical(other.paperWidth, paperWidth) || other.paperWidth == paperWidth)&&(identical(other.paperHeight, paperHeight) || other.paperHeight == paperHeight)&&(identical(other.plotRotation, plotRotation) || other.plotRotation == plotRotation)&&(identical(other.plotWindow, plotWindow) || other.plotWindow == plotWindow)&&(identical(other.plotScale, plotScale) || other.plotScale == plotScale)&&(identical(other.plotFit, plotFit) || other.plotFit == plotFit)&&(identical(other.plotOffsetX, plotOffsetX) || other.plotOffsetX == plotOffsetX)&&(identical(other.plotOffsetY, plotOffsetY) || other.plotOffsetY == plotOffsetY)&&const DeepCollectionEquality().equals(other.viewports, viewports));
}


@override
int get hashCode => Object.hash(runtimeType,name,blockName,isModelSpace,tabOrder,paperWidth,paperHeight,plotRotation,plotWindow,plotScale,plotFit,plotOffsetX,plotOffsetY,const DeepCollectionEquality().hash(viewports));



}

/// @nodoc
abstract mixin class $LayoutCopyWith<$Res>  {
  factory $LayoutCopyWith(Layout value, $Res Function(Layout) _then) = _$LayoutCopyWithImpl;
@useResult
$Res call({
 String name, String blockName, bool isModelSpace, int tabOrder, double paperWidth, double paperHeight, int plotRotation, Bounds2? plotWindow, double plotScale, bool plotFit, double plotOffsetX, double plotOffsetY, List<PaperViewport> viewports
});




}
/// @nodoc
class _$LayoutCopyWithImpl<$Res>
    implements $LayoutCopyWith<$Res> {
  _$LayoutCopyWithImpl(this._self, this._then);

  final Layout _self;
  final $Res Function(Layout) _then;

/// Create a copy of Layout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? blockName = null,Object? isModelSpace = null,Object? tabOrder = null,Object? paperWidth = null,Object? paperHeight = null,Object? plotRotation = null,Object? plotWindow = freezed,Object? plotScale = null,Object? plotFit = null,Object? plotOffsetX = null,Object? plotOffsetY = null,Object? viewports = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,blockName: null == blockName ? _self.blockName : blockName // ignore: cast_nullable_to_non_nullable
as String,isModelSpace: null == isModelSpace ? _self.isModelSpace : isModelSpace // ignore: cast_nullable_to_non_nullable
as bool,tabOrder: null == tabOrder ? _self.tabOrder : tabOrder // ignore: cast_nullable_to_non_nullable
as int,paperWidth: null == paperWidth ? _self.paperWidth : paperWidth // ignore: cast_nullable_to_non_nullable
as double,paperHeight: null == paperHeight ? _self.paperHeight : paperHeight // ignore: cast_nullable_to_non_nullable
as double,plotRotation: null == plotRotation ? _self.plotRotation : plotRotation // ignore: cast_nullable_to_non_nullable
as int,plotWindow: freezed == plotWindow ? _self.plotWindow : plotWindow // ignore: cast_nullable_to_non_nullable
as Bounds2?,plotScale: null == plotScale ? _self.plotScale : plotScale // ignore: cast_nullable_to_non_nullable
as double,plotFit: null == plotFit ? _self.plotFit : plotFit // ignore: cast_nullable_to_non_nullable
as bool,plotOffsetX: null == plotOffsetX ? _self.plotOffsetX : plotOffsetX // ignore: cast_nullable_to_non_nullable
as double,plotOffsetY: null == plotOffsetY ? _self.plotOffsetY : plotOffsetY // ignore: cast_nullable_to_non_nullable
as double,viewports: null == viewports ? _self.viewports : viewports // ignore: cast_nullable_to_non_nullable
as List<PaperViewport>,
  ));
}

}


/// Adds pattern-matching-related methods to [Layout].
extension LayoutPatterns on Layout {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Layout value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Layout() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Layout value)  $default,){
final _that = this;
switch (_that) {
case _Layout():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Layout value)?  $default,){
final _that = this;
switch (_that) {
case _Layout() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String blockName,  bool isModelSpace,  int tabOrder,  double paperWidth,  double paperHeight,  int plotRotation,  Bounds2? plotWindow,  double plotScale,  bool plotFit,  double plotOffsetX,  double plotOffsetY,  List<PaperViewport> viewports)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Layout() when $default != null:
return $default(_that.name,_that.blockName,_that.isModelSpace,_that.tabOrder,_that.paperWidth,_that.paperHeight,_that.plotRotation,_that.plotWindow,_that.plotScale,_that.plotFit,_that.plotOffsetX,_that.plotOffsetY,_that.viewports);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String blockName,  bool isModelSpace,  int tabOrder,  double paperWidth,  double paperHeight,  int plotRotation,  Bounds2? plotWindow,  double plotScale,  bool plotFit,  double plotOffsetX,  double plotOffsetY,  List<PaperViewport> viewports)  $default,) {final _that = this;
switch (_that) {
case _Layout():
return $default(_that.name,_that.blockName,_that.isModelSpace,_that.tabOrder,_that.paperWidth,_that.paperHeight,_that.plotRotation,_that.plotWindow,_that.plotScale,_that.plotFit,_that.plotOffsetX,_that.plotOffsetY,_that.viewports);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String blockName,  bool isModelSpace,  int tabOrder,  double paperWidth,  double paperHeight,  int plotRotation,  Bounds2? plotWindow,  double plotScale,  bool plotFit,  double plotOffsetX,  double plotOffsetY,  List<PaperViewport> viewports)?  $default,) {final _that = this;
switch (_that) {
case _Layout() when $default != null:
return $default(_that.name,_that.blockName,_that.isModelSpace,_that.tabOrder,_that.paperWidth,_that.paperHeight,_that.plotRotation,_that.plotWindow,_that.plotScale,_that.plotFit,_that.plotOffsetX,_that.plotOffsetY,_that.viewports);case _:
  return null;

}
}

}

/// @nodoc


class _Layout extends Layout {
  const _Layout({required this.name, required this.blockName, this.isModelSpace = false, this.tabOrder = 0, this.paperWidth = 297, this.paperHeight = 210, this.plotRotation = 0, this.plotWindow, this.plotScale = 1, this.plotFit = false, this.plotOffsetX = 0, this.plotOffsetY = 0, final  List<PaperViewport> viewports = const []}): _viewports = viewports,super._();
  

@override final  String name;
@override final  String blockName;
@override@JsonKey() final  bool isModelSpace;
@override@JsonKey() final  int tabOrder;
/// Paper size in millimetres.
@override@JsonKey() final  double paperWidth;
@override@JsonKey() final  double paperHeight;
/// Plot twist in degrees: 0, 90, 180 or 270. The sheet on screen stays
/// put; only SVG/PDF output rotates.
@override@JsonKey() final  int plotRotation;
/// Optional plot window. Null means the full sheet, or model extents.
@override final  Bounds2? plotWindow;
/// Drawing units per plotted millimetre. Ignored when [plotFit] is set.
@override@JsonKey() final  double plotScale;
/// Scale the plot window (or extents) to fill the sheet.
@override@JsonKey() final  bool plotFit;
/// Shift of the scaled content on the sheet, in millimetres.
@override@JsonKey() final  double plotOffsetX;
@override@JsonKey() final  double plotOffsetY;
/// Windows into model space. Empty on the model tab itself.
 final  List<PaperViewport> _viewports;
/// Windows into model space. Empty on the model tab itself.
@override@JsonKey() List<PaperViewport> get viewports {
  if (_viewports is EqualUnmodifiableListView) return _viewports;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_viewports);
}


/// Create a copy of Layout
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LayoutCopyWith<_Layout> get copyWith => __$LayoutCopyWithImpl<_Layout>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Layout&&(identical(other.name, name) || other.name == name)&&(identical(other.blockName, blockName) || other.blockName == blockName)&&(identical(other.isModelSpace, isModelSpace) || other.isModelSpace == isModelSpace)&&(identical(other.tabOrder, tabOrder) || other.tabOrder == tabOrder)&&(identical(other.paperWidth, paperWidth) || other.paperWidth == paperWidth)&&(identical(other.paperHeight, paperHeight) || other.paperHeight == paperHeight)&&(identical(other.plotRotation, plotRotation) || other.plotRotation == plotRotation)&&(identical(other.plotWindow, plotWindow) || other.plotWindow == plotWindow)&&(identical(other.plotScale, plotScale) || other.plotScale == plotScale)&&(identical(other.plotFit, plotFit) || other.plotFit == plotFit)&&(identical(other.plotOffsetX, plotOffsetX) || other.plotOffsetX == plotOffsetX)&&(identical(other.plotOffsetY, plotOffsetY) || other.plotOffsetY == plotOffsetY)&&const DeepCollectionEquality().equals(other._viewports, _viewports));
}


@override
int get hashCode => Object.hash(runtimeType,name,blockName,isModelSpace,tabOrder,paperWidth,paperHeight,plotRotation,plotWindow,plotScale,plotFit,plotOffsetX,plotOffsetY,const DeepCollectionEquality().hash(_viewports));



}

/// @nodoc
abstract mixin class _$LayoutCopyWith<$Res> implements $LayoutCopyWith<$Res> {
  factory _$LayoutCopyWith(_Layout value, $Res Function(_Layout) _then) = __$LayoutCopyWithImpl;
@override @useResult
$Res call({
 String name, String blockName, bool isModelSpace, int tabOrder, double paperWidth, double paperHeight, int plotRotation, Bounds2? plotWindow, double plotScale, bool plotFit, double plotOffsetX, double plotOffsetY, List<PaperViewport> viewports
});




}
/// @nodoc
class __$LayoutCopyWithImpl<$Res>
    implements _$LayoutCopyWith<$Res> {
  __$LayoutCopyWithImpl(this._self, this._then);

  final _Layout _self;
  final $Res Function(_Layout) _then;

/// Create a copy of Layout
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? blockName = null,Object? isModelSpace = null,Object? tabOrder = null,Object? paperWidth = null,Object? paperHeight = null,Object? plotRotation = null,Object? plotWindow = freezed,Object? plotScale = null,Object? plotFit = null,Object? plotOffsetX = null,Object? plotOffsetY = null,Object? viewports = null,}) {
  return _then(_Layout(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,blockName: null == blockName ? _self.blockName : blockName // ignore: cast_nullable_to_non_nullable
as String,isModelSpace: null == isModelSpace ? _self.isModelSpace : isModelSpace // ignore: cast_nullable_to_non_nullable
as bool,tabOrder: null == tabOrder ? _self.tabOrder : tabOrder // ignore: cast_nullable_to_non_nullable
as int,paperWidth: null == paperWidth ? _self.paperWidth : paperWidth // ignore: cast_nullable_to_non_nullable
as double,paperHeight: null == paperHeight ? _self.paperHeight : paperHeight // ignore: cast_nullable_to_non_nullable
as double,plotRotation: null == plotRotation ? _self.plotRotation : plotRotation // ignore: cast_nullable_to_non_nullable
as int,plotWindow: freezed == plotWindow ? _self.plotWindow : plotWindow // ignore: cast_nullable_to_non_nullable
as Bounds2?,plotScale: null == plotScale ? _self.plotScale : plotScale // ignore: cast_nullable_to_non_nullable
as double,plotFit: null == plotFit ? _self.plotFit : plotFit // ignore: cast_nullable_to_non_nullable
as bool,plotOffsetX: null == plotOffsetX ? _self.plotOffsetX : plotOffsetX // ignore: cast_nullable_to_non_nullable
as double,plotOffsetY: null == plotOffsetY ? _self.plotOffsetY : plotOffsetY // ignore: cast_nullable_to_non_nullable
as double,viewports: null == viewports ? _self._viewports : viewports // ignore: cast_nullable_to_non_nullable
as List<PaperViewport>,
  ));
}


}

/// @nodoc
mixin _$DocumentChange {

 List<int> get added; List<int> get removed; List<int> get modified;/// A symbol table (layers, line types, styles) changed, so resolved styles
/// must be recomputed even for untouched entities.
 bool get tablesChanged;/// Blocks or layouts changed, so any cached block geometry is stale.
 bool get structureChanged;
/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentChangeCopyWith<DocumentChange> get copyWith => _$DocumentChangeCopyWithImpl<DocumentChange>(this as DocumentChange, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentChange&&const DeepCollectionEquality().equals(other.added, added)&&const DeepCollectionEquality().equals(other.removed, removed)&&const DeepCollectionEquality().equals(other.modified, modified)&&(identical(other.tablesChanged, tablesChanged) || other.tablesChanged == tablesChanged)&&(identical(other.structureChanged, structureChanged) || other.structureChanged == structureChanged));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(added),const DeepCollectionEquality().hash(removed),const DeepCollectionEquality().hash(modified),tablesChanged,structureChanged);



}

/// @nodoc
abstract mixin class $DocumentChangeCopyWith<$Res>  {
  factory $DocumentChangeCopyWith(DocumentChange value, $Res Function(DocumentChange) _then) = _$DocumentChangeCopyWithImpl;
@useResult
$Res call({
 List<int> added, List<int> removed, List<int> modified, bool tablesChanged, bool structureChanged
});




}
/// @nodoc
class _$DocumentChangeCopyWithImpl<$Res>
    implements $DocumentChangeCopyWith<$Res> {
  _$DocumentChangeCopyWithImpl(this._self, this._then);

  final DocumentChange _self;
  final $Res Function(DocumentChange) _then;

/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? added = null,Object? removed = null,Object? modified = null,Object? tablesChanged = null,Object? structureChanged = null,}) {
  return _then(_self.copyWith(
added: null == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as List<int>,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as List<int>,modified: null == modified ? _self.modified : modified // ignore: cast_nullable_to_non_nullable
as List<int>,tablesChanged: null == tablesChanged ? _self.tablesChanged : tablesChanged // ignore: cast_nullable_to_non_nullable
as bool,structureChanged: null == structureChanged ? _self.structureChanged : structureChanged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentChange].
extension DocumentChangePatterns on DocumentChange {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentChange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentChange value)  $default,){
final _that = this;
switch (_that) {
case _DocumentChange():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentChange value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<int> added,  List<int> removed,  List<int> modified,  bool tablesChanged,  bool structureChanged)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that.added,_that.removed,_that.modified,_that.tablesChanged,_that.structureChanged);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<int> added,  List<int> removed,  List<int> modified,  bool tablesChanged,  bool structureChanged)  $default,) {final _that = this;
switch (_that) {
case _DocumentChange():
return $default(_that.added,_that.removed,_that.modified,_that.tablesChanged,_that.structureChanged);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<int> added,  List<int> removed,  List<int> modified,  bool tablesChanged,  bool structureChanged)?  $default,) {final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that.added,_that.removed,_that.modified,_that.tablesChanged,_that.structureChanged);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentChange extends DocumentChange {
  const _DocumentChange({final  List<int> added = const [], final  List<int> removed = const [], final  List<int> modified = const [], this.tablesChanged = false, this.structureChanged = false}): _added = added,_removed = removed,_modified = modified,super._();
  

 final  List<int> _added;
@override@JsonKey() List<int> get added {
  if (_added is EqualUnmodifiableListView) return _added;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_added);
}

 final  List<int> _removed;
@override@JsonKey() List<int> get removed {
  if (_removed is EqualUnmodifiableListView) return _removed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removed);
}

 final  List<int> _modified;
@override@JsonKey() List<int> get modified {
  if (_modified is EqualUnmodifiableListView) return _modified;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modified);
}

/// A symbol table (layers, line types, styles) changed, so resolved styles
/// must be recomputed even for untouched entities.
@override@JsonKey() final  bool tablesChanged;
/// Blocks or layouts changed, so any cached block geometry is stale.
@override@JsonKey() final  bool structureChanged;

/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentChangeCopyWith<_DocumentChange> get copyWith => __$DocumentChangeCopyWithImpl<_DocumentChange>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentChange&&const DeepCollectionEquality().equals(other._added, _added)&&const DeepCollectionEquality().equals(other._removed, _removed)&&const DeepCollectionEquality().equals(other._modified, _modified)&&(identical(other.tablesChanged, tablesChanged) || other.tablesChanged == tablesChanged)&&(identical(other.structureChanged, structureChanged) || other.structureChanged == structureChanged));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_added),const DeepCollectionEquality().hash(_removed),const DeepCollectionEquality().hash(_modified),tablesChanged,structureChanged);



}

/// @nodoc
abstract mixin class _$DocumentChangeCopyWith<$Res> implements $DocumentChangeCopyWith<$Res> {
  factory _$DocumentChangeCopyWith(_DocumentChange value, $Res Function(_DocumentChange) _then) = __$DocumentChangeCopyWithImpl;
@override @useResult
$Res call({
 List<int> added, List<int> removed, List<int> modified, bool tablesChanged, bool structureChanged
});




}
/// @nodoc
class __$DocumentChangeCopyWithImpl<$Res>
    implements _$DocumentChangeCopyWith<$Res> {
  __$DocumentChangeCopyWithImpl(this._self, this._then);

  final _DocumentChange _self;
  final $Res Function(_DocumentChange) _then;

/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? added = null,Object? removed = null,Object? modified = null,Object? tablesChanged = null,Object? structureChanged = null,}) {
  return _then(_DocumentChange(
added: null == added ? _self._added : added // ignore: cast_nullable_to_non_nullable
as List<int>,removed: null == removed ? _self._removed : removed // ignore: cast_nullable_to_non_nullable
as List<int>,modified: null == modified ? _self._modified : modified // ignore: cast_nullable_to_non_nullable
as List<int>,tablesChanged: null == tablesChanged ? _self.tablesChanged : tablesChanged // ignore: cast_nullable_to_non_nullable
as bool,structureChanged: null == structureChanged ? _self.structureChanged : structureChanged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
