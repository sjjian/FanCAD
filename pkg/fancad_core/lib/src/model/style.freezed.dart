// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EntityProps {

 String get layer;@JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson) CadColor get color;/// A line type name, or the literal `ByLayer` / `ByBlock` sentinels.
@JsonKey(toJson: _omitByLayerName) String get lineType;@JsonKey(toJson: _omitByLayerWeight) int get lineWeight;@JsonKey(toJson: _omitOne) double get lineTypeScale;/// -1 means inherit from the layer.
@JsonKey(toJson: _omitMinusOne) int get transparency;@JsonKey(toJson: _omitTrue) bool get visible;/// Z offset preserved for DWG round-tripping in this 2D application.
@JsonKey(toJson: _omitZero) double get elevation;
/// Create a copy of EntityProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntityPropsCopyWith<EntityProps> get copyWith => _$EntityPropsCopyWithImpl<EntityProps>(this as EntityProps, _$identity);

  /// Serializes this EntityProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntityProps&&(identical(other.layer, layer) || other.layer == layer)&&(identical(other.color, color) || other.color == color)&&(identical(other.lineType, lineType) || other.lineType == lineType)&&(identical(other.lineWeight, lineWeight) || other.lineWeight == lineWeight)&&(identical(other.lineTypeScale, lineTypeScale) || other.lineTypeScale == lineTypeScale)&&(identical(other.transparency, transparency) || other.transparency == transparency)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.elevation, elevation) || other.elevation == elevation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,layer,color,lineType,lineWeight,lineTypeScale,transparency,visible,elevation);

@override
String toString() {
  return 'EntityProps(layer: $layer, color: $color, lineType: $lineType, lineWeight: $lineWeight, lineTypeScale: $lineTypeScale, transparency: $transparency, visible: $visible, elevation: $elevation)';
}


}

/// @nodoc
abstract mixin class $EntityPropsCopyWith<$Res>  {
  factory $EntityPropsCopyWith(EntityProps value, $Res Function(EntityProps) _then) = _$EntityPropsCopyWithImpl;
@useResult
$Res call({
 String layer,@JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson) CadColor color,@JsonKey(toJson: _omitByLayerName) String lineType,@JsonKey(toJson: _omitByLayerWeight) int lineWeight,@JsonKey(toJson: _omitOne) double lineTypeScale,@JsonKey(toJson: _omitMinusOne) int transparency,@JsonKey(toJson: _omitTrue) bool visible,@JsonKey(toJson: _omitZero) double elevation
});




}
/// @nodoc
class _$EntityPropsCopyWithImpl<$Res>
    implements $EntityPropsCopyWith<$Res> {
  _$EntityPropsCopyWithImpl(this._self, this._then);

  final EntityProps _self;
  final $Res Function(EntityProps) _then;

/// Create a copy of EntityProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? layer = null,Object? color = null,Object? lineType = null,Object? lineWeight = null,Object? lineTypeScale = null,Object? transparency = null,Object? visible = null,Object? elevation = null,}) {
  return _then(_self.copyWith(
layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as CadColor,lineType: null == lineType ? _self.lineType : lineType // ignore: cast_nullable_to_non_nullable
as String,lineWeight: null == lineWeight ? _self.lineWeight : lineWeight // ignore: cast_nullable_to_non_nullable
as int,lineTypeScale: null == lineTypeScale ? _self.lineTypeScale : lineTypeScale // ignore: cast_nullable_to_non_nullable
as double,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as int,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,elevation: null == elevation ? _self.elevation : elevation // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [EntityProps].
extension EntityPropsPatterns on EntityProps {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntityProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntityProps() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntityProps value)  $default,){
final _that = this;
switch (_that) {
case _EntityProps():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntityProps value)?  $default,){
final _that = this;
switch (_that) {
case _EntityProps() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String layer, @JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson)  CadColor color, @JsonKey(toJson: _omitByLayerName)  String lineType, @JsonKey(toJson: _omitByLayerWeight)  int lineWeight, @JsonKey(toJson: _omitOne)  double lineTypeScale, @JsonKey(toJson: _omitMinusOne)  int transparency, @JsonKey(toJson: _omitTrue)  bool visible, @JsonKey(toJson: _omitZero)  double elevation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntityProps() when $default != null:
return $default(_that.layer,_that.color,_that.lineType,_that.lineWeight,_that.lineTypeScale,_that.transparency,_that.visible,_that.elevation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String layer, @JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson)  CadColor color, @JsonKey(toJson: _omitByLayerName)  String lineType, @JsonKey(toJson: _omitByLayerWeight)  int lineWeight, @JsonKey(toJson: _omitOne)  double lineTypeScale, @JsonKey(toJson: _omitMinusOne)  int transparency, @JsonKey(toJson: _omitTrue)  bool visible, @JsonKey(toJson: _omitZero)  double elevation)  $default,) {final _that = this;
switch (_that) {
case _EntityProps():
return $default(_that.layer,_that.color,_that.lineType,_that.lineWeight,_that.lineTypeScale,_that.transparency,_that.visible,_that.elevation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String layer, @JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson)  CadColor color, @JsonKey(toJson: _omitByLayerName)  String lineType, @JsonKey(toJson: _omitByLayerWeight)  int lineWeight, @JsonKey(toJson: _omitOne)  double lineTypeScale, @JsonKey(toJson: _omitMinusOne)  int transparency, @JsonKey(toJson: _omitTrue)  bool visible, @JsonKey(toJson: _omitZero)  double elevation)?  $default,) {final _that = this;
switch (_that) {
case _EntityProps() when $default != null:
return $default(_that.layer,_that.color,_that.lineType,_that.lineWeight,_that.lineTypeScale,_that.transparency,_that.visible,_that.elevation);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _EntityProps extends EntityProps {
  const _EntityProps({this.layer = '0', @JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson) this.color = const CadColor.byLayer(), @JsonKey(toJson: _omitByLayerName) this.lineType = 'ByLayer', @JsonKey(toJson: _omitByLayerWeight) this.lineWeight = LineWeight.byLayer, @JsonKey(toJson: _omitOne) this.lineTypeScale = 1, @JsonKey(toJson: _omitMinusOne) this.transparency = -1, @JsonKey(toJson: _omitTrue) this.visible = true, @JsonKey(toJson: _omitZero) this.elevation = 0}): super._();
  factory _EntityProps.fromJson(Map<String, dynamic> json) => _$EntityPropsFromJson(json);

@override@JsonKey() final  String layer;
@override@JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson) final  CadColor color;
/// A line type name, or the literal `ByLayer` / `ByBlock` sentinels.
@override@JsonKey(toJson: _omitByLayerName) final  String lineType;
@override@JsonKey(toJson: _omitByLayerWeight) final  int lineWeight;
@override@JsonKey(toJson: _omitOne) final  double lineTypeScale;
/// -1 means inherit from the layer.
@override@JsonKey(toJson: _omitMinusOne) final  int transparency;
@override@JsonKey(toJson: _omitTrue) final  bool visible;
/// Z offset preserved for DWG round-tripping in this 2D application.
@override@JsonKey(toJson: _omitZero) final  double elevation;

/// Create a copy of EntityProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntityPropsCopyWith<_EntityProps> get copyWith => __$EntityPropsCopyWithImpl<_EntityProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EntityPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntityProps&&(identical(other.layer, layer) || other.layer == layer)&&(identical(other.color, color) || other.color == color)&&(identical(other.lineType, lineType) || other.lineType == lineType)&&(identical(other.lineWeight, lineWeight) || other.lineWeight == lineWeight)&&(identical(other.lineTypeScale, lineTypeScale) || other.lineTypeScale == lineTypeScale)&&(identical(other.transparency, transparency) || other.transparency == transparency)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.elevation, elevation) || other.elevation == elevation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,layer,color,lineType,lineWeight,lineTypeScale,transparency,visible,elevation);

@override
String toString() {
  return 'EntityProps(layer: $layer, color: $color, lineType: $lineType, lineWeight: $lineWeight, lineTypeScale: $lineTypeScale, transparency: $transparency, visible: $visible, elevation: $elevation)';
}


}

/// @nodoc
abstract mixin class _$EntityPropsCopyWith<$Res> implements $EntityPropsCopyWith<$Res> {
  factory _$EntityPropsCopyWith(_EntityProps value, $Res Function(_EntityProps) _then) = __$EntityPropsCopyWithImpl;
@override @useResult
$Res call({
 String layer,@JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson) CadColor color,@JsonKey(toJson: _omitByLayerName) String lineType,@JsonKey(toJson: _omitByLayerWeight) int lineWeight,@JsonKey(toJson: _omitOne) double lineTypeScale,@JsonKey(toJson: _omitMinusOne) int transparency,@JsonKey(toJson: _omitTrue) bool visible,@JsonKey(toJson: _omitZero) double elevation
});




}
/// @nodoc
class __$EntityPropsCopyWithImpl<$Res>
    implements _$EntityPropsCopyWith<$Res> {
  __$EntityPropsCopyWithImpl(this._self, this._then);

  final _EntityProps _self;
  final $Res Function(_EntityProps) _then;

/// Create a copy of EntityProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? layer = null,Object? color = null,Object? lineType = null,Object? lineWeight = null,Object? lineTypeScale = null,Object? transparency = null,Object? visible = null,Object? elevation = null,}) {
  return _then(_EntityProps(
layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as CadColor,lineType: null == lineType ? _self.lineType : lineType // ignore: cast_nullable_to_non_nullable
as String,lineWeight: null == lineWeight ? _self.lineWeight : lineWeight // ignore: cast_nullable_to_non_nullable
as int,lineTypeScale: null == lineTypeScale ? _self.lineTypeScale : lineTypeScale // ignore: cast_nullable_to_non_nullable
as double,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as int,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,elevation: null == elevation ? _self.elevation : elevation // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$LayerDef {

 String get name; CadColor get color; String get lineType; int get lineWeight; bool get visible; bool get frozen; bool get locked; bool get plottable;/// 0 = opaque, 90 = nearly invisible, matching the AutoCAD scale.
 int get transparency;
/// Create a copy of LayerDef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LayerDefCopyWith<LayerDef> get copyWith => _$LayerDefCopyWithImpl<LayerDef>(this as LayerDef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LayerDef&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.lineType, lineType) || other.lineType == lineType)&&(identical(other.lineWeight, lineWeight) || other.lineWeight == lineWeight)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.frozen, frozen) || other.frozen == frozen)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.plottable, plottable) || other.plottable == plottable)&&(identical(other.transparency, transparency) || other.transparency == transparency));
}


@override
int get hashCode => Object.hash(runtimeType,name,color,lineType,lineWeight,visible,frozen,locked,plottable,transparency);



}

/// @nodoc
abstract mixin class $LayerDefCopyWith<$Res>  {
  factory $LayerDefCopyWith(LayerDef value, $Res Function(LayerDef) _then) = _$LayerDefCopyWithImpl;
@useResult
$Res call({
 String name, CadColor color, String lineType, int lineWeight, bool visible, bool frozen, bool locked, bool plottable, int transparency
});




}
/// @nodoc
class _$LayerDefCopyWithImpl<$Res>
    implements $LayerDefCopyWith<$Res> {
  _$LayerDefCopyWithImpl(this._self, this._then);

  final LayerDef _self;
  final $Res Function(LayerDef) _then;

/// Create a copy of LayerDef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? color = null,Object? lineType = null,Object? lineWeight = null,Object? visible = null,Object? frozen = null,Object? locked = null,Object? plottable = null,Object? transparency = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as CadColor,lineType: null == lineType ? _self.lineType : lineType // ignore: cast_nullable_to_non_nullable
as String,lineWeight: null == lineWeight ? _self.lineWeight : lineWeight // ignore: cast_nullable_to_non_nullable
as int,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,frozen: null == frozen ? _self.frozen : frozen // ignore: cast_nullable_to_non_nullable
as bool,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,plottable: null == plottable ? _self.plottable : plottable // ignore: cast_nullable_to_non_nullable
as bool,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LayerDef].
extension LayerDefPatterns on LayerDef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LayerDef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LayerDef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LayerDef value)  $default,){
final _that = this;
switch (_that) {
case _LayerDef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LayerDef value)?  $default,){
final _that = this;
switch (_that) {
case _LayerDef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  CadColor color,  String lineType,  int lineWeight,  bool visible,  bool frozen,  bool locked,  bool plottable,  int transparency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LayerDef() when $default != null:
return $default(_that.name,_that.color,_that.lineType,_that.lineWeight,_that.visible,_that.frozen,_that.locked,_that.plottable,_that.transparency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  CadColor color,  String lineType,  int lineWeight,  bool visible,  bool frozen,  bool locked,  bool plottable,  int transparency)  $default,) {final _that = this;
switch (_that) {
case _LayerDef():
return $default(_that.name,_that.color,_that.lineType,_that.lineWeight,_that.visible,_that.frozen,_that.locked,_that.plottable,_that.transparency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  CadColor color,  String lineType,  int lineWeight,  bool visible,  bool frozen,  bool locked,  bool plottable,  int transparency)?  $default,) {final _that = this;
switch (_that) {
case _LayerDef() when $default != null:
return $default(_that.name,_that.color,_that.lineType,_that.lineWeight,_that.visible,_that.frozen,_that.locked,_that.plottable,_that.transparency);case _:
  return null;

}
}

}

/// @nodoc


class _LayerDef extends LayerDef {
  const _LayerDef({required this.name, this.color = const CadColor.indexed(7), this.lineType = 'Continuous', this.lineWeight = LineWeight.byDefault, this.visible = true, this.frozen = false, this.locked = false, this.plottable = true, this.transparency = 0}): super._();
  

@override final  String name;
@override@JsonKey() final  CadColor color;
@override@JsonKey() final  String lineType;
@override@JsonKey() final  int lineWeight;
@override@JsonKey() final  bool visible;
@override@JsonKey() final  bool frozen;
@override@JsonKey() final  bool locked;
@override@JsonKey() final  bool plottable;
/// 0 = opaque, 90 = nearly invisible, matching the AutoCAD scale.
@override@JsonKey() final  int transparency;

/// Create a copy of LayerDef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LayerDefCopyWith<_LayerDef> get copyWith => __$LayerDefCopyWithImpl<_LayerDef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LayerDef&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.lineType, lineType) || other.lineType == lineType)&&(identical(other.lineWeight, lineWeight) || other.lineWeight == lineWeight)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.frozen, frozen) || other.frozen == frozen)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.plottable, plottable) || other.plottable == plottable)&&(identical(other.transparency, transparency) || other.transparency == transparency));
}


@override
int get hashCode => Object.hash(runtimeType,name,color,lineType,lineWeight,visible,frozen,locked,plottable,transparency);



}

/// @nodoc
abstract mixin class _$LayerDefCopyWith<$Res> implements $LayerDefCopyWith<$Res> {
  factory _$LayerDefCopyWith(_LayerDef value, $Res Function(_LayerDef) _then) = __$LayerDefCopyWithImpl;
@override @useResult
$Res call({
 String name, CadColor color, String lineType, int lineWeight, bool visible, bool frozen, bool locked, bool plottable, int transparency
});




}
/// @nodoc
class __$LayerDefCopyWithImpl<$Res>
    implements _$LayerDefCopyWith<$Res> {
  __$LayerDefCopyWithImpl(this._self, this._then);

  final _LayerDef _self;
  final $Res Function(_LayerDef) _then;

/// Create a copy of LayerDef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? color = null,Object? lineType = null,Object? lineWeight = null,Object? visible = null,Object? frozen = null,Object? locked = null,Object? plottable = null,Object? transparency = null,}) {
  return _then(_LayerDef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as CadColor,lineType: null == lineType ? _self.lineType : lineType // ignore: cast_nullable_to_non_nullable
as String,lineWeight: null == lineWeight ? _self.lineWeight : lineWeight // ignore: cast_nullable_to_non_nullable
as int,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,frozen: null == frozen ? _self.frozen : frozen // ignore: cast_nullable_to_non_nullable
as bool,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,plottable: null == plottable ? _self.plottable : plottable // ignore: cast_nullable_to_non_nullable
as bool,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$LineTypeDef {

 String get name; String get description; List<double> get pattern; double get patternLength;
/// Create a copy of LineTypeDef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineTypeDefCopyWith<LineTypeDef> get copyWith => _$LineTypeDefCopyWithImpl<LineTypeDef>(this as LineTypeDef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineTypeDef&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.pattern, pattern)&&(identical(other.patternLength, patternLength) || other.patternLength == patternLength));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(pattern),patternLength);



}

/// @nodoc
abstract mixin class $LineTypeDefCopyWith<$Res>  {
  factory $LineTypeDefCopyWith(LineTypeDef value, $Res Function(LineTypeDef) _then) = _$LineTypeDefCopyWithImpl;
@useResult
$Res call({
 String name, String description, List<double> pattern, double patternLength
});




}
/// @nodoc
class _$LineTypeDefCopyWithImpl<$Res>
    implements $LineTypeDefCopyWith<$Res> {
  _$LineTypeDefCopyWithImpl(this._self, this._then);

  final LineTypeDef _self;
  final $Res Function(LineTypeDef) _then;

/// Create a copy of LineTypeDef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? pattern = null,Object? patternLength = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,pattern: null == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as List<double>,patternLength: null == patternLength ? _self.patternLength : patternLength // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LineTypeDef].
extension LineTypeDefPatterns on LineTypeDef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineTypeDef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineTypeDef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineTypeDef value)  $default,){
final _that = this;
switch (_that) {
case _LineTypeDef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineTypeDef value)?  $default,){
final _that = this;
switch (_that) {
case _LineTypeDef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  List<double> pattern,  double patternLength)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineTypeDef() when $default != null:
return $default(_that.name,_that.description,_that.pattern,_that.patternLength);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  List<double> pattern,  double patternLength)  $default,) {final _that = this;
switch (_that) {
case _LineTypeDef():
return $default(_that.name,_that.description,_that.pattern,_that.patternLength);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  List<double> pattern,  double patternLength)?  $default,) {final _that = this;
switch (_that) {
case _LineTypeDef() when $default != null:
return $default(_that.name,_that.description,_that.pattern,_that.patternLength);case _:
  return null;

}
}

}

/// @nodoc


class _LineTypeDef extends LineTypeDef {
  const _LineTypeDef({required this.name, this.description = '', final  List<double> pattern = const [], this.patternLength = 0}): _pattern = pattern,super._();
  

@override final  String name;
@override@JsonKey() final  String description;
 final  List<double> _pattern;
@override@JsonKey() List<double> get pattern {
  if (_pattern is EqualUnmodifiableListView) return _pattern;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pattern);
}

@override@JsonKey() final  double patternLength;

/// Create a copy of LineTypeDef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineTypeDefCopyWith<_LineTypeDef> get copyWith => __$LineTypeDefCopyWithImpl<_LineTypeDef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineTypeDef&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._pattern, _pattern)&&(identical(other.patternLength, patternLength) || other.patternLength == patternLength));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_pattern),patternLength);



}

/// @nodoc
abstract mixin class _$LineTypeDefCopyWith<$Res> implements $LineTypeDefCopyWith<$Res> {
  factory _$LineTypeDefCopyWith(_LineTypeDef value, $Res Function(_LineTypeDef) _then) = __$LineTypeDefCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, List<double> pattern, double patternLength
});




}
/// @nodoc
class __$LineTypeDefCopyWithImpl<$Res>
    implements _$LineTypeDefCopyWith<$Res> {
  __$LineTypeDefCopyWithImpl(this._self, this._then);

  final _LineTypeDef _self;
  final $Res Function(_LineTypeDef) _then;

/// Create a copy of LineTypeDef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? pattern = null,Object? patternLength = null,}) {
  return _then(_LineTypeDef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,pattern: null == pattern ? _self._pattern : pattern // ignore: cast_nullable_to_non_nullable
as List<double>,patternLength: null == patternLength ? _self.patternLength : patternLength // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$TextStyleDef {

 String get name;/// The SHX or TTF font name recorded in the drawing.
 String get fontFamily;/// The secondary font used for CJK glyphs in SHX-based styles.
 String get bigFontFamily;/// A fixed height, or 0 when the height comes from each text entity.
 double get height; double get widthFactor; double get obliqueAngle; bool get backwards; bool get upsideDown;
/// Create a copy of TextStyleDef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextStyleDefCopyWith<TextStyleDef> get copyWith => _$TextStyleDefCopyWithImpl<TextStyleDef>(this as TextStyleDef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextStyleDef&&(identical(other.name, name) || other.name == name)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.bigFontFamily, bigFontFamily) || other.bigFontFamily == bigFontFamily)&&(identical(other.height, height) || other.height == height)&&(identical(other.widthFactor, widthFactor) || other.widthFactor == widthFactor)&&(identical(other.obliqueAngle, obliqueAngle) || other.obliqueAngle == obliqueAngle)&&(identical(other.backwards, backwards) || other.backwards == backwards)&&(identical(other.upsideDown, upsideDown) || other.upsideDown == upsideDown));
}


@override
int get hashCode => Object.hash(runtimeType,name,fontFamily,bigFontFamily,height,widthFactor,obliqueAngle,backwards,upsideDown);



}

/// @nodoc
abstract mixin class $TextStyleDefCopyWith<$Res>  {
  factory $TextStyleDefCopyWith(TextStyleDef value, $Res Function(TextStyleDef) _then) = _$TextStyleDefCopyWithImpl;
@useResult
$Res call({
 String name, String fontFamily, String bigFontFamily, double height, double widthFactor, double obliqueAngle, bool backwards, bool upsideDown
});




}
/// @nodoc
class _$TextStyleDefCopyWithImpl<$Res>
    implements $TextStyleDefCopyWith<$Res> {
  _$TextStyleDefCopyWithImpl(this._self, this._then);

  final TextStyleDef _self;
  final $Res Function(TextStyleDef) _then;

/// Create a copy of TextStyleDef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? fontFamily = null,Object? bigFontFamily = null,Object? height = null,Object? widthFactor = null,Object? obliqueAngle = null,Object? backwards = null,Object? upsideDown = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,bigFontFamily: null == bigFontFamily ? _self.bigFontFamily : bigFontFamily // ignore: cast_nullable_to_non_nullable
as String,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,widthFactor: null == widthFactor ? _self.widthFactor : widthFactor // ignore: cast_nullable_to_non_nullable
as double,obliqueAngle: null == obliqueAngle ? _self.obliqueAngle : obliqueAngle // ignore: cast_nullable_to_non_nullable
as double,backwards: null == backwards ? _self.backwards : backwards // ignore: cast_nullable_to_non_nullable
as bool,upsideDown: null == upsideDown ? _self.upsideDown : upsideDown // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TextStyleDef].
extension TextStyleDefPatterns on TextStyleDef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextStyleDef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextStyleDef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextStyleDef value)  $default,){
final _that = this;
switch (_that) {
case _TextStyleDef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextStyleDef value)?  $default,){
final _that = this;
switch (_that) {
case _TextStyleDef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String fontFamily,  String bigFontFamily,  double height,  double widthFactor,  double obliqueAngle,  bool backwards,  bool upsideDown)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextStyleDef() when $default != null:
return $default(_that.name,_that.fontFamily,_that.bigFontFamily,_that.height,_that.widthFactor,_that.obliqueAngle,_that.backwards,_that.upsideDown);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String fontFamily,  String bigFontFamily,  double height,  double widthFactor,  double obliqueAngle,  bool backwards,  bool upsideDown)  $default,) {final _that = this;
switch (_that) {
case _TextStyleDef():
return $default(_that.name,_that.fontFamily,_that.bigFontFamily,_that.height,_that.widthFactor,_that.obliqueAngle,_that.backwards,_that.upsideDown);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String fontFamily,  String bigFontFamily,  double height,  double widthFactor,  double obliqueAngle,  bool backwards,  bool upsideDown)?  $default,) {final _that = this;
switch (_that) {
case _TextStyleDef() when $default != null:
return $default(_that.name,_that.fontFamily,_that.bigFontFamily,_that.height,_that.widthFactor,_that.obliqueAngle,_that.backwards,_that.upsideDown);case _:
  return null;

}
}

}

/// @nodoc


class _TextStyleDef extends TextStyleDef {
  const _TextStyleDef({required this.name, this.fontFamily = 'txt', this.bigFontFamily = '', this.height = 0, this.widthFactor = 1, this.obliqueAngle = 0, this.backwards = false, this.upsideDown = false}): super._();
  

@override final  String name;
/// The SHX or TTF font name recorded in the drawing.
@override@JsonKey() final  String fontFamily;
/// The secondary font used for CJK glyphs in SHX-based styles.
@override@JsonKey() final  String bigFontFamily;
/// A fixed height, or 0 when the height comes from each text entity.
@override@JsonKey() final  double height;
@override@JsonKey() final  double widthFactor;
@override@JsonKey() final  double obliqueAngle;
@override@JsonKey() final  bool backwards;
@override@JsonKey() final  bool upsideDown;

/// Create a copy of TextStyleDef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextStyleDefCopyWith<_TextStyleDef> get copyWith => __$TextStyleDefCopyWithImpl<_TextStyleDef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextStyleDef&&(identical(other.name, name) || other.name == name)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.bigFontFamily, bigFontFamily) || other.bigFontFamily == bigFontFamily)&&(identical(other.height, height) || other.height == height)&&(identical(other.widthFactor, widthFactor) || other.widthFactor == widthFactor)&&(identical(other.obliqueAngle, obliqueAngle) || other.obliqueAngle == obliqueAngle)&&(identical(other.backwards, backwards) || other.backwards == backwards)&&(identical(other.upsideDown, upsideDown) || other.upsideDown == upsideDown));
}


@override
int get hashCode => Object.hash(runtimeType,name,fontFamily,bigFontFamily,height,widthFactor,obliqueAngle,backwards,upsideDown);



}

/// @nodoc
abstract mixin class _$TextStyleDefCopyWith<$Res> implements $TextStyleDefCopyWith<$Res> {
  factory _$TextStyleDefCopyWith(_TextStyleDef value, $Res Function(_TextStyleDef) _then) = __$TextStyleDefCopyWithImpl;
@override @useResult
$Res call({
 String name, String fontFamily, String bigFontFamily, double height, double widthFactor, double obliqueAngle, bool backwards, bool upsideDown
});




}
/// @nodoc
class __$TextStyleDefCopyWithImpl<$Res>
    implements _$TextStyleDefCopyWith<$Res> {
  __$TextStyleDefCopyWithImpl(this._self, this._then);

  final _TextStyleDef _self;
  final $Res Function(_TextStyleDef) _then;

/// Create a copy of TextStyleDef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? fontFamily = null,Object? bigFontFamily = null,Object? height = null,Object? widthFactor = null,Object? obliqueAngle = null,Object? backwards = null,Object? upsideDown = null,}) {
  return _then(_TextStyleDef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,bigFontFamily: null == bigFontFamily ? _self.bigFontFamily : bigFontFamily // ignore: cast_nullable_to_non_nullable
as String,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,widthFactor: null == widthFactor ? _self.widthFactor : widthFactor // ignore: cast_nullable_to_non_nullable
as double,obliqueAngle: null == obliqueAngle ? _self.obliqueAngle : obliqueAngle // ignore: cast_nullable_to_non_nullable
as double,backwards: null == backwards ? _self.backwards : backwards // ignore: cast_nullable_to_non_nullable
as bool,upsideDown: null == upsideDown ? _self.upsideDown : upsideDown // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$DimStyleDef {

 String get name; double get textHeight; double get arrowSize; double get extensionLineOffset; double get extensionLineExtend; double get textGap; double get scale; int get decimalPlaces; String get textStyle;
/// Create a copy of DimStyleDef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DimStyleDefCopyWith<DimStyleDef> get copyWith => _$DimStyleDefCopyWithImpl<DimStyleDef>(this as DimStyleDef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DimStyleDef&&(identical(other.name, name) || other.name == name)&&(identical(other.textHeight, textHeight) || other.textHeight == textHeight)&&(identical(other.arrowSize, arrowSize) || other.arrowSize == arrowSize)&&(identical(other.extensionLineOffset, extensionLineOffset) || other.extensionLineOffset == extensionLineOffset)&&(identical(other.extensionLineExtend, extensionLineExtend) || other.extensionLineExtend == extensionLineExtend)&&(identical(other.textGap, textGap) || other.textGap == textGap)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.decimalPlaces, decimalPlaces) || other.decimalPlaces == decimalPlaces)&&(identical(other.textStyle, textStyle) || other.textStyle == textStyle));
}


@override
int get hashCode => Object.hash(runtimeType,name,textHeight,arrowSize,extensionLineOffset,extensionLineExtend,textGap,scale,decimalPlaces,textStyle);



}

/// @nodoc
abstract mixin class $DimStyleDefCopyWith<$Res>  {
  factory $DimStyleDefCopyWith(DimStyleDef value, $Res Function(DimStyleDef) _then) = _$DimStyleDefCopyWithImpl;
@useResult
$Res call({
 String name, double textHeight, double arrowSize, double extensionLineOffset, double extensionLineExtend, double textGap, double scale, int decimalPlaces, String textStyle
});




}
/// @nodoc
class _$DimStyleDefCopyWithImpl<$Res>
    implements $DimStyleDefCopyWith<$Res> {
  _$DimStyleDefCopyWithImpl(this._self, this._then);

  final DimStyleDef _self;
  final $Res Function(DimStyleDef) _then;

/// Create a copy of DimStyleDef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? textHeight = null,Object? arrowSize = null,Object? extensionLineOffset = null,Object? extensionLineExtend = null,Object? textGap = null,Object? scale = null,Object? decimalPlaces = null,Object? textStyle = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,textHeight: null == textHeight ? _self.textHeight : textHeight // ignore: cast_nullable_to_non_nullable
as double,arrowSize: null == arrowSize ? _self.arrowSize : arrowSize // ignore: cast_nullable_to_non_nullable
as double,extensionLineOffset: null == extensionLineOffset ? _self.extensionLineOffset : extensionLineOffset // ignore: cast_nullable_to_non_nullable
as double,extensionLineExtend: null == extensionLineExtend ? _self.extensionLineExtend : extensionLineExtend // ignore: cast_nullable_to_non_nullable
as double,textGap: null == textGap ? _self.textGap : textGap // ignore: cast_nullable_to_non_nullable
as double,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,decimalPlaces: null == decimalPlaces ? _self.decimalPlaces : decimalPlaces // ignore: cast_nullable_to_non_nullable
as int,textStyle: null == textStyle ? _self.textStyle : textStyle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DimStyleDef].
extension DimStyleDefPatterns on DimStyleDef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DimStyleDef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DimStyleDef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DimStyleDef value)  $default,){
final _that = this;
switch (_that) {
case _DimStyleDef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DimStyleDef value)?  $default,){
final _that = this;
switch (_that) {
case _DimStyleDef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  double textHeight,  double arrowSize,  double extensionLineOffset,  double extensionLineExtend,  double textGap,  double scale,  int decimalPlaces,  String textStyle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DimStyleDef() when $default != null:
return $default(_that.name,_that.textHeight,_that.arrowSize,_that.extensionLineOffset,_that.extensionLineExtend,_that.textGap,_that.scale,_that.decimalPlaces,_that.textStyle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  double textHeight,  double arrowSize,  double extensionLineOffset,  double extensionLineExtend,  double textGap,  double scale,  int decimalPlaces,  String textStyle)  $default,) {final _that = this;
switch (_that) {
case _DimStyleDef():
return $default(_that.name,_that.textHeight,_that.arrowSize,_that.extensionLineOffset,_that.extensionLineExtend,_that.textGap,_that.scale,_that.decimalPlaces,_that.textStyle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  double textHeight,  double arrowSize,  double extensionLineOffset,  double extensionLineExtend,  double textGap,  double scale,  int decimalPlaces,  String textStyle)?  $default,) {final _that = this;
switch (_that) {
case _DimStyleDef() when $default != null:
return $default(_that.name,_that.textHeight,_that.arrowSize,_that.extensionLineOffset,_that.extensionLineExtend,_that.textGap,_that.scale,_that.decimalPlaces,_that.textStyle);case _:
  return null;

}
}

}

/// @nodoc


class _DimStyleDef extends DimStyleDef {
  const _DimStyleDef({required this.name, this.textHeight = 2.5, this.arrowSize = 2.5, this.extensionLineOffset = 0.625, this.extensionLineExtend = 1.25, this.textGap = 0.625, this.scale = 1, this.decimalPlaces = 2, this.textStyle = 'Standard'}): super._();
  

@override final  String name;
@override@JsonKey() final  double textHeight;
@override@JsonKey() final  double arrowSize;
@override@JsonKey() final  double extensionLineOffset;
@override@JsonKey() final  double extensionLineExtend;
@override@JsonKey() final  double textGap;
@override@JsonKey() final  double scale;
@override@JsonKey() final  int decimalPlaces;
@override@JsonKey() final  String textStyle;

/// Create a copy of DimStyleDef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DimStyleDefCopyWith<_DimStyleDef> get copyWith => __$DimStyleDefCopyWithImpl<_DimStyleDef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DimStyleDef&&(identical(other.name, name) || other.name == name)&&(identical(other.textHeight, textHeight) || other.textHeight == textHeight)&&(identical(other.arrowSize, arrowSize) || other.arrowSize == arrowSize)&&(identical(other.extensionLineOffset, extensionLineOffset) || other.extensionLineOffset == extensionLineOffset)&&(identical(other.extensionLineExtend, extensionLineExtend) || other.extensionLineExtend == extensionLineExtend)&&(identical(other.textGap, textGap) || other.textGap == textGap)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.decimalPlaces, decimalPlaces) || other.decimalPlaces == decimalPlaces)&&(identical(other.textStyle, textStyle) || other.textStyle == textStyle));
}


@override
int get hashCode => Object.hash(runtimeType,name,textHeight,arrowSize,extensionLineOffset,extensionLineExtend,textGap,scale,decimalPlaces,textStyle);



}

/// @nodoc
abstract mixin class _$DimStyleDefCopyWith<$Res> implements $DimStyleDefCopyWith<$Res> {
  factory _$DimStyleDefCopyWith(_DimStyleDef value, $Res Function(_DimStyleDef) _then) = __$DimStyleDefCopyWithImpl;
@override @useResult
$Res call({
 String name, double textHeight, double arrowSize, double extensionLineOffset, double extensionLineExtend, double textGap, double scale, int decimalPlaces, String textStyle
});




}
/// @nodoc
class __$DimStyleDefCopyWithImpl<$Res>
    implements _$DimStyleDefCopyWith<$Res> {
  __$DimStyleDefCopyWithImpl(this._self, this._then);

  final _DimStyleDef _self;
  final $Res Function(_DimStyleDef) _then;

/// Create a copy of DimStyleDef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? textHeight = null,Object? arrowSize = null,Object? extensionLineOffset = null,Object? extensionLineExtend = null,Object? textGap = null,Object? scale = null,Object? decimalPlaces = null,Object? textStyle = null,}) {
  return _then(_DimStyleDef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,textHeight: null == textHeight ? _self.textHeight : textHeight // ignore: cast_nullable_to_non_nullable
as double,arrowSize: null == arrowSize ? _self.arrowSize : arrowSize // ignore: cast_nullable_to_non_nullable
as double,extensionLineOffset: null == extensionLineOffset ? _self.extensionLineOffset : extensionLineOffset // ignore: cast_nullable_to_non_nullable
as double,extensionLineExtend: null == extensionLineExtend ? _self.extensionLineExtend : extensionLineExtend // ignore: cast_nullable_to_non_nullable
as double,textGap: null == textGap ? _self.textGap : textGap // ignore: cast_nullable_to_non_nullable
as double,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,decimalPlaces: null == decimalPlaces ? _self.decimalPlaces : decimalPlaces // ignore: cast_nullable_to_non_nullable
as int,textStyle: null == textStyle ? _self.textStyle : textStyle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
