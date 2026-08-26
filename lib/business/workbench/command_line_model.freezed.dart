// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command_line_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HistoryLine implements DiagnosticableTreeMixin {

 String get text; HistoryLevel get level;
/// Create a copy of HistoryLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HistoryLineCopyWith<HistoryLine> get copyWith => _$HistoryLineCopyWithImpl<HistoryLine>(this as HistoryLine, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'HistoryLine'))
    ..add(DiagnosticsProperty('text', text))..add(DiagnosticsProperty('level', level));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryLine&&(identical(other.text, text) || other.text == text)&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode => Object.hash(runtimeType,text,level);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'HistoryLine(text: $text, level: $level)';
}


}

/// @nodoc
abstract mixin class $HistoryLineCopyWith<$Res>  {
  factory $HistoryLineCopyWith(HistoryLine value, $Res Function(HistoryLine) _then) = _$HistoryLineCopyWithImpl;
@useResult
$Res call({
 String text, HistoryLevel level
});




}
/// @nodoc
class _$HistoryLineCopyWithImpl<$Res>
    implements $HistoryLineCopyWith<$Res> {
  _$HistoryLineCopyWithImpl(this._self, this._then);

  final HistoryLine _self;
  final $Res Function(HistoryLine) _then;

/// Create a copy of HistoryLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? level = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as HistoryLevel,
  ));
}

}


/// Adds pattern-matching-related methods to [HistoryLine].
extension HistoryLinePatterns on HistoryLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HistoryLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HistoryLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HistoryLine value)  $default,){
final _that = this;
switch (_that) {
case _HistoryLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HistoryLine value)?  $default,){
final _that = this;
switch (_that) {
case _HistoryLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  HistoryLevel level)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HistoryLine() when $default != null:
return $default(_that.text,_that.level);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  HistoryLevel level)  $default,) {final _that = this;
switch (_that) {
case _HistoryLine():
return $default(_that.text,_that.level);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  HistoryLevel level)?  $default,) {final _that = this;
switch (_that) {
case _HistoryLine() when $default != null:
return $default(_that.text,_that.level);case _:
  return null;

}
}

}

/// @nodoc


class _HistoryLine with DiagnosticableTreeMixin implements HistoryLine {
  const _HistoryLine(this.text, {this.level = HistoryLevel.normal});
  

@override final  String text;
@override@JsonKey() final  HistoryLevel level;

/// Create a copy of HistoryLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryLineCopyWith<_HistoryLine> get copyWith => __$HistoryLineCopyWithImpl<_HistoryLine>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'HistoryLine'))
    ..add(DiagnosticsProperty('text', text))..add(DiagnosticsProperty('level', level));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryLine&&(identical(other.text, text) || other.text == text)&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode => Object.hash(runtimeType,text,level);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'HistoryLine(text: $text, level: $level)';
}


}

/// @nodoc
abstract mixin class _$HistoryLineCopyWith<$Res> implements $HistoryLineCopyWith<$Res> {
  factory _$HistoryLineCopyWith(_HistoryLine value, $Res Function(_HistoryLine) _then) = __$HistoryLineCopyWithImpl;
@override @useResult
$Res call({
 String text, HistoryLevel level
});




}
/// @nodoc
class __$HistoryLineCopyWithImpl<$Res>
    implements _$HistoryLineCopyWith<$Res> {
  __$HistoryLineCopyWithImpl(this._self, this._then);

  final _HistoryLine _self;
  final $Res Function(_HistoryLine) _then;

/// Create a copy of HistoryLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? level = null,}) {
  return _then(_HistoryLine(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as HistoryLevel,
  ));
}


}

// dart format on
