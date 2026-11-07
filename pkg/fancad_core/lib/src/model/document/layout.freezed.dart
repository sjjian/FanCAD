// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'layout.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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

// dart format on
