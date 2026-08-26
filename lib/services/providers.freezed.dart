// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SidebarState {

 String get viewId; bool get isOpen; double get width;
/// Create a copy of SidebarState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SidebarStateCopyWith<SidebarState> get copyWith => _$SidebarStateCopyWithImpl<SidebarState>(this as SidebarState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SidebarState&&(identical(other.viewId, viewId) || other.viewId == viewId)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,viewId,isOpen,width);

@override
String toString() {
  return 'SidebarState(viewId: $viewId, isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class $SidebarStateCopyWith<$Res>  {
  factory $SidebarStateCopyWith(SidebarState value, $Res Function(SidebarState) _then) = _$SidebarStateCopyWithImpl;
@useResult
$Res call({
 String viewId, bool isOpen, double width
});




}
/// @nodoc
class _$SidebarStateCopyWithImpl<$Res>
    implements $SidebarStateCopyWith<$Res> {
  _$SidebarStateCopyWithImpl(this._self, this._then);

  final SidebarState _self;
  final $Res Function(SidebarState) _then;

/// Create a copy of SidebarState
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


/// Adds pattern-matching-related methods to [SidebarState].
extension SidebarStatePatterns on SidebarState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SidebarState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SidebarState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SidebarState value)  $default,){
final _that = this;
switch (_that) {
case _SidebarState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SidebarState value)?  $default,){
final _that = this;
switch (_that) {
case _SidebarState() when $default != null:
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
case _SidebarState() when $default != null:
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
case _SidebarState():
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
case _SidebarState() when $default != null:
return $default(_that.viewId,_that.isOpen,_that.width);case _:
  return null;

}
}

}

/// @nodoc


class _SidebarState implements SidebarState {
  const _SidebarState({this.viewId = 'layers', this.isOpen = true, this.width = FanCadTokens.sidePanelWidth});
  

@override@JsonKey() final  String viewId;
@override@JsonKey() final  bool isOpen;
@override@JsonKey() final  double width;

/// Create a copy of SidebarState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SidebarStateCopyWith<_SidebarState> get copyWith => __$SidebarStateCopyWithImpl<_SidebarState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SidebarState&&(identical(other.viewId, viewId) || other.viewId == viewId)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,viewId,isOpen,width);

@override
String toString() {
  return 'SidebarState(viewId: $viewId, isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class _$SidebarStateCopyWith<$Res> implements $SidebarStateCopyWith<$Res> {
  factory _$SidebarStateCopyWith(_SidebarState value, $Res Function(_SidebarState) _then) = __$SidebarStateCopyWithImpl;
@override @useResult
$Res call({
 String viewId, bool isOpen, double width
});




}
/// @nodoc
class __$SidebarStateCopyWithImpl<$Res>
    implements _$SidebarStateCopyWith<$Res> {
  __$SidebarStateCopyWithImpl(this._self, this._then);

  final _SidebarState _self;
  final $Res Function(_SidebarState) _then;

/// Create a copy of SidebarState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? viewId = null,Object? isOpen = null,Object? width = null,}) {
  return _then(_SidebarState(
viewId: null == viewId ? _self.viewId : viewId // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$CommandPaneState {

 double get height; bool get isExpanded;
/// Create a copy of CommandPaneState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandPaneStateCopyWith<CommandPaneState> get copyWith => _$CommandPaneStateCopyWithImpl<CommandPaneState>(this as CommandPaneState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandPaneState&&(identical(other.height, height) || other.height == height)&&(identical(other.isExpanded, isExpanded) || other.isExpanded == isExpanded));
}


@override
int get hashCode => Object.hash(runtimeType,height,isExpanded);

@override
String toString() {
  return 'CommandPaneState(height: $height, isExpanded: $isExpanded)';
}


}

/// @nodoc
abstract mixin class $CommandPaneStateCopyWith<$Res>  {
  factory $CommandPaneStateCopyWith(CommandPaneState value, $Res Function(CommandPaneState) _then) = _$CommandPaneStateCopyWithImpl;
@useResult
$Res call({
 double height, bool isExpanded
});




}
/// @nodoc
class _$CommandPaneStateCopyWithImpl<$Res>
    implements $CommandPaneStateCopyWith<$Res> {
  _$CommandPaneStateCopyWithImpl(this._self, this._then);

  final CommandPaneState _self;
  final $Res Function(CommandPaneState) _then;

/// Create a copy of CommandPaneState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? height = null,Object? isExpanded = null,}) {
  return _then(_self.copyWith(
height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,isExpanded: null == isExpanded ? _self.isExpanded : isExpanded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CommandPaneState].
extension CommandPaneStatePatterns on CommandPaneState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandPaneState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandPaneState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandPaneState value)  $default,){
final _that = this;
switch (_that) {
case _CommandPaneState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandPaneState value)?  $default,){
final _that = this;
switch (_that) {
case _CommandPaneState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double height,  bool isExpanded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandPaneState() when $default != null:
return $default(_that.height,_that.isExpanded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double height,  bool isExpanded)  $default,) {final _that = this;
switch (_that) {
case _CommandPaneState():
return $default(_that.height,_that.isExpanded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double height,  bool isExpanded)?  $default,) {final _that = this;
switch (_that) {
case _CommandPaneState() when $default != null:
return $default(_that.height,_that.isExpanded);case _:
  return null;

}
}

}

/// @nodoc


class _CommandPaneState implements CommandPaneState {
  const _CommandPaneState({this.height = 84, this.isExpanded = false});
  

@override@JsonKey() final  double height;
@override@JsonKey() final  bool isExpanded;

/// Create a copy of CommandPaneState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandPaneStateCopyWith<_CommandPaneState> get copyWith => __$CommandPaneStateCopyWithImpl<_CommandPaneState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandPaneState&&(identical(other.height, height) || other.height == height)&&(identical(other.isExpanded, isExpanded) || other.isExpanded == isExpanded));
}


@override
int get hashCode => Object.hash(runtimeType,height,isExpanded);

@override
String toString() {
  return 'CommandPaneState(height: $height, isExpanded: $isExpanded)';
}


}

/// @nodoc
abstract mixin class _$CommandPaneStateCopyWith<$Res> implements $CommandPaneStateCopyWith<$Res> {
  factory _$CommandPaneStateCopyWith(_CommandPaneState value, $Res Function(_CommandPaneState) _then) = __$CommandPaneStateCopyWithImpl;
@override @useResult
$Res call({
 double height, bool isExpanded
});




}
/// @nodoc
class __$CommandPaneStateCopyWithImpl<$Res>
    implements _$CommandPaneStateCopyWith<$Res> {
  __$CommandPaneStateCopyWithImpl(this._self, this._then);

  final _CommandPaneState _self;
  final $Res Function(_CommandPaneState) _then;

/// Create a copy of CommandPaneState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? height = null,Object? isExpanded = null,}) {
  return _then(_CommandPaneState(
height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,isExpanded: null == isExpanded ? _self.isExpanded : isExpanded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$AssistantPaneState {

 bool get isOpen; double get width;
/// Create a copy of AssistantPaneState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantPaneStateCopyWith<AssistantPaneState> get copyWith => _$AssistantPaneStateCopyWithImpl<AssistantPaneState>(this as AssistantPaneState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantPaneState&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,isOpen,width);

@override
String toString() {
  return 'AssistantPaneState(isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class $AssistantPaneStateCopyWith<$Res>  {
  factory $AssistantPaneStateCopyWith(AssistantPaneState value, $Res Function(AssistantPaneState) _then) = _$AssistantPaneStateCopyWithImpl;
@useResult
$Res call({
 bool isOpen, double width
});




}
/// @nodoc
class _$AssistantPaneStateCopyWithImpl<$Res>
    implements $AssistantPaneStateCopyWith<$Res> {
  _$AssistantPaneStateCopyWithImpl(this._self, this._then);

  final AssistantPaneState _self;
  final $Res Function(AssistantPaneState) _then;

/// Create a copy of AssistantPaneState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isOpen = null,Object? width = null,}) {
  return _then(_self.copyWith(
isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantPaneState].
extension AssistantPaneStatePatterns on AssistantPaneState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantPaneState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantPaneState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantPaneState value)  $default,){
final _that = this;
switch (_that) {
case _AssistantPaneState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantPaneState value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantPaneState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isOpen,  double width)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantPaneState() when $default != null:
return $default(_that.isOpen,_that.width);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isOpen,  double width)  $default,) {final _that = this;
switch (_that) {
case _AssistantPaneState():
return $default(_that.isOpen,_that.width);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isOpen,  double width)?  $default,) {final _that = this;
switch (_that) {
case _AssistantPaneState() when $default != null:
return $default(_that.isOpen,_that.width);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantPaneState implements AssistantPaneState {
  const _AssistantPaneState({this.isOpen = false, this.width = 320});
  

@override@JsonKey() final  bool isOpen;
@override@JsonKey() final  double width;

/// Create a copy of AssistantPaneState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantPaneStateCopyWith<_AssistantPaneState> get copyWith => __$AssistantPaneStateCopyWithImpl<_AssistantPaneState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantPaneState&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,isOpen,width);

@override
String toString() {
  return 'AssistantPaneState(isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class _$AssistantPaneStateCopyWith<$Res> implements $AssistantPaneStateCopyWith<$Res> {
  factory _$AssistantPaneStateCopyWith(_AssistantPaneState value, $Res Function(_AssistantPaneState) _then) = __$AssistantPaneStateCopyWithImpl;
@override @useResult
$Res call({
 bool isOpen, double width
});




}
/// @nodoc
class __$AssistantPaneStateCopyWithImpl<$Res>
    implements _$AssistantPaneStateCopyWith<$Res> {
  __$AssistantPaneStateCopyWithImpl(this._self, this._then);

  final _AssistantPaneState _self;
  final $Res Function(_AssistantPaneState) _then;

/// Create a copy of AssistantPaneState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isOpen = null,Object? width = null,}) {
  return _then(_AssistantPaneState(
isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
