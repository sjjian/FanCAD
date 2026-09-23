// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paper_viewport.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaperViewport {

/// The rectangle on the sheet, in millimetres of paper space.
@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson) Bounds2 get paperBounds;/// The model-space point that sits at the centre of [paperBounds].
@JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson) Vec2 get modelCenter;/// Model units per paper unit. 1 = 1:1, 0.1 = 1:10.
 double get scale;@JsonKey(toJson: _omitZero) double get rotation;@JsonKey(name: 'on', toJson: _omitTrue) bool get isOn;@JsonKey(toJson: _omitFalse) bool get locked;@JsonKey(toJson: _omitLayerZero) String get layer;/// Layer names frozen in this window only (VPLAYER). Empty means every
/// visible model layer still shows through.
@JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson) List<String> get frozenLayers;
/// Create a copy of PaperViewport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaperViewportCopyWith<PaperViewport> get copyWith => _$PaperViewportCopyWithImpl<PaperViewport>(this as PaperViewport, _$identity);

  /// Serializes this PaperViewport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaperViewport&&(identical(other.paperBounds, paperBounds) || other.paperBounds == paperBounds)&&(identical(other.modelCenter, modelCenter) || other.modelCenter == modelCenter)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&(identical(other.isOn, isOn) || other.isOn == isOn)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.layer, layer) || other.layer == layer)&&const DeepCollectionEquality().equals(other.frozenLayers, frozenLayers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paperBounds,modelCenter,scale,rotation,isOn,locked,layer,const DeepCollectionEquality().hash(frozenLayers));

@override
String toString() {
  return 'PaperViewport(paperBounds: $paperBounds, modelCenter: $modelCenter, scale: $scale, rotation: $rotation, isOn: $isOn, locked: $locked, layer: $layer, frozenLayers: $frozenLayers)';
}


}

/// @nodoc
abstract mixin class $PaperViewportCopyWith<$Res>  {
  factory $PaperViewportCopyWith(PaperViewport value, $Res Function(PaperViewport) _then) = _$PaperViewportCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson) Bounds2 paperBounds,@JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson) Vec2 modelCenter, double scale,@JsonKey(toJson: _omitZero) double rotation,@JsonKey(name: 'on', toJson: _omitTrue) bool isOn,@JsonKey(toJson: _omitFalse) bool locked,@JsonKey(toJson: _omitLayerZero) String layer,@JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson) List<String> frozenLayers
});




}
/// @nodoc
class _$PaperViewportCopyWithImpl<$Res>
    implements $PaperViewportCopyWith<$Res> {
  _$PaperViewportCopyWithImpl(this._self, this._then);

  final PaperViewport _self;
  final $Res Function(PaperViewport) _then;

/// Create a copy of PaperViewport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paperBounds = null,Object? modelCenter = null,Object? scale = null,Object? rotation = null,Object? isOn = null,Object? locked = null,Object? layer = null,Object? frozenLayers = null,}) {
  return _then(_self.copyWith(
paperBounds: null == paperBounds ? _self.paperBounds : paperBounds // ignore: cast_nullable_to_non_nullable
as Bounds2,modelCenter: null == modelCenter ? _self.modelCenter : modelCenter // ignore: cast_nullable_to_non_nullable
as Vec2,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,isOn: null == isOn ? _self.isOn : isOn // ignore: cast_nullable_to_non_nullable
as bool,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as String,frozenLayers: null == frozenLayers ? _self.frozenLayers : frozenLayers // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PaperViewport].
extension PaperViewportPatterns on PaperViewport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaperViewport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaperViewport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaperViewport value)  $default,){
final _that = this;
switch (_that) {
case _PaperViewport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaperViewport value)?  $default,){
final _that = this;
switch (_that) {
case _PaperViewport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson)  Bounds2 paperBounds, @JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson)  Vec2 modelCenter,  double scale, @JsonKey(toJson: _omitZero)  double rotation, @JsonKey(name: 'on', toJson: _omitTrue)  bool isOn, @JsonKey(toJson: _omitFalse)  bool locked, @JsonKey(toJson: _omitLayerZero)  String layer, @JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson)  List<String> frozenLayers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaperViewport() when $default != null:
return $default(_that.paperBounds,_that.modelCenter,_that.scale,_that.rotation,_that.isOn,_that.locked,_that.layer,_that.frozenLayers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson)  Bounds2 paperBounds, @JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson)  Vec2 modelCenter,  double scale, @JsonKey(toJson: _omitZero)  double rotation, @JsonKey(name: 'on', toJson: _omitTrue)  bool isOn, @JsonKey(toJson: _omitFalse)  bool locked, @JsonKey(toJson: _omitLayerZero)  String layer, @JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson)  List<String> frozenLayers)  $default,) {final _that = this;
switch (_that) {
case _PaperViewport():
return $default(_that.paperBounds,_that.modelCenter,_that.scale,_that.rotation,_that.isOn,_that.locked,_that.layer,_that.frozenLayers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson)  Bounds2 paperBounds, @JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson)  Vec2 modelCenter,  double scale, @JsonKey(toJson: _omitZero)  double rotation, @JsonKey(name: 'on', toJson: _omitTrue)  bool isOn, @JsonKey(toJson: _omitFalse)  bool locked, @JsonKey(toJson: _omitLayerZero)  String layer, @JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson)  List<String> frozenLayers)?  $default,) {final _that = this;
switch (_that) {
case _PaperViewport() when $default != null:
return $default(_that.paperBounds,_that.modelCenter,_that.scale,_that.rotation,_that.isOn,_that.locked,_that.layer,_that.frozenLayers);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _PaperViewport extends PaperViewport {
  const _PaperViewport({@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson) required this.paperBounds, @JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson) required this.modelCenter, this.scale = 1, @JsonKey(toJson: _omitZero) this.rotation = 0, @JsonKey(name: 'on', toJson: _omitTrue) this.isOn = true, @JsonKey(toJson: _omitFalse) this.locked = false, @JsonKey(toJson: _omitLayerZero) this.layer = '0', @JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson) final  List<String> frozenLayers = const []}): _frozenLayers = frozenLayers,super._();
  factory _PaperViewport.fromJson(Map<String, dynamic> json) => _$PaperViewportFromJson(json);

/// The rectangle on the sheet, in millimetres of paper space.
@override@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson) final  Bounds2 paperBounds;
/// The model-space point that sits at the centre of [paperBounds].
@override@JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson) final  Vec2 modelCenter;
/// Model units per paper unit. 1 = 1:1, 0.1 = 1:10.
@override@JsonKey() final  double scale;
@override@JsonKey(toJson: _omitZero) final  double rotation;
@override@JsonKey(name: 'on', toJson: _omitTrue) final  bool isOn;
@override@JsonKey(toJson: _omitFalse) final  bool locked;
@override@JsonKey(toJson: _omitLayerZero) final  String layer;
/// Layer names frozen in this window only (VPLAYER). Empty means every
/// visible model layer still shows through.
 final  List<String> _frozenLayers;
/// Layer names frozen in this window only (VPLAYER). Empty means every
/// visible model layer still shows through.
@override@JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson) List<String> get frozenLayers {
  if (_frozenLayers is EqualUnmodifiableListView) return _frozenLayers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_frozenLayers);
}


/// Create a copy of PaperViewport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaperViewportCopyWith<_PaperViewport> get copyWith => __$PaperViewportCopyWithImpl<_PaperViewport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaperViewportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaperViewport&&(identical(other.paperBounds, paperBounds) || other.paperBounds == paperBounds)&&(identical(other.modelCenter, modelCenter) || other.modelCenter == modelCenter)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&(identical(other.isOn, isOn) || other.isOn == isOn)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.layer, layer) || other.layer == layer)&&const DeepCollectionEquality().equals(other._frozenLayers, _frozenLayers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paperBounds,modelCenter,scale,rotation,isOn,locked,layer,const DeepCollectionEquality().hash(_frozenLayers));

@override
String toString() {
  return 'PaperViewport(paperBounds: $paperBounds, modelCenter: $modelCenter, scale: $scale, rotation: $rotation, isOn: $isOn, locked: $locked, layer: $layer, frozenLayers: $frozenLayers)';
}


}

/// @nodoc
abstract mixin class _$PaperViewportCopyWith<$Res> implements $PaperViewportCopyWith<$Res> {
  factory _$PaperViewportCopyWith(_PaperViewport value, $Res Function(_PaperViewport) _then) = __$PaperViewportCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson) Bounds2 paperBounds,@JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson) Vec2 modelCenter, double scale,@JsonKey(toJson: _omitZero) double rotation,@JsonKey(name: 'on', toJson: _omitTrue) bool isOn,@JsonKey(toJson: _omitFalse) bool locked,@JsonKey(toJson: _omitLayerZero) String layer,@JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson) List<String> frozenLayers
});




}
/// @nodoc
class __$PaperViewportCopyWithImpl<$Res>
    implements _$PaperViewportCopyWith<$Res> {
  __$PaperViewportCopyWithImpl(this._self, this._then);

  final _PaperViewport _self;
  final $Res Function(_PaperViewport) _then;

/// Create a copy of PaperViewport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paperBounds = null,Object? modelCenter = null,Object? scale = null,Object? rotation = null,Object? isOn = null,Object? locked = null,Object? layer = null,Object? frozenLayers = null,}) {
  return _then(_PaperViewport(
paperBounds: null == paperBounds ? _self.paperBounds : paperBounds // ignore: cast_nullable_to_non_nullable
as Bounds2,modelCenter: null == modelCenter ? _self.modelCenter : modelCenter // ignore: cast_nullable_to_non_nullable
as Vec2,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,isOn: null == isOn ? _self.isOn : isOn // ignore: cast_nullable_to_non_nullable
as bool,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as String,frozenLayers: null == frozenLayers ? _self._frozenLayers : frozenLayers // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
