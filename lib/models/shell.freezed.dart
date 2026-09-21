// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shell.dart';

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
  const _SidebarModel({this.viewId = 'layers', this.isOpen = true, this.width = 240});
  

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

/// @nodoc
mixin _$CommandPaneModel {

 double get height; bool get isExpanded;
/// Create a copy of CommandPaneModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandPaneModelCopyWith<CommandPaneModel> get copyWith => _$CommandPaneModelCopyWithImpl<CommandPaneModel>(this as CommandPaneModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandPaneModel&&(identical(other.height, height) || other.height == height)&&(identical(other.isExpanded, isExpanded) || other.isExpanded == isExpanded));
}


@override
int get hashCode => Object.hash(runtimeType,height,isExpanded);

@override
String toString() {
  return 'CommandPaneModel(height: $height, isExpanded: $isExpanded)';
}


}

/// @nodoc
abstract mixin class $CommandPaneModelCopyWith<$Res>  {
  factory $CommandPaneModelCopyWith(CommandPaneModel value, $Res Function(CommandPaneModel) _then) = _$CommandPaneModelCopyWithImpl;
@useResult
$Res call({
 double height, bool isExpanded
});




}
/// @nodoc
class _$CommandPaneModelCopyWithImpl<$Res>
    implements $CommandPaneModelCopyWith<$Res> {
  _$CommandPaneModelCopyWithImpl(this._self, this._then);

  final CommandPaneModel _self;
  final $Res Function(CommandPaneModel) _then;

/// Create a copy of CommandPaneModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? height = null,Object? isExpanded = null,}) {
  return _then(_self.copyWith(
height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,isExpanded: null == isExpanded ? _self.isExpanded : isExpanded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CommandPaneModel].
extension CommandPaneModelPatterns on CommandPaneModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandPaneModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandPaneModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandPaneModel value)  $default,){
final _that = this;
switch (_that) {
case _CommandPaneModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandPaneModel value)?  $default,){
final _that = this;
switch (_that) {
case _CommandPaneModel() when $default != null:
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
case _CommandPaneModel() when $default != null:
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
case _CommandPaneModel():
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
case _CommandPaneModel() when $default != null:
return $default(_that.height,_that.isExpanded);case _:
  return null;

}
}

}

/// @nodoc


class _CommandPaneModel implements CommandPaneModel {
  const _CommandPaneModel({this.height = 84, this.isExpanded = false});
  

@override@JsonKey() final  double height;
@override@JsonKey() final  bool isExpanded;

/// Create a copy of CommandPaneModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandPaneModelCopyWith<_CommandPaneModel> get copyWith => __$CommandPaneModelCopyWithImpl<_CommandPaneModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandPaneModel&&(identical(other.height, height) || other.height == height)&&(identical(other.isExpanded, isExpanded) || other.isExpanded == isExpanded));
}


@override
int get hashCode => Object.hash(runtimeType,height,isExpanded);

@override
String toString() {
  return 'CommandPaneModel(height: $height, isExpanded: $isExpanded)';
}


}

/// @nodoc
abstract mixin class _$CommandPaneModelCopyWith<$Res> implements $CommandPaneModelCopyWith<$Res> {
  factory _$CommandPaneModelCopyWith(_CommandPaneModel value, $Res Function(_CommandPaneModel) _then) = __$CommandPaneModelCopyWithImpl;
@override @useResult
$Res call({
 double height, bool isExpanded
});




}
/// @nodoc
class __$CommandPaneModelCopyWithImpl<$Res>
    implements _$CommandPaneModelCopyWith<$Res> {
  __$CommandPaneModelCopyWithImpl(this._self, this._then);

  final _CommandPaneModel _self;
  final $Res Function(_CommandPaneModel) _then;

/// Create a copy of CommandPaneModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? height = null,Object? isExpanded = null,}) {
  return _then(_CommandPaneModel(
height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,isExpanded: null == isExpanded ? _self.isExpanded : isExpanded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$AssistantPaneModel {

 bool get isOpen; double get width;
/// Create a copy of AssistantPaneModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantPaneModelCopyWith<AssistantPaneModel> get copyWith => _$AssistantPaneModelCopyWithImpl<AssistantPaneModel>(this as AssistantPaneModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantPaneModel&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,isOpen,width);

@override
String toString() {
  return 'AssistantPaneModel(isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class $AssistantPaneModelCopyWith<$Res>  {
  factory $AssistantPaneModelCopyWith(AssistantPaneModel value, $Res Function(AssistantPaneModel) _then) = _$AssistantPaneModelCopyWithImpl;
@useResult
$Res call({
 bool isOpen, double width
});




}
/// @nodoc
class _$AssistantPaneModelCopyWithImpl<$Res>
    implements $AssistantPaneModelCopyWith<$Res> {
  _$AssistantPaneModelCopyWithImpl(this._self, this._then);

  final AssistantPaneModel _self;
  final $Res Function(AssistantPaneModel) _then;

/// Create a copy of AssistantPaneModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isOpen = null,Object? width = null,}) {
  return _then(_self.copyWith(
isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantPaneModel].
extension AssistantPaneModelPatterns on AssistantPaneModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantPaneModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantPaneModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantPaneModel value)  $default,){
final _that = this;
switch (_that) {
case _AssistantPaneModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantPaneModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantPaneModel() when $default != null:
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
case _AssistantPaneModel() when $default != null:
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
case _AssistantPaneModel():
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
case _AssistantPaneModel() when $default != null:
return $default(_that.isOpen,_that.width);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantPaneModel implements AssistantPaneModel {
  const _AssistantPaneModel({this.isOpen = false, this.width = 320});
  

@override@JsonKey() final  bool isOpen;
@override@JsonKey() final  double width;

/// Create a copy of AssistantPaneModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantPaneModelCopyWith<_AssistantPaneModel> get copyWith => __$AssistantPaneModelCopyWithImpl<_AssistantPaneModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantPaneModel&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.width, width) || other.width == width));
}


@override
int get hashCode => Object.hash(runtimeType,isOpen,width);

@override
String toString() {
  return 'AssistantPaneModel(isOpen: $isOpen, width: $width)';
}


}

/// @nodoc
abstract mixin class _$AssistantPaneModelCopyWith<$Res> implements $AssistantPaneModelCopyWith<$Res> {
  factory _$AssistantPaneModelCopyWith(_AssistantPaneModel value, $Res Function(_AssistantPaneModel) _then) = __$AssistantPaneModelCopyWithImpl;
@override @useResult
$Res call({
 bool isOpen, double width
});




}
/// @nodoc
class __$AssistantPaneModelCopyWithImpl<$Res>
    implements _$AssistantPaneModelCopyWith<$Res> {
  __$AssistantPaneModelCopyWithImpl(this._self, this._then);

  final _AssistantPaneModel _self;
  final $Res Function(_AssistantPaneModel) _then;

/// Create a copy of AssistantPaneModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isOpen = null,Object? width = null,}) {
  return _then(_AssistantPaneModel(
isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$ShellModel {

 SidebarModel get sidebar; CommandPaneModel get commandPane; AssistantPaneModel get assistant; ThemePreference get theme; String get language; bool get paletteOpen;
/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShellModelCopyWith<ShellModel> get copyWith => _$ShellModelCopyWithImpl<ShellModel>(this as ShellModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShellModel&&(identical(other.sidebar, sidebar) || other.sidebar == sidebar)&&(identical(other.commandPane, commandPane) || other.commandPane == commandPane)&&(identical(other.assistant, assistant) || other.assistant == assistant)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language)&&(identical(other.paletteOpen, paletteOpen) || other.paletteOpen == paletteOpen));
}


@override
int get hashCode => Object.hash(runtimeType,sidebar,commandPane,assistant,theme,language,paletteOpen);

@override
String toString() {
  return 'ShellModel(sidebar: $sidebar, commandPane: $commandPane, assistant: $assistant, theme: $theme, language: $language, paletteOpen: $paletteOpen)';
}


}

/// @nodoc
abstract mixin class $ShellModelCopyWith<$Res>  {
  factory $ShellModelCopyWith(ShellModel value, $Res Function(ShellModel) _then) = _$ShellModelCopyWithImpl;
@useResult
$Res call({
 SidebarModel sidebar, CommandPaneModel commandPane, AssistantPaneModel assistant, ThemePreference theme, String language, bool paletteOpen
});


$SidebarModelCopyWith<$Res> get sidebar;$CommandPaneModelCopyWith<$Res> get commandPane;$AssistantPaneModelCopyWith<$Res> get assistant;

}
/// @nodoc
class _$ShellModelCopyWithImpl<$Res>
    implements $ShellModelCopyWith<$Res> {
  _$ShellModelCopyWithImpl(this._self, this._then);

  final ShellModel _self;
  final $Res Function(ShellModel) _then;

/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sidebar = null,Object? commandPane = null,Object? assistant = null,Object? theme = null,Object? language = null,Object? paletteOpen = null,}) {
  return _then(_self.copyWith(
sidebar: null == sidebar ? _self.sidebar : sidebar // ignore: cast_nullable_to_non_nullable
as SidebarModel,commandPane: null == commandPane ? _self.commandPane : commandPane // ignore: cast_nullable_to_non_nullable
as CommandPaneModel,assistant: null == assistant ? _self.assistant : assistant // ignore: cast_nullable_to_non_nullable
as AssistantPaneModel,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,paletteOpen: null == paletteOpen ? _self.paletteOpen : paletteOpen // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SidebarModelCopyWith<$Res> get sidebar {
  
  return $SidebarModelCopyWith<$Res>(_self.sidebar, (value) {
    return _then(_self.copyWith(sidebar: value));
  });
}/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandPaneModelCopyWith<$Res> get commandPane {
  
  return $CommandPaneModelCopyWith<$Res>(_self.commandPane, (value) {
    return _then(_self.copyWith(commandPane: value));
  });
}/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantPaneModelCopyWith<$Res> get assistant {
  
  return $AssistantPaneModelCopyWith<$Res>(_self.assistant, (value) {
    return _then(_self.copyWith(assistant: value));
  });
}
}


/// Adds pattern-matching-related methods to [ShellModel].
extension ShellModelPatterns on ShellModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShellModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShellModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShellModel value)  $default,){
final _that = this;
switch (_that) {
case _ShellModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShellModel value)?  $default,){
final _that = this;
switch (_that) {
case _ShellModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SidebarModel sidebar,  CommandPaneModel commandPane,  AssistantPaneModel assistant,  ThemePreference theme,  String language,  bool paletteOpen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShellModel() when $default != null:
return $default(_that.sidebar,_that.commandPane,_that.assistant,_that.theme,_that.language,_that.paletteOpen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SidebarModel sidebar,  CommandPaneModel commandPane,  AssistantPaneModel assistant,  ThemePreference theme,  String language,  bool paletteOpen)  $default,) {final _that = this;
switch (_that) {
case _ShellModel():
return $default(_that.sidebar,_that.commandPane,_that.assistant,_that.theme,_that.language,_that.paletteOpen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SidebarModel sidebar,  CommandPaneModel commandPane,  AssistantPaneModel assistant,  ThemePreference theme,  String language,  bool paletteOpen)?  $default,) {final _that = this;
switch (_that) {
case _ShellModel() when $default != null:
return $default(_that.sidebar,_that.commandPane,_that.assistant,_that.theme,_that.language,_that.paletteOpen);case _:
  return null;

}
}

}

/// @nodoc


class _ShellModel implements ShellModel {
  const _ShellModel({this.sidebar = const SidebarModel(), this.commandPane = const CommandPaneModel(), this.assistant = const AssistantPaneModel(), this.theme = ThemePreference.fallback, this.language = FanCadLanguage.english, this.paletteOpen = false});
  

@override@JsonKey() final  SidebarModel sidebar;
@override@JsonKey() final  CommandPaneModel commandPane;
@override@JsonKey() final  AssistantPaneModel assistant;
@override@JsonKey() final  ThemePreference theme;
@override@JsonKey() final  String language;
@override@JsonKey() final  bool paletteOpen;

/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShellModelCopyWith<_ShellModel> get copyWith => __$ShellModelCopyWithImpl<_ShellModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShellModel&&(identical(other.sidebar, sidebar) || other.sidebar == sidebar)&&(identical(other.commandPane, commandPane) || other.commandPane == commandPane)&&(identical(other.assistant, assistant) || other.assistant == assistant)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language)&&(identical(other.paletteOpen, paletteOpen) || other.paletteOpen == paletteOpen));
}


@override
int get hashCode => Object.hash(runtimeType,sidebar,commandPane,assistant,theme,language,paletteOpen);

@override
String toString() {
  return 'ShellModel(sidebar: $sidebar, commandPane: $commandPane, assistant: $assistant, theme: $theme, language: $language, paletteOpen: $paletteOpen)';
}


}

/// @nodoc
abstract mixin class _$ShellModelCopyWith<$Res> implements $ShellModelCopyWith<$Res> {
  factory _$ShellModelCopyWith(_ShellModel value, $Res Function(_ShellModel) _then) = __$ShellModelCopyWithImpl;
@override @useResult
$Res call({
 SidebarModel sidebar, CommandPaneModel commandPane, AssistantPaneModel assistant, ThemePreference theme, String language, bool paletteOpen
});


@override $SidebarModelCopyWith<$Res> get sidebar;@override $CommandPaneModelCopyWith<$Res> get commandPane;@override $AssistantPaneModelCopyWith<$Res> get assistant;

}
/// @nodoc
class __$ShellModelCopyWithImpl<$Res>
    implements _$ShellModelCopyWith<$Res> {
  __$ShellModelCopyWithImpl(this._self, this._then);

  final _ShellModel _self;
  final $Res Function(_ShellModel) _then;

/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sidebar = null,Object? commandPane = null,Object? assistant = null,Object? theme = null,Object? language = null,Object? paletteOpen = null,}) {
  return _then(_ShellModel(
sidebar: null == sidebar ? _self.sidebar : sidebar // ignore: cast_nullable_to_non_nullable
as SidebarModel,commandPane: null == commandPane ? _self.commandPane : commandPane // ignore: cast_nullable_to_non_nullable
as CommandPaneModel,assistant: null == assistant ? _self.assistant : assistant // ignore: cast_nullable_to_non_nullable
as AssistantPaneModel,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,paletteOpen: null == paletteOpen ? _self.paletteOpen : paletteOpen // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SidebarModelCopyWith<$Res> get sidebar {
  
  return $SidebarModelCopyWith<$Res>(_self.sidebar, (value) {
    return _then(_self.copyWith(sidebar: value));
  });
}/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandPaneModelCopyWith<$Res> get commandPane {
  
  return $CommandPaneModelCopyWith<$Res>(_self.commandPane, (value) {
    return _then(_self.copyWith(commandPane: value));
  });
}/// Create a copy of ShellModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantPaneModelCopyWith<$Res> get assistant {
  
  return $AssistantPaneModelCopyWith<$Res>(_self.assistant, (value) {
    return _then(_self.copyWith(assistant: value));
  });
}
}

// dart format on
