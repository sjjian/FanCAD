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
mixin _$LayoutModel {

 String get sidebarView; bool get sidebarOpen; bool get assistantOpen; double get sidebarWidth; double get assistantWidth; double get commandHeight;
/// Create a copy of LayoutModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LayoutModelCopyWith<LayoutModel> get copyWith => _$LayoutModelCopyWithImpl<LayoutModel>(this as LayoutModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LayoutModel&&(identical(other.sidebarView, sidebarView) || other.sidebarView == sidebarView)&&(identical(other.sidebarOpen, sidebarOpen) || other.sidebarOpen == sidebarOpen)&&(identical(other.assistantOpen, assistantOpen) || other.assistantOpen == assistantOpen)&&(identical(other.sidebarWidth, sidebarWidth) || other.sidebarWidth == sidebarWidth)&&(identical(other.assistantWidth, assistantWidth) || other.assistantWidth == assistantWidth)&&(identical(other.commandHeight, commandHeight) || other.commandHeight == commandHeight));
}


@override
int get hashCode => Object.hash(runtimeType,sidebarView,sidebarOpen,assistantOpen,sidebarWidth,assistantWidth,commandHeight);

@override
String toString() {
  return 'LayoutModel(sidebarView: $sidebarView, sidebarOpen: $sidebarOpen, assistantOpen: $assistantOpen, sidebarWidth: $sidebarWidth, assistantWidth: $assistantWidth, commandHeight: $commandHeight)';
}


}

/// @nodoc
abstract mixin class $LayoutModelCopyWith<$Res>  {
  factory $LayoutModelCopyWith(LayoutModel value, $Res Function(LayoutModel) _then) = _$LayoutModelCopyWithImpl;
@useResult
$Res call({
 String sidebarView, bool sidebarOpen, bool assistantOpen, double sidebarWidth, double assistantWidth, double commandHeight
});




}
/// @nodoc
class _$LayoutModelCopyWithImpl<$Res>
    implements $LayoutModelCopyWith<$Res> {
  _$LayoutModelCopyWithImpl(this._self, this._then);

  final LayoutModel _self;
  final $Res Function(LayoutModel) _then;

/// Create a copy of LayoutModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sidebarView = null,Object? sidebarOpen = null,Object? assistantOpen = null,Object? sidebarWidth = null,Object? assistantWidth = null,Object? commandHeight = null,}) {
  return _then(_self.copyWith(
sidebarView: null == sidebarView ? _self.sidebarView : sidebarView // ignore: cast_nullable_to_non_nullable
as String,sidebarOpen: null == sidebarOpen ? _self.sidebarOpen : sidebarOpen // ignore: cast_nullable_to_non_nullable
as bool,assistantOpen: null == assistantOpen ? _self.assistantOpen : assistantOpen // ignore: cast_nullable_to_non_nullable
as bool,sidebarWidth: null == sidebarWidth ? _self.sidebarWidth : sidebarWidth // ignore: cast_nullable_to_non_nullable
as double,assistantWidth: null == assistantWidth ? _self.assistantWidth : assistantWidth // ignore: cast_nullable_to_non_nullable
as double,commandHeight: null == commandHeight ? _self.commandHeight : commandHeight // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LayoutModel].
extension LayoutModelPatterns on LayoutModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LayoutModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LayoutModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LayoutModel value)  $default,){
final _that = this;
switch (_that) {
case _LayoutModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LayoutModel value)?  $default,){
final _that = this;
switch (_that) {
case _LayoutModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sidebarView,  bool sidebarOpen,  bool assistantOpen,  double sidebarWidth,  double assistantWidth,  double commandHeight)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LayoutModel() when $default != null:
return $default(_that.sidebarView,_that.sidebarOpen,_that.assistantOpen,_that.sidebarWidth,_that.assistantWidth,_that.commandHeight);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sidebarView,  bool sidebarOpen,  bool assistantOpen,  double sidebarWidth,  double assistantWidth,  double commandHeight)  $default,) {final _that = this;
switch (_that) {
case _LayoutModel():
return $default(_that.sidebarView,_that.sidebarOpen,_that.assistantOpen,_that.sidebarWidth,_that.assistantWidth,_that.commandHeight);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sidebarView,  bool sidebarOpen,  bool assistantOpen,  double sidebarWidth,  double assistantWidth,  double commandHeight)?  $default,) {final _that = this;
switch (_that) {
case _LayoutModel() when $default != null:
return $default(_that.sidebarView,_that.sidebarOpen,_that.assistantOpen,_that.sidebarWidth,_that.assistantWidth,_that.commandHeight);case _:
  return null;

}
}

}

/// @nodoc


class _LayoutModel implements LayoutModel {
  const _LayoutModel({this.sidebarView = 'layers', this.sidebarOpen = true, this.assistantOpen = false, this.sidebarWidth = SidebarLayout.defaultWidth, this.assistantWidth = AssistantPaneLayout.defaultWidth, this.commandHeight = CommandLineLayout.defaultHeight});
  

@override@JsonKey() final  String sidebarView;
@override@JsonKey() final  bool sidebarOpen;
@override@JsonKey() final  bool assistantOpen;
@override@JsonKey() final  double sidebarWidth;
@override@JsonKey() final  double assistantWidth;
@override@JsonKey() final  double commandHeight;

/// Create a copy of LayoutModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LayoutModelCopyWith<_LayoutModel> get copyWith => __$LayoutModelCopyWithImpl<_LayoutModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LayoutModel&&(identical(other.sidebarView, sidebarView) || other.sidebarView == sidebarView)&&(identical(other.sidebarOpen, sidebarOpen) || other.sidebarOpen == sidebarOpen)&&(identical(other.assistantOpen, assistantOpen) || other.assistantOpen == assistantOpen)&&(identical(other.sidebarWidth, sidebarWidth) || other.sidebarWidth == sidebarWidth)&&(identical(other.assistantWidth, assistantWidth) || other.assistantWidth == assistantWidth)&&(identical(other.commandHeight, commandHeight) || other.commandHeight == commandHeight));
}


@override
int get hashCode => Object.hash(runtimeType,sidebarView,sidebarOpen,assistantOpen,sidebarWidth,assistantWidth,commandHeight);

@override
String toString() {
  return 'LayoutModel(sidebarView: $sidebarView, sidebarOpen: $sidebarOpen, assistantOpen: $assistantOpen, sidebarWidth: $sidebarWidth, assistantWidth: $assistantWidth, commandHeight: $commandHeight)';
}


}

/// @nodoc
abstract mixin class _$LayoutModelCopyWith<$Res> implements $LayoutModelCopyWith<$Res> {
  factory _$LayoutModelCopyWith(_LayoutModel value, $Res Function(_LayoutModel) _then) = __$LayoutModelCopyWithImpl;
@override @useResult
$Res call({
 String sidebarView, bool sidebarOpen, bool assistantOpen, double sidebarWidth, double assistantWidth, double commandHeight
});




}
/// @nodoc
class __$LayoutModelCopyWithImpl<$Res>
    implements _$LayoutModelCopyWith<$Res> {
  __$LayoutModelCopyWithImpl(this._self, this._then);

  final _LayoutModel _self;
  final $Res Function(_LayoutModel) _then;

/// Create a copy of LayoutModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sidebarView = null,Object? sidebarOpen = null,Object? assistantOpen = null,Object? sidebarWidth = null,Object? assistantWidth = null,Object? commandHeight = null,}) {
  return _then(_LayoutModel(
sidebarView: null == sidebarView ? _self.sidebarView : sidebarView // ignore: cast_nullable_to_non_nullable
as String,sidebarOpen: null == sidebarOpen ? _self.sidebarOpen : sidebarOpen // ignore: cast_nullable_to_non_nullable
as bool,assistantOpen: null == assistantOpen ? _self.assistantOpen : assistantOpen // ignore: cast_nullable_to_non_nullable
as bool,sidebarWidth: null == sidebarWidth ? _self.sidebarWidth : sidebarWidth // ignore: cast_nullable_to_non_nullable
as double,assistantWidth: null == assistantWidth ? _self.assistantWidth : assistantWidth // ignore: cast_nullable_to_non_nullable
as double,commandHeight: null == commandHeight ? _self.commandHeight : commandHeight // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
