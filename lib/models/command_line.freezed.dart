// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command_line.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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
  const _CommandPaneModel({this.height = CommandLineLayout.defaultHeight, this.isExpanded = false});
  

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
mixin _$CommandLineModel {

 List<HistoryLineModel> get lines; CommandPromptModel? get prompt; String get status; String? get offeredInput; List<String> get entered; CommandPaneModel get pane; bool get paletteOpen;
/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandLineModelCopyWith<CommandLineModel> get copyWith => _$CommandLineModelCopyWithImpl<CommandLineModel>(this as CommandLineModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandLineModel&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.status, status) || other.status == status)&&(identical(other.offeredInput, offeredInput) || other.offeredInput == offeredInput)&&const DeepCollectionEquality().equals(other.entered, entered)&&(identical(other.pane, pane) || other.pane == pane)&&(identical(other.paletteOpen, paletteOpen) || other.paletteOpen == paletteOpen));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(lines),prompt,status,offeredInput,const DeepCollectionEquality().hash(entered),pane,paletteOpen);

@override
String toString() {
  return 'CommandLineModel(lines: $lines, prompt: $prompt, status: $status, offeredInput: $offeredInput, entered: $entered, pane: $pane, paletteOpen: $paletteOpen)';
}


}

/// @nodoc
abstract mixin class $CommandLineModelCopyWith<$Res>  {
  factory $CommandLineModelCopyWith(CommandLineModel value, $Res Function(CommandLineModel) _then) = _$CommandLineModelCopyWithImpl;
@useResult
$Res call({
 List<HistoryLineModel> lines, CommandPromptModel? prompt, String status, String? offeredInput, List<String> entered, CommandPaneModel pane, bool paletteOpen
});


$CommandPromptModelCopyWith<$Res>? get prompt;$CommandPaneModelCopyWith<$Res> get pane;

}
/// @nodoc
class _$CommandLineModelCopyWithImpl<$Res>
    implements $CommandLineModelCopyWith<$Res> {
  _$CommandLineModelCopyWithImpl(this._self, this._then);

  final CommandLineModel _self;
  final $Res Function(CommandLineModel) _then;

/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lines = null,Object? prompt = freezed,Object? status = null,Object? offeredInput = freezed,Object? entered = null,Object? pane = null,Object? paletteOpen = null,}) {
  return _then(_self.copyWith(
lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<HistoryLineModel>,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as CommandPromptModel?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,offeredInput: freezed == offeredInput ? _self.offeredInput : offeredInput // ignore: cast_nullable_to_non_nullable
as String?,entered: null == entered ? _self.entered : entered // ignore: cast_nullable_to_non_nullable
as List<String>,pane: null == pane ? _self.pane : pane // ignore: cast_nullable_to_non_nullable
as CommandPaneModel,paletteOpen: null == paletteOpen ? _self.paletteOpen : paletteOpen // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandPromptModelCopyWith<$Res>? get prompt {
    if (_self.prompt == null) {
    return null;
  }

  return $CommandPromptModelCopyWith<$Res>(_self.prompt!, (value) {
    return _then(_self.copyWith(prompt: value));
  });
}/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandPaneModelCopyWith<$Res> get pane {
  
  return $CommandPaneModelCopyWith<$Res>(_self.pane, (value) {
    return _then(_self.copyWith(pane: value));
  });
}
}


/// Adds pattern-matching-related methods to [CommandLineModel].
extension CommandLineModelPatterns on CommandLineModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandLineModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandLineModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandLineModel value)  $default,){
final _that = this;
switch (_that) {
case _CommandLineModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandLineModel value)?  $default,){
final _that = this;
switch (_that) {
case _CommandLineModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<HistoryLineModel> lines,  CommandPromptModel? prompt,  String status,  String? offeredInput,  List<String> entered,  CommandPaneModel pane,  bool paletteOpen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandLineModel() when $default != null:
return $default(_that.lines,_that.prompt,_that.status,_that.offeredInput,_that.entered,_that.pane,_that.paletteOpen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<HistoryLineModel> lines,  CommandPromptModel? prompt,  String status,  String? offeredInput,  List<String> entered,  CommandPaneModel pane,  bool paletteOpen)  $default,) {final _that = this;
switch (_that) {
case _CommandLineModel():
return $default(_that.lines,_that.prompt,_that.status,_that.offeredInput,_that.entered,_that.pane,_that.paletteOpen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<HistoryLineModel> lines,  CommandPromptModel? prompt,  String status,  String? offeredInput,  List<String> entered,  CommandPaneModel pane,  bool paletteOpen)?  $default,) {final _that = this;
switch (_that) {
case _CommandLineModel() when $default != null:
return $default(_that.lines,_that.prompt,_that.status,_that.offeredInput,_that.entered,_that.pane,_that.paletteOpen);case _:
  return null;

}
}

}

/// @nodoc


class _CommandLineModel implements CommandLineModel {
  const _CommandLineModel({final  List<HistoryLineModel> lines = const [], this.prompt, this.status = '', this.offeredInput, final  List<String> entered = const [], this.pane = const CommandPaneModel(), this.paletteOpen = false}): _lines = lines,_entered = entered;
  

 final  List<HistoryLineModel> _lines;
@override@JsonKey() List<HistoryLineModel> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override final  CommandPromptModel? prompt;
@override@JsonKey() final  String status;
@override final  String? offeredInput;
 final  List<String> _entered;
@override@JsonKey() List<String> get entered {
  if (_entered is EqualUnmodifiableListView) return _entered;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entered);
}

@override@JsonKey() final  CommandPaneModel pane;
@override@JsonKey() final  bool paletteOpen;

/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandLineModelCopyWith<_CommandLineModel> get copyWith => __$CommandLineModelCopyWithImpl<_CommandLineModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandLineModel&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.status, status) || other.status == status)&&(identical(other.offeredInput, offeredInput) || other.offeredInput == offeredInput)&&const DeepCollectionEquality().equals(other._entered, _entered)&&(identical(other.pane, pane) || other.pane == pane)&&(identical(other.paletteOpen, paletteOpen) || other.paletteOpen == paletteOpen));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_lines),prompt,status,offeredInput,const DeepCollectionEquality().hash(_entered),pane,paletteOpen);

@override
String toString() {
  return 'CommandLineModel(lines: $lines, prompt: $prompt, status: $status, offeredInput: $offeredInput, entered: $entered, pane: $pane, paletteOpen: $paletteOpen)';
}


}

/// @nodoc
abstract mixin class _$CommandLineModelCopyWith<$Res> implements $CommandLineModelCopyWith<$Res> {
  factory _$CommandLineModelCopyWith(_CommandLineModel value, $Res Function(_CommandLineModel) _then) = __$CommandLineModelCopyWithImpl;
@override @useResult
$Res call({
 List<HistoryLineModel> lines, CommandPromptModel? prompt, String status, String? offeredInput, List<String> entered, CommandPaneModel pane, bool paletteOpen
});


@override $CommandPromptModelCopyWith<$Res>? get prompt;@override $CommandPaneModelCopyWith<$Res> get pane;

}
/// @nodoc
class __$CommandLineModelCopyWithImpl<$Res>
    implements _$CommandLineModelCopyWith<$Res> {
  __$CommandLineModelCopyWithImpl(this._self, this._then);

  final _CommandLineModel _self;
  final $Res Function(_CommandLineModel) _then;

/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lines = null,Object? prompt = freezed,Object? status = null,Object? offeredInput = freezed,Object? entered = null,Object? pane = null,Object? paletteOpen = null,}) {
  return _then(_CommandLineModel(
lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<HistoryLineModel>,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as CommandPromptModel?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,offeredInput: freezed == offeredInput ? _self.offeredInput : offeredInput // ignore: cast_nullable_to_non_nullable
as String?,entered: null == entered ? _self._entered : entered // ignore: cast_nullable_to_non_nullable
as List<String>,pane: null == pane ? _self.pane : pane // ignore: cast_nullable_to_non_nullable
as CommandPaneModel,paletteOpen: null == paletteOpen ? _self.paletteOpen : paletteOpen // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandPromptModelCopyWith<$Res>? get prompt {
    if (_self.prompt == null) {
    return null;
  }

  return $CommandPromptModelCopyWith<$Res>(_self.prompt!, (value) {
    return _then(_self.copyWith(prompt: value));
  });
}/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandPaneModelCopyWith<$Res> get pane {
  
  return $CommandPaneModelCopyWith<$Res>(_self.pane, (value) {
    return _then(_self.copyWith(pane: value));
  });
}
}

/// @nodoc
mixin _$HistoryLineModel {

 String get text; HistoryLevel get level;
/// Create a copy of HistoryLineModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HistoryLineModelCopyWith<HistoryLineModel> get copyWith => _$HistoryLineModelCopyWithImpl<HistoryLineModel>(this as HistoryLineModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryLineModel&&(identical(other.text, text) || other.text == text)&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode => Object.hash(runtimeType,text,level);

@override
String toString() {
  return 'HistoryLineModel(text: $text, level: $level)';
}


}

/// @nodoc
abstract mixin class $HistoryLineModelCopyWith<$Res>  {
  factory $HistoryLineModelCopyWith(HistoryLineModel value, $Res Function(HistoryLineModel) _then) = _$HistoryLineModelCopyWithImpl;
@useResult
$Res call({
 String text, HistoryLevel level
});




}
/// @nodoc
class _$HistoryLineModelCopyWithImpl<$Res>
    implements $HistoryLineModelCopyWith<$Res> {
  _$HistoryLineModelCopyWithImpl(this._self, this._then);

  final HistoryLineModel _self;
  final $Res Function(HistoryLineModel) _then;

/// Create a copy of HistoryLineModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? level = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as HistoryLevel,
  ));
}

}


/// Adds pattern-matching-related methods to [HistoryLineModel].
extension HistoryLineModelPatterns on HistoryLineModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HistoryLineModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HistoryLineModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HistoryLineModel value)  $default,){
final _that = this;
switch (_that) {
case _HistoryLineModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HistoryLineModel value)?  $default,){
final _that = this;
switch (_that) {
case _HistoryLineModel() when $default != null:
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
case _HistoryLineModel() when $default != null:
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
case _HistoryLineModel():
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
case _HistoryLineModel() when $default != null:
return $default(_that.text,_that.level);case _:
  return null;

}
}

}

/// @nodoc


class _HistoryLineModel implements HistoryLineModel {
  const _HistoryLineModel(this.text, {this.level = HistoryLevel.normal});
  

@override final  String text;
@override@JsonKey() final  HistoryLevel level;

/// Create a copy of HistoryLineModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryLineModelCopyWith<_HistoryLineModel> get copyWith => __$HistoryLineModelCopyWithImpl<_HistoryLineModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryLineModel&&(identical(other.text, text) || other.text == text)&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode => Object.hash(runtimeType,text,level);

@override
String toString() {
  return 'HistoryLineModel(text: $text, level: $level)';
}


}

/// @nodoc
abstract mixin class _$HistoryLineModelCopyWith<$Res> implements $HistoryLineModelCopyWith<$Res> {
  factory _$HistoryLineModelCopyWith(_HistoryLineModel value, $Res Function(_HistoryLineModel) _then) = __$HistoryLineModelCopyWithImpl;
@override @useResult
$Res call({
 String text, HistoryLevel level
});




}
/// @nodoc
class __$HistoryLineModelCopyWithImpl<$Res>
    implements _$HistoryLineModelCopyWith<$Res> {
  __$HistoryLineModelCopyWithImpl(this._self, this._then);

  final _HistoryLineModel _self;
  final $Res Function(_HistoryLineModel) _then;

/// Create a copy of HistoryLineModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? level = null,}) {
  return _then(_HistoryLineModel(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as HistoryLevel,
  ));
}


}

/// @nodoc
mixin _$CommandPromptModel {

 String get message; List<String> get keywords; bool get allowEmpty;
/// Create a copy of CommandPromptModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandPromptModelCopyWith<CommandPromptModel> get copyWith => _$CommandPromptModelCopyWithImpl<CommandPromptModel>(this as CommandPromptModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandPromptModel&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.keywords, keywords)&&(identical(other.allowEmpty, allowEmpty) || other.allowEmpty == allowEmpty));
}


@override
int get hashCode => Object.hash(runtimeType,message,const DeepCollectionEquality().hash(keywords),allowEmpty);

@override
String toString() {
  return 'CommandPromptModel(message: $message, keywords: $keywords, allowEmpty: $allowEmpty)';
}


}

/// @nodoc
abstract mixin class $CommandPromptModelCopyWith<$Res>  {
  factory $CommandPromptModelCopyWith(CommandPromptModel value, $Res Function(CommandPromptModel) _then) = _$CommandPromptModelCopyWithImpl;
@useResult
$Res call({
 String message, List<String> keywords, bool allowEmpty
});




}
/// @nodoc
class _$CommandPromptModelCopyWithImpl<$Res>
    implements $CommandPromptModelCopyWith<$Res> {
  _$CommandPromptModelCopyWithImpl(this._self, this._then);

  final CommandPromptModel _self;
  final $Res Function(CommandPromptModel) _then;

/// Create a copy of CommandPromptModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? keywords = null,Object? allowEmpty = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,keywords: null == keywords ? _self.keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,allowEmpty: null == allowEmpty ? _self.allowEmpty : allowEmpty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CommandPromptModel].
extension CommandPromptModelPatterns on CommandPromptModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandPromptModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandPromptModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandPromptModel value)  $default,){
final _that = this;
switch (_that) {
case _CommandPromptModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandPromptModel value)?  $default,){
final _that = this;
switch (_that) {
case _CommandPromptModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  List<String> keywords,  bool allowEmpty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandPromptModel() when $default != null:
return $default(_that.message,_that.keywords,_that.allowEmpty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  List<String> keywords,  bool allowEmpty)  $default,) {final _that = this;
switch (_that) {
case _CommandPromptModel():
return $default(_that.message,_that.keywords,_that.allowEmpty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  List<String> keywords,  bool allowEmpty)?  $default,) {final _that = this;
switch (_that) {
case _CommandPromptModel() when $default != null:
return $default(_that.message,_that.keywords,_that.allowEmpty);case _:
  return null;

}
}

}

/// @nodoc


class _CommandPromptModel implements CommandPromptModel {
  const _CommandPromptModel({required this.message, final  List<String> keywords = const [], this.allowEmpty = false}): _keywords = keywords;
  

@override final  String message;
 final  List<String> _keywords;
@override@JsonKey() List<String> get keywords {
  if (_keywords is EqualUnmodifiableListView) return _keywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keywords);
}

@override@JsonKey() final  bool allowEmpty;

/// Create a copy of CommandPromptModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandPromptModelCopyWith<_CommandPromptModel> get copyWith => __$CommandPromptModelCopyWithImpl<_CommandPromptModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandPromptModel&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other._keywords, _keywords)&&(identical(other.allowEmpty, allowEmpty) || other.allowEmpty == allowEmpty));
}


@override
int get hashCode => Object.hash(runtimeType,message,const DeepCollectionEquality().hash(_keywords),allowEmpty);

@override
String toString() {
  return 'CommandPromptModel(message: $message, keywords: $keywords, allowEmpty: $allowEmpty)';
}


}

/// @nodoc
abstract mixin class _$CommandPromptModelCopyWith<$Res> implements $CommandPromptModelCopyWith<$Res> {
  factory _$CommandPromptModelCopyWith(_CommandPromptModel value, $Res Function(_CommandPromptModel) _then) = __$CommandPromptModelCopyWithImpl;
@override @useResult
$Res call({
 String message, List<String> keywords, bool allowEmpty
});




}
/// @nodoc
class __$CommandPromptModelCopyWithImpl<$Res>
    implements _$CommandPromptModelCopyWith<$Res> {
  __$CommandPromptModelCopyWithImpl(this._self, this._then);

  final _CommandPromptModel _self;
  final $Res Function(_CommandPromptModel) _then;

/// Create a copy of CommandPromptModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? keywords = null,Object? allowEmpty = null,}) {
  return _then(_CommandPromptModel(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,keywords: null == keywords ? _self._keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,allowEmpty: null == allowEmpty ? _self.allowEmpty : allowEmpty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
