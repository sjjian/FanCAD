// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sidebar.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SidebarModel {

 String get viewId; bool get isOpen; double get width;
/// Create a copy of SidebarModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SidebarModelCopyWith<SidebarModel> get copyWith => _$SidebarModelCopyWithImpl<SidebarModel>(this as SidebarModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SidebarModel&&(identical(other.viewId, viewId) || other.viewId == viewId)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,viewId,isOpen,width);

@override
String toString() {
  return 'SidebarModel(viewId: $viewId, isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class $SidebarModelCopyWith<$Res>  {
  factory $SidebarModelCopyWith(SidebarModel value, $Res Function(SidebarModel) _then) = _$SidebarModelCopyWithImpl;
@useResult
$Res call({
 String viewId, bool isOpen, double width
});




}
/// @nodoc
class _$SidebarModelCopyWithImpl<$Res>
    implements $SidebarModelCopyWith<$Res> {
  _$SidebarModelCopyWithImpl(this._self, this._then);

  final SidebarModel _self;
  final $Res Function(SidebarModel) _then;

/// Create a copy of SidebarModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? viewId = null,Object? isOpen = null,Object? width = null,}) {
  return _then(_self.copyWith(
viewId: null == viewId ? _self.viewId : viewId // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SidebarModel].
extension SidebarModelPatterns on SidebarModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SidebarModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SidebarModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SidebarModel value)  $default,){
final _that = this;
switch (_that) {
case _SidebarModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SidebarModel value)?  $default,){
final _that = this;
switch (_that) {
case _SidebarModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String viewId,  bool isOpen,  double width)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SidebarModel() when $default != null:
return $default(_that.viewId,_that.isOpen,_that.width);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String viewId,  bool isOpen,  double width)  $default,) {final _that = this;
switch (_that) {
case _SidebarModel():
return $default(_that.viewId,_that.isOpen,_that.width);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String viewId,  bool isOpen,  double width)?  $default,) {final _that = this;
switch (_that) {
case _SidebarModel() when $default != null:
return $default(_that.viewId,_that.isOpen,_that.width);case _:
  return null;

}
}

}

/// @nodoc


class _SidebarModel implements SidebarModel {
  const _SidebarModel({this.viewId = 'layers', this.isOpen = true, this.width = SidebarLayout.defaultWidth});
  

@override@JsonKey() final  String viewId;
@override@JsonKey() final  bool isOpen;
@override@JsonKey() final  double width;

/// Create a copy of SidebarModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SidebarModelCopyWith<_SidebarModel> get copyWith => __$SidebarModelCopyWithImpl<_SidebarModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SidebarModel&&(identical(other.viewId, viewId) || other.viewId == viewId)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,viewId,isOpen,width);

@override
String toString() {
  return 'SidebarModel(viewId: $viewId, isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class _$SidebarModelCopyWith<$Res> implements $SidebarModelCopyWith<$Res> {
  factory _$SidebarModelCopyWith(_SidebarModel value, $Res Function(_SidebarModel) _then) = __$SidebarModelCopyWithImpl;
@override @useResult
$Res call({
 String viewId, bool isOpen, double width
});




}
/// @nodoc
class __$SidebarModelCopyWithImpl<$Res>
    implements _$SidebarModelCopyWith<$Res> {
  __$SidebarModelCopyWithImpl(this._self, this._then);

  final _SidebarModel _self;
  final $Res Function(_SidebarModel) _then;

/// Create a copy of SidebarModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? viewId = null,Object? isOpen = null,Object? width = null,}) {
  return _then(_SidebarModel(
viewId: null == viewId ? _self.viewId : viewId // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
