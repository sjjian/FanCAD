// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AssistantProfile {

 String get id; String get label; String get model; String get baseUrl; String get apiKey;
/// Create a copy of AssistantProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantProfileCopyWith<AssistantProfile> get copyWith => _$AssistantProfileCopyWithImpl<AssistantProfile>(this as AssistantProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.model, model) || other.model == model)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,model,baseUrl,apiKey);

@override
String toString() {
  return 'AssistantProfile(id: $id, label: $label, model: $model, baseUrl: $baseUrl, apiKey: $apiKey)';
}


}

/// @nodoc
abstract mixin class $AssistantProfileCopyWith<$Res>  {
  factory $AssistantProfileCopyWith(AssistantProfile value, $Res Function(AssistantProfile) _then) = _$AssistantProfileCopyWithImpl;
@useResult
$Res call({
 String id, String label, String model, String baseUrl, String apiKey
});




}
/// @nodoc
class _$AssistantProfileCopyWithImpl<$Res>
    implements $AssistantProfileCopyWith<$Res> {
  _$AssistantProfileCopyWithImpl(this._self, this._then);

  final AssistantProfile _self;
  final $Res Function(AssistantProfile) _then;

/// Create a copy of AssistantProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? model = null,Object? baseUrl = null,Object? apiKey = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantProfile].
extension AssistantProfilePatterns on AssistantProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantProfile value)  $default,){
final _that = this;
switch (_that) {
case _AssistantProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantProfile value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String model,  String baseUrl,  String apiKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantProfile() when $default != null:
return $default(_that.id,_that.label,_that.model,_that.baseUrl,_that.apiKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String model,  String baseUrl,  String apiKey)  $default,) {final _that = this;
switch (_that) {
case _AssistantProfile():
return $default(_that.id,_that.label,_that.model,_that.baseUrl,_that.apiKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String model,  String baseUrl,  String apiKey)?  $default,) {final _that = this;
switch (_that) {
case _AssistantProfile() when $default != null:
return $default(_that.id,_that.label,_that.model,_that.baseUrl,_that.apiKey);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantProfile extends AssistantProfile {
  const _AssistantProfile({required this.id, this.label = '', this.model = 'gpt-4o-mini', this.baseUrl = 'https://api.openai.com/v1', this.apiKey = ''}): super._();
  

@override final  String id;
@override@JsonKey() final  String label;
@override@JsonKey() final  String model;
@override@JsonKey() final  String baseUrl;
@override@JsonKey() final  String apiKey;

/// Create a copy of AssistantProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantProfileCopyWith<_AssistantProfile> get copyWith => __$AssistantProfileCopyWithImpl<_AssistantProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.model, model) || other.model == model)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,model,baseUrl,apiKey);

@override
String toString() {
  return 'AssistantProfile(id: $id, label: $label, model: $model, baseUrl: $baseUrl, apiKey: $apiKey)';
}


}

/// @nodoc
abstract mixin class _$AssistantProfileCopyWith<$Res> implements $AssistantProfileCopyWith<$Res> {
  factory _$AssistantProfileCopyWith(_AssistantProfile value, $Res Function(_AssistantProfile) _then) = __$AssistantProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String model, String baseUrl, String apiKey
});




}
/// @nodoc
class __$AssistantProfileCopyWithImpl<$Res>
    implements _$AssistantProfileCopyWith<$Res> {
  __$AssistantProfileCopyWithImpl(this._self, this._then);

  final _AssistantProfile _self;
  final $Res Function(_AssistantProfile) _then;

/// Create a copy of AssistantProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? model = null,Object? baseUrl = null,Object? apiKey = null,}) {
  return _then(_AssistantProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
