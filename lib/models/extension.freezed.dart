// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'extension.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExtensionModel {

 String get directory; int get epoch;
/// Create a copy of ExtensionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExtensionModelCopyWith<ExtensionModel> get copyWith => _$ExtensionModelCopyWithImpl<ExtensionModel>(this as ExtensionModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExtensionModel&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode => Object.hash(runtimeType,directory,epoch);

@override
String toString() {
  return 'ExtensionModel(directory: $directory, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class $ExtensionModelCopyWith<$Res>  {
  factory $ExtensionModelCopyWith(ExtensionModel value, $Res Function(ExtensionModel) _then) = _$ExtensionModelCopyWithImpl;
@useResult
$Res call({
 String directory, int epoch
});




}
/// @nodoc
class _$ExtensionModelCopyWithImpl<$Res>
    implements $ExtensionModelCopyWith<$Res> {
  _$ExtensionModelCopyWithImpl(this._self, this._then);

  final ExtensionModel _self;
  final $Res Function(ExtensionModel) _then;

/// Create a copy of ExtensionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? directory = null,Object? epoch = null,}) {
  return _then(_self.copyWith(
directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,epoch: null == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ExtensionModel].
extension ExtensionModelPatterns on ExtensionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExtensionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExtensionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExtensionModel value)  $default,){
final _that = this;
switch (_that) {
case _ExtensionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExtensionModel value)?  $default,){
final _that = this;
switch (_that) {
case _ExtensionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String directory,  int epoch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExtensionModel() when $default != null:
return $default(_that.directory,_that.epoch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String directory,  int epoch)  $default,) {final _that = this;
switch (_that) {
case _ExtensionModel():
return $default(_that.directory,_that.epoch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String directory,  int epoch)?  $default,) {final _that = this;
switch (_that) {
case _ExtensionModel() when $default != null:
return $default(_that.directory,_that.epoch);case _:
  return null;

}
}

}

/// @nodoc


class _ExtensionModel implements ExtensionModel {
  const _ExtensionModel({this.directory = '', this.epoch = 0});
  

@override@JsonKey() final  String directory;
@override@JsonKey() final  int epoch;

/// Create a copy of ExtensionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExtensionModelCopyWith<_ExtensionModel> get copyWith => __$ExtensionModelCopyWithImpl<_ExtensionModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExtensionModel&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode => Object.hash(runtimeType,directory,epoch);

@override
String toString() {
  return 'ExtensionModel(directory: $directory, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class _$ExtensionModelCopyWith<$Res> implements $ExtensionModelCopyWith<$Res> {
  factory _$ExtensionModelCopyWith(_ExtensionModel value, $Res Function(_ExtensionModel) _then) = __$ExtensionModelCopyWithImpl;
@override @useResult
$Res call({
 String directory, int epoch
});




}
/// @nodoc
class __$ExtensionModelCopyWithImpl<$Res>
    implements _$ExtensionModelCopyWith<$Res> {
  __$ExtensionModelCopyWithImpl(this._self, this._then);

  final _ExtensionModel _self;
  final $Res Function(_ExtensionModel) _then;

/// Create a copy of ExtensionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? directory = null,Object? epoch = null,}) {
  return _then(_ExtensionModel(
directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,epoch: null == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
