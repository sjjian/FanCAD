// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geometry_sink.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResolvedStyle {

 String get layer; CadColor get color; String get lineType; int get lineWeight; double get lineTypeScale; int get transparency;
/// Create a copy of ResolvedStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResolvedStyleCopyWith<ResolvedStyle> get copyWith => _$ResolvedStyleCopyWithImpl<ResolvedStyle>(this as ResolvedStyle, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResolvedStyle&&(identical(other.layer, layer) || other.layer == layer)&&(identical(other.color, color) || other.color == color)&&(identical(other.lineType, lineType) || other.lineType == lineType)&&(identical(other.lineWeight, lineWeight) || other.lineWeight == lineWeight)&&(identical(other.lineTypeScale, lineTypeScale) || other.lineTypeScale == lineTypeScale)&&(identical(other.transparency, transparency) || other.transparency == transparency));
}


@override
int get hashCode => Object.hash(runtimeType,layer,color,lineType,lineWeight,lineTypeScale,transparency);

@override
String toString() {
  return 'ResolvedStyle(layer: $layer, color: $color, lineType: $lineType, lineWeight: $lineWeight, lineTypeScale: $lineTypeScale, transparency: $transparency)';
}


}

/// @nodoc
abstract mixin class $ResolvedStyleCopyWith<$Res>  {
  factory $ResolvedStyleCopyWith(ResolvedStyle value, $Res Function(ResolvedStyle) _then) = _$ResolvedStyleCopyWithImpl;
@useResult
$Res call({
 String layer, CadColor color, String lineType, int lineWeight, double lineTypeScale, int transparency
});




}
/// @nodoc
class _$ResolvedStyleCopyWithImpl<$Res>
    implements $ResolvedStyleCopyWith<$Res> {
  _$ResolvedStyleCopyWithImpl(this._self, this._then);

  final ResolvedStyle _self;
  final $Res Function(ResolvedStyle) _then;

/// Create a copy of ResolvedStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? layer = null,Object? color = null,Object? lineType = null,Object? lineWeight = null,Object? lineTypeScale = null,Object? transparency = null,}) {
  return _then(_self.copyWith(
layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as CadColor,lineType: null == lineType ? _self.lineType : lineType // ignore: cast_nullable_to_non_nullable
as String,lineWeight: null == lineWeight ? _self.lineWeight : lineWeight // ignore: cast_nullable_to_non_nullable
as int,lineTypeScale: null == lineTypeScale ? _self.lineTypeScale : lineTypeScale // ignore: cast_nullable_to_non_nullable
as double,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ResolvedStyle].
extension ResolvedStylePatterns on ResolvedStyle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResolvedStyle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResolvedStyle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResolvedStyle value)  $default,){
final _that = this;
switch (_that) {
case _ResolvedStyle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResolvedStyle value)?  $default,){
final _that = this;
switch (_that) {
case _ResolvedStyle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String layer,  CadColor color,  String lineType,  int lineWeight,  double lineTypeScale,  int transparency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResolvedStyle() when $default != null:
return $default(_that.layer,_that.color,_that.lineType,_that.lineWeight,_that.lineTypeScale,_that.transparency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String layer,  CadColor color,  String lineType,  int lineWeight,  double lineTypeScale,  int transparency)  $default,) {final _that = this;
switch (_that) {
case _ResolvedStyle():
return $default(_that.layer,_that.color,_that.lineType,_that.lineWeight,_that.lineTypeScale,_that.transparency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String layer,  CadColor color,  String lineType,  int lineWeight,  double lineTypeScale,  int transparency)?  $default,) {final _that = this;
switch (_that) {
case _ResolvedStyle() when $default != null:
return $default(_that.layer,_that.color,_that.lineType,_that.lineWeight,_that.lineTypeScale,_that.transparency);case _:
  return null;

}
}

}

/// @nodoc


class _ResolvedStyle extends ResolvedStyle {
  const _ResolvedStyle({required this.layer, required this.color, required this.lineType, required this.lineWeight, this.lineTypeScale = 1, this.transparency = 0}): super._();
  

@override final  String layer;
@override final  CadColor color;
@override final  String lineType;
@override final  int lineWeight;
@override@JsonKey() final  double lineTypeScale;
@override@JsonKey() final  int transparency;

/// Create a copy of ResolvedStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResolvedStyleCopyWith<_ResolvedStyle> get copyWith => __$ResolvedStyleCopyWithImpl<_ResolvedStyle>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResolvedStyle&&(identical(other.layer, layer) || other.layer == layer)&&(identical(other.color, color) || other.color == color)&&(identical(other.lineType, lineType) || other.lineType == lineType)&&(identical(other.lineWeight, lineWeight) || other.lineWeight == lineWeight)&&(identical(other.lineTypeScale, lineTypeScale) || other.lineTypeScale == lineTypeScale)&&(identical(other.transparency, transparency) || other.transparency == transparency));
}


@override
int get hashCode => Object.hash(runtimeType,layer,color,lineType,lineWeight,lineTypeScale,transparency);

@override
String toString() {
  return 'ResolvedStyle(layer: $layer, color: $color, lineType: $lineType, lineWeight: $lineWeight, lineTypeScale: $lineTypeScale, transparency: $transparency)';
}


}

/// @nodoc
abstract mixin class _$ResolvedStyleCopyWith<$Res> implements $ResolvedStyleCopyWith<$Res> {
  factory _$ResolvedStyleCopyWith(_ResolvedStyle value, $Res Function(_ResolvedStyle) _then) = __$ResolvedStyleCopyWithImpl;
@override @useResult
$Res call({
 String layer, CadColor color, String lineType, int lineWeight, double lineTypeScale, int transparency
});




}
/// @nodoc
class __$ResolvedStyleCopyWithImpl<$Res>
    implements _$ResolvedStyleCopyWith<$Res> {
  __$ResolvedStyleCopyWithImpl(this._self, this._then);

  final _ResolvedStyle _self;
  final $Res Function(_ResolvedStyle) _then;

/// Create a copy of ResolvedStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? layer = null,Object? color = null,Object? lineType = null,Object? lineWeight = null,Object? lineTypeScale = null,Object? transparency = null,}) {
  return _then(_ResolvedStyle(
layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as CadColor,lineType: null == lineType ? _self.lineType : lineType // ignore: cast_nullable_to_non_nullable
as String,lineWeight: null == lineWeight ? _self.lineWeight : lineWeight // ignore: cast_nullable_to_non_nullable
as int,lineTypeScale: null == lineTypeScale ? _self.lineTypeScale : lineTypeScale // ignore: cast_nullable_to_non_nullable
as double,transparency: null == transparency ? _self.transparency : transparency // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
