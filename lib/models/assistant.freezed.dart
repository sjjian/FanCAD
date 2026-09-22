// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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
  const _AssistantPaneModel({this.isOpen = false, this.width = AssistantPaneLayout.defaultWidth});
  

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
mixin _$AssistantModel {

 List<AssistantChatModel> get chats; String get activeChatId; List<ComposerPinModel> get pins; String? get error; PendingChangeSet? get approval; SessionQuestion? get question; bool get busy; int get transcriptEpoch; AssistantPaneModel get pane;
/// Create a copy of AssistantModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantModelCopyWith<AssistantModel> get copyWith => _$AssistantModelCopyWithImpl<AssistantModel>(this as AssistantModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantModel&&const DeepCollectionEquality().equals(other.chats, chats)&&(identical(other.activeChatId, activeChatId) || other.activeChatId == activeChatId)&&const DeepCollectionEquality().equals(other.pins, pins)&&(identical(other.error, error) || other.error == error)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.question, question) || other.question == question)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.transcriptEpoch, transcriptEpoch) || other.transcriptEpoch == transcriptEpoch)&&(identical(other.pane, pane) || other.pane == pane));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(chats),activeChatId,const DeepCollectionEquality().hash(pins),error,approval,question,busy,transcriptEpoch,pane);

@override
String toString() {
  return 'AssistantModel(chats: $chats, activeChatId: $activeChatId, pins: $pins, error: $error, approval: $approval, question: $question, busy: $busy, transcriptEpoch: $transcriptEpoch, pane: $pane)';
}


}

/// @nodoc
abstract mixin class $AssistantModelCopyWith<$Res>  {
  factory $AssistantModelCopyWith(AssistantModel value, $Res Function(AssistantModel) _then) = _$AssistantModelCopyWithImpl;
@useResult
$Res call({
 List<AssistantChatModel> chats, String activeChatId, List<ComposerPinModel> pins, String? error, PendingChangeSet? approval, SessionQuestion? question, bool busy, int transcriptEpoch, AssistantPaneModel pane
});


$AssistantPaneModelCopyWith<$Res> get pane;

}
/// @nodoc
class _$AssistantModelCopyWithImpl<$Res>
    implements $AssistantModelCopyWith<$Res> {
  _$AssistantModelCopyWithImpl(this._self, this._then);

  final AssistantModel _self;
  final $Res Function(AssistantModel) _then;

/// Create a copy of AssistantModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chats = null,Object? activeChatId = null,Object? pins = null,Object? error = freezed,Object? approval = freezed,Object? question = freezed,Object? busy = null,Object? transcriptEpoch = null,Object? pane = null,}) {
  return _then(_self.copyWith(
chats: null == chats ? _self.chats : chats // ignore: cast_nullable_to_non_nullable
as List<AssistantChatModel>,activeChatId: null == activeChatId ? _self.activeChatId : activeChatId // ignore: cast_nullable_to_non_nullable
as String,pins: null == pins ? _self.pins : pins // ignore: cast_nullable_to_non_nullable
as List<ComposerPinModel>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,approval: freezed == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as PendingChangeSet?,question: freezed == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as SessionQuestion?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,transcriptEpoch: null == transcriptEpoch ? _self.transcriptEpoch : transcriptEpoch // ignore: cast_nullable_to_non_nullable
as int,pane: null == pane ? _self.pane : pane // ignore: cast_nullable_to_non_nullable
as AssistantPaneModel,
  ));
}
/// Create a copy of AssistantModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantPaneModelCopyWith<$Res> get pane {
  
  return $AssistantPaneModelCopyWith<$Res>(_self.pane, (value) {
    return _then(_self.copyWith(pane: value));
  });
}
}


/// Adds pattern-matching-related methods to [AssistantModel].
extension AssistantModelPatterns on AssistantModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantModel value)  $default,){
final _that = this;
switch (_that) {
case _AssistantModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AssistantChatModel> chats,  String activeChatId,  List<ComposerPinModel> pins,  String? error,  PendingChangeSet? approval,  SessionQuestion? question,  bool busy,  int transcriptEpoch,  AssistantPaneModel pane)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantModel() when $default != null:
return $default(_that.chats,_that.activeChatId,_that.pins,_that.error,_that.approval,_that.question,_that.busy,_that.transcriptEpoch,_that.pane);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AssistantChatModel> chats,  String activeChatId,  List<ComposerPinModel> pins,  String? error,  PendingChangeSet? approval,  SessionQuestion? question,  bool busy,  int transcriptEpoch,  AssistantPaneModel pane)  $default,) {final _that = this;
switch (_that) {
case _AssistantModel():
return $default(_that.chats,_that.activeChatId,_that.pins,_that.error,_that.approval,_that.question,_that.busy,_that.transcriptEpoch,_that.pane);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AssistantChatModel> chats,  String activeChatId,  List<ComposerPinModel> pins,  String? error,  PendingChangeSet? approval,  SessionQuestion? question,  bool busy,  int transcriptEpoch,  AssistantPaneModel pane)?  $default,) {final _that = this;
switch (_that) {
case _AssistantModel() when $default != null:
return $default(_that.chats,_that.activeChatId,_that.pins,_that.error,_that.approval,_that.question,_that.busy,_that.transcriptEpoch,_that.pane);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantModel extends AssistantModel {
  const _AssistantModel({final  List<AssistantChatModel> chats = const [], this.activeChatId = AssistantChatModel.defaultId, final  List<ComposerPinModel> pins = const [], this.error, this.approval, this.question, this.busy = false, this.transcriptEpoch = 0, this.pane = const AssistantPaneModel()}): _chats = chats,_pins = pins,super._();
  

 final  List<AssistantChatModel> _chats;
@override@JsonKey() List<AssistantChatModel> get chats {
  if (_chats is EqualUnmodifiableListView) return _chats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chats);
}

@override@JsonKey() final  String activeChatId;
 final  List<ComposerPinModel> _pins;
@override@JsonKey() List<ComposerPinModel> get pins {
  if (_pins is EqualUnmodifiableListView) return _pins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pins);
}

@override final  String? error;
@override final  PendingChangeSet? approval;
@override final  SessionQuestion? question;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  int transcriptEpoch;
@override@JsonKey() final  AssistantPaneModel pane;

/// Create a copy of AssistantModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantModelCopyWith<_AssistantModel> get copyWith => __$AssistantModelCopyWithImpl<_AssistantModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantModel&&const DeepCollectionEquality().equals(other._chats, _chats)&&(identical(other.activeChatId, activeChatId) || other.activeChatId == activeChatId)&&const DeepCollectionEquality().equals(other._pins, _pins)&&(identical(other.error, error) || other.error == error)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.question, question) || other.question == question)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.transcriptEpoch, transcriptEpoch) || other.transcriptEpoch == transcriptEpoch)&&(identical(other.pane, pane) || other.pane == pane));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_chats),activeChatId,const DeepCollectionEquality().hash(_pins),error,approval,question,busy,transcriptEpoch,pane);

@override
String toString() {
  return 'AssistantModel(chats: $chats, activeChatId: $activeChatId, pins: $pins, error: $error, approval: $approval, question: $question, busy: $busy, transcriptEpoch: $transcriptEpoch, pane: $pane)';
}


}

/// @nodoc
abstract mixin class _$AssistantModelCopyWith<$Res> implements $AssistantModelCopyWith<$Res> {
  factory _$AssistantModelCopyWith(_AssistantModel value, $Res Function(_AssistantModel) _then) = __$AssistantModelCopyWithImpl;
@override @useResult
$Res call({
 List<AssistantChatModel> chats, String activeChatId, List<ComposerPinModel> pins, String? error, PendingChangeSet? approval, SessionQuestion? question, bool busy, int transcriptEpoch, AssistantPaneModel pane
});


@override $AssistantPaneModelCopyWith<$Res> get pane;

}
/// @nodoc
class __$AssistantModelCopyWithImpl<$Res>
    implements _$AssistantModelCopyWith<$Res> {
  __$AssistantModelCopyWithImpl(this._self, this._then);

  final _AssistantModel _self;
  final $Res Function(_AssistantModel) _then;

/// Create a copy of AssistantModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chats = null,Object? activeChatId = null,Object? pins = null,Object? error = freezed,Object? approval = freezed,Object? question = freezed,Object? busy = null,Object? transcriptEpoch = null,Object? pane = null,}) {
  return _then(_AssistantModel(
chats: null == chats ? _self._chats : chats // ignore: cast_nullable_to_non_nullable
as List<AssistantChatModel>,activeChatId: null == activeChatId ? _self.activeChatId : activeChatId // ignore: cast_nullable_to_non_nullable
as String,pins: null == pins ? _self._pins : pins // ignore: cast_nullable_to_non_nullable
as List<ComposerPinModel>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,approval: freezed == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as PendingChangeSet?,question: freezed == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as SessionQuestion?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,transcriptEpoch: null == transcriptEpoch ? _self.transcriptEpoch : transcriptEpoch // ignore: cast_nullable_to_non_nullable
as int,pane: null == pane ? _self.pane : pane // ignore: cast_nullable_to_non_nullable
as AssistantPaneModel,
  ));
}

/// Create a copy of AssistantModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantPaneModelCopyWith<$Res> get pane {
  
  return $AssistantPaneModelCopyWith<$Res>(_self.pane, (value) {
    return _then(_self.copyWith(pane: value));
  });
}
}

/// @nodoc
mixin _$AssistantChatModel {

@JsonKey() String get id;@JsonKey() String get title;@JsonKey() DateTime get updatedAt;@JsonKey(includeToJson: false, includeFromJson: false) Conversation get conversation;@JsonKey(includeToJson: false, includeFromJson: false) LlmUsage? get usage;@JsonKey() String get draft;
/// Create a copy of AssistantChatModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantChatModelCopyWith<AssistantChatModel> get copyWith => _$AssistantChatModelCopyWithImpl<AssistantChatModel>(this as AssistantChatModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantChatModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.conversation, conversation) || other.conversation == conversation)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.draft, draft) || other.draft == draft));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,updatedAt,conversation,usage,draft);

@override
String toString() {
  return 'AssistantChatModel(id: $id, title: $title, updatedAt: $updatedAt, conversation: $conversation, usage: $usage, draft: $draft)';
}


}

/// @nodoc
abstract mixin class $AssistantChatModelCopyWith<$Res>  {
  factory $AssistantChatModelCopyWith(AssistantChatModel value, $Res Function(AssistantChatModel) _then) = _$AssistantChatModelCopyWithImpl;
@useResult
$Res call({
@JsonKey() String id,@JsonKey() String title,@JsonKey() DateTime updatedAt,@JsonKey(includeToJson: false, includeFromJson: false) Conversation conversation,@JsonKey(includeToJson: false, includeFromJson: false) LlmUsage? usage,@JsonKey() String draft
});




}
/// @nodoc
class _$AssistantChatModelCopyWithImpl<$Res>
    implements $AssistantChatModelCopyWith<$Res> {
  _$AssistantChatModelCopyWithImpl(this._self, this._then);

  final AssistantChatModel _self;
  final $Res Function(AssistantChatModel) _then;

/// Create a copy of AssistantChatModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? updatedAt = null,Object? conversation = null,Object? usage = freezed,Object? draft = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,conversation: null == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as Conversation,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as LlmUsage?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantChatModel].
extension AssistantChatModelPatterns on AssistantChatModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _AssistantChatModel value)?  raw,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantChatModel() when raw != null:
return raw(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _AssistantChatModel value)  raw,}){
final _that = this;
switch (_that) {
case _AssistantChatModel():
return raw(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _AssistantChatModel value)?  raw,}){
final _that = this;
switch (_that) {
case _AssistantChatModel() when raw != null:
return raw(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function(@JsonKey()  String id, @JsonKey()  String title, @JsonKey()  DateTime updatedAt, @JsonKey(includeToJson: false, includeFromJson: false)  Conversation conversation, @JsonKey(includeToJson: false, includeFromJson: false)  LlmUsage? usage, @JsonKey()  String draft)?  raw,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantChatModel() when raw != null:
return raw(_that.id,_that.title,_that.updatedAt,_that.conversation,_that.usage,_that.draft);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function(@JsonKey()  String id, @JsonKey()  String title, @JsonKey()  DateTime updatedAt, @JsonKey(includeToJson: false, includeFromJson: false)  Conversation conversation, @JsonKey(includeToJson: false, includeFromJson: false)  LlmUsage? usage, @JsonKey()  String draft)  raw,}) {final _that = this;
switch (_that) {
case _AssistantChatModel():
return raw(_that.id,_that.title,_that.updatedAt,_that.conversation,_that.usage,_that.draft);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function(@JsonKey()  String id, @JsonKey()  String title, @JsonKey()  DateTime updatedAt, @JsonKey(includeToJson: false, includeFromJson: false)  Conversation conversation, @JsonKey(includeToJson: false, includeFromJson: false)  LlmUsage? usage, @JsonKey()  String draft)?  raw,}) {final _that = this;
switch (_that) {
case _AssistantChatModel() when raw != null:
return raw(_that.id,_that.title,_that.updatedAt,_that.conversation,_that.usage,_that.draft);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(createFactory: false, ignoreUnannotated: true)
class _AssistantChatModel extends AssistantChatModel {
  const _AssistantChatModel({@JsonKey() required this.id, @JsonKey() this.title = '', @JsonKey() required this.updatedAt, @JsonKey(includeToJson: false, includeFromJson: false) required this.conversation, @JsonKey(includeToJson: false, includeFromJson: false) this.usage, @JsonKey() this.draft = ''}): super._();
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String title;
@override@JsonKey() final  DateTime updatedAt;
@override@JsonKey(includeToJson: false, includeFromJson: false) final  Conversation conversation;
@override@JsonKey(includeToJson: false, includeFromJson: false) final  LlmUsage? usage;
@override@JsonKey() final  String draft;

/// Create a copy of AssistantChatModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantChatModelCopyWith<_AssistantChatModel> get copyWith => __$AssistantChatModelCopyWithImpl<_AssistantChatModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantChatModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.conversation, conversation) || other.conversation == conversation)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.draft, draft) || other.draft == draft));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,updatedAt,conversation,usage,draft);

@override
String toString() {
  return 'AssistantChatModel.raw(id: $id, title: $title, updatedAt: $updatedAt, conversation: $conversation, usage: $usage, draft: $draft)';
}


}

/// @nodoc
abstract mixin class _$AssistantChatModelCopyWith<$Res> implements $AssistantChatModelCopyWith<$Res> {
  factory _$AssistantChatModelCopyWith(_AssistantChatModel value, $Res Function(_AssistantChatModel) _then) = __$AssistantChatModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey() String id,@JsonKey() String title,@JsonKey() DateTime updatedAt,@JsonKey(includeToJson: false, includeFromJson: false) Conversation conversation,@JsonKey(includeToJson: false, includeFromJson: false) LlmUsage? usage,@JsonKey() String draft
});




}
/// @nodoc
class __$AssistantChatModelCopyWithImpl<$Res>
    implements _$AssistantChatModelCopyWith<$Res> {
  __$AssistantChatModelCopyWithImpl(this._self, this._then);

  final _AssistantChatModel _self;
  final $Res Function(_AssistantChatModel) _then;

/// Create a copy of AssistantChatModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? updatedAt = null,Object? conversation = null,Object? usage = freezed,Object? draft = null,}) {
  return _then(_AssistantChatModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,conversation: null == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as Conversation,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as LlmUsage?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AssistantReceiptModel {

 String get verb; String get summary; String get status; String get raw; String? get toolName; bool get isError; int get count;
/// Create a copy of AssistantReceiptModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantReceiptModelCopyWith<AssistantReceiptModel> get copyWith => _$AssistantReceiptModelCopyWithImpl<AssistantReceiptModel>(this as AssistantReceiptModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantReceiptModel&&(identical(other.verb, verb) || other.verb == verb)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.status, status) || other.status == status)&&(identical(other.raw, raw) || other.raw == raw)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.count, count) || other.count == count));
}


@override
int get hashCode => Object.hash(runtimeType,verb,summary,status,raw,toolName,isError,count);

@override
String toString() {
  return 'AssistantReceiptModel(verb: $verb, summary: $summary, status: $status, raw: $raw, toolName: $toolName, isError: $isError, count: $count)';
}


}

/// @nodoc
abstract mixin class $AssistantReceiptModelCopyWith<$Res>  {
  factory $AssistantReceiptModelCopyWith(AssistantReceiptModel value, $Res Function(AssistantReceiptModel) _then) = _$AssistantReceiptModelCopyWithImpl;
@useResult
$Res call({
 String verb, String summary, String status, String raw, String? toolName, bool isError, int count
});




}
/// @nodoc
class _$AssistantReceiptModelCopyWithImpl<$Res>
    implements $AssistantReceiptModelCopyWith<$Res> {
  _$AssistantReceiptModelCopyWithImpl(this._self, this._then);

  final AssistantReceiptModel _self;
  final $Res Function(AssistantReceiptModel) _then;

/// Create a copy of AssistantReceiptModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? verb = null,Object? summary = null,Object? status = null,Object? raw = null,Object? toolName = freezed,Object? isError = null,Object? count = null,}) {
  return _then(_self.copyWith(
verb: null == verb ? _self.verb : verb // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,raw: null == raw ? _self.raw : raw // ignore: cast_nullable_to_non_nullable
as String,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantReceiptModel].
extension AssistantReceiptModelPatterns on AssistantReceiptModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantReceiptModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantReceiptModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantReceiptModel value)  $default,){
final _that = this;
switch (_that) {
case _AssistantReceiptModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantReceiptModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantReceiptModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String verb,  String summary,  String status,  String raw,  String? toolName,  bool isError,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantReceiptModel() when $default != null:
return $default(_that.verb,_that.summary,_that.status,_that.raw,_that.toolName,_that.isError,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String verb,  String summary,  String status,  String raw,  String? toolName,  bool isError,  int count)  $default,) {final _that = this;
switch (_that) {
case _AssistantReceiptModel():
return $default(_that.verb,_that.summary,_that.status,_that.raw,_that.toolName,_that.isError,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String verb,  String summary,  String status,  String raw,  String? toolName,  bool isError,  int count)?  $default,) {final _that = this;
switch (_that) {
case _AssistantReceiptModel() when $default != null:
return $default(_that.verb,_that.summary,_that.status,_that.raw,_that.toolName,_that.isError,_that.count);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantReceiptModel extends AssistantReceiptModel {
  const _AssistantReceiptModel({required this.verb, required this.summary, required this.status, required this.raw, this.toolName, this.isError = false, this.count = 1}): super._();
  

@override final  String verb;
@override final  String summary;
@override final  String status;
@override final  String raw;
@override final  String? toolName;
@override@JsonKey() final  bool isError;
@override@JsonKey() final  int count;

/// Create a copy of AssistantReceiptModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantReceiptModelCopyWith<_AssistantReceiptModel> get copyWith => __$AssistantReceiptModelCopyWithImpl<_AssistantReceiptModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantReceiptModel&&(identical(other.verb, verb) || other.verb == verb)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.status, status) || other.status == status)&&(identical(other.raw, raw) || other.raw == raw)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.count, count) || other.count == count));
}


@override
int get hashCode => Object.hash(runtimeType,verb,summary,status,raw,toolName,isError,count);

@override
String toString() {
  return 'AssistantReceiptModel(verb: $verb, summary: $summary, status: $status, raw: $raw, toolName: $toolName, isError: $isError, count: $count)';
}


}

/// @nodoc
abstract mixin class _$AssistantReceiptModelCopyWith<$Res> implements $AssistantReceiptModelCopyWith<$Res> {
  factory _$AssistantReceiptModelCopyWith(_AssistantReceiptModel value, $Res Function(_AssistantReceiptModel) _then) = __$AssistantReceiptModelCopyWithImpl;
@override @useResult
$Res call({
 String verb, String summary, String status, String raw, String? toolName, bool isError, int count
});




}
/// @nodoc
class __$AssistantReceiptModelCopyWithImpl<$Res>
    implements _$AssistantReceiptModelCopyWith<$Res> {
  __$AssistantReceiptModelCopyWithImpl(this._self, this._then);

  final _AssistantReceiptModel _self;
  final $Res Function(_AssistantReceiptModel) _then;

/// Create a copy of AssistantReceiptModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? verb = null,Object? summary = null,Object? status = null,Object? raw = null,Object? toolName = freezed,Object? isError = null,Object? count = null,}) {
  return _then(_AssistantReceiptModel(
verb: null == verb ? _self.verb : verb // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,raw: null == raw ? _self.raw : raw // ignore: cast_nullable_to_non_nullable
as String,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$AssistantLogEntryModel {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantLogEntryModel);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AssistantLogEntryModel()';
}


}

/// @nodoc
class $AssistantLogEntryModelCopyWith<$Res>  {
$AssistantLogEntryModelCopyWith(AssistantLogEntryModel _, $Res Function(AssistantLogEntryModel) __);
}


/// Adds pattern-matching-related methods to [AssistantLogEntryModel].
extension AssistantLogEntryModelPatterns on AssistantLogEntryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AssistantLogMessageModel value)?  message,TResult Function( AssistantLogReceiptModel value)?  receipt,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AssistantLogMessageModel() when message != null:
return message(_that);case AssistantLogReceiptModel() when receipt != null:
return receipt(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AssistantLogMessageModel value)  message,required TResult Function( AssistantLogReceiptModel value)  receipt,}){
final _that = this;
switch (_that) {
case AssistantLogMessageModel():
return message(_that);case AssistantLogReceiptModel():
return receipt(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AssistantLogMessageModel value)?  message,TResult? Function( AssistantLogReceiptModel value)?  receipt,}){
final _that = this;
switch (_that) {
case AssistantLogMessageModel() when message != null:
return message(_that);case AssistantLogReceiptModel() when receipt != null:
return receipt(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ChatMessage message)?  message,TResult Function( AssistantReceiptModel receipt)?  receipt,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AssistantLogMessageModel() when message != null:
return message(_that.message);case AssistantLogReceiptModel() when receipt != null:
return receipt(_that.receipt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ChatMessage message)  message,required TResult Function( AssistantReceiptModel receipt)  receipt,}) {final _that = this;
switch (_that) {
case AssistantLogMessageModel():
return message(_that.message);case AssistantLogReceiptModel():
return receipt(_that.receipt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ChatMessage message)?  message,TResult? Function( AssistantReceiptModel receipt)?  receipt,}) {final _that = this;
switch (_that) {
case AssistantLogMessageModel() when message != null:
return message(_that.message);case AssistantLogReceiptModel() when receipt != null:
return receipt(_that.receipt);case _:
  return null;

}
}

}

/// @nodoc


class AssistantLogMessageModel extends AssistantLogEntryModel {
  const AssistantLogMessageModel(this.message): super._();
  

 final  ChatMessage message;

/// Create a copy of AssistantLogEntryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantLogMessageModelCopyWith<AssistantLogMessageModel> get copyWith => _$AssistantLogMessageModelCopyWithImpl<AssistantLogMessageModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantLogMessageModel&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AssistantLogEntryModel.message(message: $message)';
}


}

/// @nodoc
abstract mixin class $AssistantLogMessageModelCopyWith<$Res> implements $AssistantLogEntryModelCopyWith<$Res> {
  factory $AssistantLogMessageModelCopyWith(AssistantLogMessageModel value, $Res Function(AssistantLogMessageModel) _then) = _$AssistantLogMessageModelCopyWithImpl;
@useResult
$Res call({
 ChatMessage message
});




}
/// @nodoc
class _$AssistantLogMessageModelCopyWithImpl<$Res>
    implements $AssistantLogMessageModelCopyWith<$Res> {
  _$AssistantLogMessageModelCopyWithImpl(this._self, this._then);

  final AssistantLogMessageModel _self;
  final $Res Function(AssistantLogMessageModel) _then;

/// Create a copy of AssistantLogEntryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AssistantLogMessageModel(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as ChatMessage,
  ));
}


}

/// @nodoc


class AssistantLogReceiptModel extends AssistantLogEntryModel {
  const AssistantLogReceiptModel(this.receipt): super._();
  

 final  AssistantReceiptModel receipt;

/// Create a copy of AssistantLogEntryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantLogReceiptModelCopyWith<AssistantLogReceiptModel> get copyWith => _$AssistantLogReceiptModelCopyWithImpl<AssistantLogReceiptModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantLogReceiptModel&&(identical(other.receipt, receipt) || other.receipt == receipt));
}


@override
int get hashCode => Object.hash(runtimeType,receipt);

@override
String toString() {
  return 'AssistantLogEntryModel.receipt(receipt: $receipt)';
}


}

/// @nodoc
abstract mixin class $AssistantLogReceiptModelCopyWith<$Res> implements $AssistantLogEntryModelCopyWith<$Res> {
  factory $AssistantLogReceiptModelCopyWith(AssistantLogReceiptModel value, $Res Function(AssistantLogReceiptModel) _then) = _$AssistantLogReceiptModelCopyWithImpl;
@useResult
$Res call({
 AssistantReceiptModel receipt
});


$AssistantReceiptModelCopyWith<$Res> get receipt;

}
/// @nodoc
class _$AssistantLogReceiptModelCopyWithImpl<$Res>
    implements $AssistantLogReceiptModelCopyWith<$Res> {
  _$AssistantLogReceiptModelCopyWithImpl(this._self, this._then);

  final AssistantLogReceiptModel _self;
  final $Res Function(AssistantLogReceiptModel) _then;

/// Create a copy of AssistantLogEntryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? receipt = null,}) {
  return _then(AssistantLogReceiptModel(
null == receipt ? _self.receipt : receipt // ignore: cast_nullable_to_non_nullable
as AssistantReceiptModel,
  ));
}

/// Create a copy of AssistantLogEntryModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantReceiptModelCopyWith<$Res> get receipt {
  
  return $AssistantReceiptModelCopyWith<$Res>(_self.receipt, (value) {
    return _then(_self.copyWith(receipt: value));
  });
}
}

/// @nodoc
mixin _$ComposerPinModel {

 ComposerPinKind get kind; List<int> get ids; String get tabId; String get tabTitle; String? get path; String get label;
/// Create a copy of ComposerPinModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComposerPinModelCopyWith<ComposerPinModel> get copyWith => _$ComposerPinModelCopyWithImpl<ComposerPinModel>(this as ComposerPinModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComposerPinModel&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.ids, ids)&&(identical(other.tabId, tabId) || other.tabId == tabId)&&(identical(other.tabTitle, tabTitle) || other.tabTitle == tabTitle)&&(identical(other.path, path) || other.path == path)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(ids),tabId,tabTitle,path,label);

@override
String toString() {
  return 'ComposerPinModel(kind: $kind, ids: $ids, tabId: $tabId, tabTitle: $tabTitle, path: $path, label: $label)';
}


}

/// @nodoc
abstract mixin class $ComposerPinModelCopyWith<$Res>  {
  factory $ComposerPinModelCopyWith(ComposerPinModel value, $Res Function(ComposerPinModel) _then) = _$ComposerPinModelCopyWithImpl;
@useResult
$Res call({
 ComposerPinKind kind, List<int> ids, String tabId, String tabTitle, String? path, String label
});




}
/// @nodoc
class _$ComposerPinModelCopyWithImpl<$Res>
    implements $ComposerPinModelCopyWith<$Res> {
  _$ComposerPinModelCopyWithImpl(this._self, this._then);

  final ComposerPinModel _self;
  final $Res Function(ComposerPinModel) _then;

/// Create a copy of ComposerPinModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? ids = null,Object? tabId = null,Object? tabTitle = null,Object? path = freezed,Object? label = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ComposerPinKind,ids: null == ids ? _self.ids : ids // ignore: cast_nullable_to_non_nullable
as List<int>,tabId: null == tabId ? _self.tabId : tabId // ignore: cast_nullable_to_non_nullable
as String,tabTitle: null == tabTitle ? _self.tabTitle : tabTitle // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ComposerPinModel].
extension ComposerPinModelPatterns on ComposerPinModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComposerPinModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComposerPinModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComposerPinModel value)  $default,){
final _that = this;
switch (_that) {
case _ComposerPinModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComposerPinModel value)?  $default,){
final _that = this;
switch (_that) {
case _ComposerPinModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ComposerPinKind kind,  List<int> ids,  String tabId,  String tabTitle,  String? path,  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComposerPinModel() when $default != null:
return $default(_that.kind,_that.ids,_that.tabId,_that.tabTitle,_that.path,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ComposerPinKind kind,  List<int> ids,  String tabId,  String tabTitle,  String? path,  String label)  $default,) {final _that = this;
switch (_that) {
case _ComposerPinModel():
return $default(_that.kind,_that.ids,_that.tabId,_that.tabTitle,_that.path,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ComposerPinKind kind,  List<int> ids,  String tabId,  String tabTitle,  String? path,  String label)?  $default,) {final _that = this;
switch (_that) {
case _ComposerPinModel() when $default != null:
return $default(_that.kind,_that.ids,_that.tabId,_that.tabTitle,_that.path,_that.label);case _:
  return null;

}
}

}

/// @nodoc


class _ComposerPinModel extends ComposerPinModel {
  const _ComposerPinModel({required this.kind, final  List<int> ids = const [], this.tabId = '', this.tabTitle = '', this.path, this.label = ''}): _ids = ids,super._();
  

@override final  ComposerPinKind kind;
 final  List<int> _ids;
@override@JsonKey() List<int> get ids {
  if (_ids is EqualUnmodifiableListView) return _ids;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ids);
}

@override@JsonKey() final  String tabId;
@override@JsonKey() final  String tabTitle;
@override final  String? path;
@override@JsonKey() final  String label;

/// Create a copy of ComposerPinModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComposerPinModelCopyWith<_ComposerPinModel> get copyWith => __$ComposerPinModelCopyWithImpl<_ComposerPinModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComposerPinModel&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._ids, _ids)&&(identical(other.tabId, tabId) || other.tabId == tabId)&&(identical(other.tabTitle, tabTitle) || other.tabTitle == tabTitle)&&(identical(other.path, path) || other.path == path)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_ids),tabId,tabTitle,path,label);

@override
String toString() {
  return 'ComposerPinModel(kind: $kind, ids: $ids, tabId: $tabId, tabTitle: $tabTitle, path: $path, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ComposerPinModelCopyWith<$Res> implements $ComposerPinModelCopyWith<$Res> {
  factory _$ComposerPinModelCopyWith(_ComposerPinModel value, $Res Function(_ComposerPinModel) _then) = __$ComposerPinModelCopyWithImpl;
@override @useResult
$Res call({
 ComposerPinKind kind, List<int> ids, String tabId, String tabTitle, String? path, String label
});




}
/// @nodoc
class __$ComposerPinModelCopyWithImpl<$Res>
    implements _$ComposerPinModelCopyWith<$Res> {
  __$ComposerPinModelCopyWithImpl(this._self, this._then);

  final _ComposerPinModel _self;
  final $Res Function(_ComposerPinModel) _then;

/// Create a copy of ComposerPinModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? ids = null,Object? tabId = null,Object? tabTitle = null,Object? path = freezed,Object? label = null,}) {
  return _then(_ComposerPinModel(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ComposerPinKind,ids: null == ids ? _self._ids : ids // ignore: cast_nullable_to_non_nullable
as List<int>,tabId: null == tabId ? _self.tabId : tabId // ignore: cast_nullable_to_non_nullable
as String,tabTitle: null == tabTitle ? _self.tabTitle : tabTitle // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ComposerPinSpanModel {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComposerPinSpanModel);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ComposerPinSpanModel()';
}


}

/// @nodoc
class $ComposerPinSpanModelCopyWith<$Res>  {
$ComposerPinSpanModelCopyWith(ComposerPinSpanModel _, $Res Function(ComposerPinSpanModel) __);
}


/// Adds pattern-matching-related methods to [ComposerPinSpanModel].
extension ComposerPinSpanModelPatterns on ComposerPinSpanModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ComposerPinTextModel value)?  text,TResult Function( ComposerPinChipModel value)?  pin,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ComposerPinTextModel() when text != null:
return text(_that);case ComposerPinChipModel() when pin != null:
return pin(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ComposerPinTextModel value)  text,required TResult Function( ComposerPinChipModel value)  pin,}){
final _that = this;
switch (_that) {
case ComposerPinTextModel():
return text(_that);case ComposerPinChipModel():
return pin(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ComposerPinTextModel value)?  text,TResult? Function( ComposerPinChipModel value)?  pin,}){
final _that = this;
switch (_that) {
case ComposerPinTextModel() when text != null:
return text(_that);case ComposerPinChipModel() when pin != null:
return pin(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  text,TResult Function( ComposerPinModel pin)?  pin,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ComposerPinTextModel() when text != null:
return text(_that.text);case ComposerPinChipModel() when pin != null:
return pin(_that.pin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  text,required TResult Function( ComposerPinModel pin)  pin,}) {final _that = this;
switch (_that) {
case ComposerPinTextModel():
return text(_that.text);case ComposerPinChipModel():
return pin(_that.pin);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  text,TResult? Function( ComposerPinModel pin)?  pin,}) {final _that = this;
switch (_that) {
case ComposerPinTextModel() when text != null:
return text(_that.text);case ComposerPinChipModel() when pin != null:
return pin(_that.pin);case _:
  return null;

}
}

}

/// @nodoc


class ComposerPinTextModel implements ComposerPinSpanModel {
  const ComposerPinTextModel(this.text);
  

 final  String text;

/// Create a copy of ComposerPinSpanModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComposerPinTextModelCopyWith<ComposerPinTextModel> get copyWith => _$ComposerPinTextModelCopyWithImpl<ComposerPinTextModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComposerPinTextModel&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'ComposerPinSpanModel.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $ComposerPinTextModelCopyWith<$Res> implements $ComposerPinSpanModelCopyWith<$Res> {
  factory $ComposerPinTextModelCopyWith(ComposerPinTextModel value, $Res Function(ComposerPinTextModel) _then) = _$ComposerPinTextModelCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$ComposerPinTextModelCopyWithImpl<$Res>
    implements $ComposerPinTextModelCopyWith<$Res> {
  _$ComposerPinTextModelCopyWithImpl(this._self, this._then);

  final ComposerPinTextModel _self;
  final $Res Function(ComposerPinTextModel) _then;

/// Create a copy of ComposerPinSpanModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(ComposerPinTextModel(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ComposerPinChipModel implements ComposerPinSpanModel {
  const ComposerPinChipModel(this.pin);
  

 final  ComposerPinModel pin;

/// Create a copy of ComposerPinSpanModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComposerPinChipModelCopyWith<ComposerPinChipModel> get copyWith => _$ComposerPinChipModelCopyWithImpl<ComposerPinChipModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComposerPinChipModel&&(identical(other.pin, pin) || other.pin == pin));
}


@override
int get hashCode => Object.hash(runtimeType,pin);

@override
String toString() {
  return 'ComposerPinSpanModel.pin(pin: $pin)';
}


}

/// @nodoc
abstract mixin class $ComposerPinChipModelCopyWith<$Res> implements $ComposerPinSpanModelCopyWith<$Res> {
  factory $ComposerPinChipModelCopyWith(ComposerPinChipModel value, $Res Function(ComposerPinChipModel) _then) = _$ComposerPinChipModelCopyWithImpl;
@useResult
$Res call({
 ComposerPinModel pin
});


$ComposerPinModelCopyWith<$Res> get pin;

}
/// @nodoc
class _$ComposerPinChipModelCopyWithImpl<$Res>
    implements $ComposerPinChipModelCopyWith<$Res> {
  _$ComposerPinChipModelCopyWithImpl(this._self, this._then);

  final ComposerPinChipModel _self;
  final $Res Function(ComposerPinChipModel) _then;

/// Create a copy of ComposerPinSpanModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pin = null,}) {
  return _then(ComposerPinChipModel(
null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as ComposerPinModel,
  ));
}

/// Create a copy of ComposerPinSpanModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ComposerPinModelCopyWith<$Res> get pin {
  
  return $ComposerPinModelCopyWith<$Res>(_self.pin, (value) {
    return _then(_self.copyWith(pin: value));
  });
}
}

/// @nodoc
mixin _$ComposerAtMentionModel {

/// Index of the `@`.
 int get start;/// Cursor, exclusive end of the query.
 int get end; String get query;
/// Create a copy of ComposerAtMentionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComposerAtMentionModelCopyWith<ComposerAtMentionModel> get copyWith => _$ComposerAtMentionModelCopyWithImpl<ComposerAtMentionModel>(this as ComposerAtMentionModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComposerAtMentionModel&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.query, query) || other.query == query));
}


@override
int get hashCode => Object.hash(runtimeType,start,end,query);

@override
String toString() {
  return 'ComposerAtMentionModel(start: $start, end: $end, query: $query)';
}


}

/// @nodoc
abstract mixin class $ComposerAtMentionModelCopyWith<$Res>  {
  factory $ComposerAtMentionModelCopyWith(ComposerAtMentionModel value, $Res Function(ComposerAtMentionModel) _then) = _$ComposerAtMentionModelCopyWithImpl;
@useResult
$Res call({
 int start, int end, String query
});




}
/// @nodoc
class _$ComposerAtMentionModelCopyWithImpl<$Res>
    implements $ComposerAtMentionModelCopyWith<$Res> {
  _$ComposerAtMentionModelCopyWithImpl(this._self, this._then);

  final ComposerAtMentionModel _self;
  final $Res Function(ComposerAtMentionModel) _then;

/// Create a copy of ComposerAtMentionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? end = null,Object? query = null,}) {
  return _then(_self.copyWith(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ComposerAtMentionModel].
extension ComposerAtMentionModelPatterns on ComposerAtMentionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComposerAtMentionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComposerAtMentionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComposerAtMentionModel value)  $default,){
final _that = this;
switch (_that) {
case _ComposerAtMentionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComposerAtMentionModel value)?  $default,){
final _that = this;
switch (_that) {
case _ComposerAtMentionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int start,  int end,  String query)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComposerAtMentionModel() when $default != null:
return $default(_that.start,_that.end,_that.query);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int start,  int end,  String query)  $default,) {final _that = this;
switch (_that) {
case _ComposerAtMentionModel():
return $default(_that.start,_that.end,_that.query);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int start,  int end,  String query)?  $default,) {final _that = this;
switch (_that) {
case _ComposerAtMentionModel() when $default != null:
return $default(_that.start,_that.end,_that.query);case _:
  return null;

}
}

}

/// @nodoc


class _ComposerAtMentionModel implements ComposerAtMentionModel {
  const _ComposerAtMentionModel({required this.start, required this.end, required this.query});
  

/// Index of the `@`.
@override final  int start;
/// Cursor, exclusive end of the query.
@override final  int end;
@override final  String query;

/// Create a copy of ComposerAtMentionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComposerAtMentionModelCopyWith<_ComposerAtMentionModel> get copyWith => __$ComposerAtMentionModelCopyWithImpl<_ComposerAtMentionModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComposerAtMentionModel&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.query, query) || other.query == query));
}


@override
int get hashCode => Object.hash(runtimeType,start,end,query);

@override
String toString() {
  return 'ComposerAtMentionModel(start: $start, end: $end, query: $query)';
}


}

/// @nodoc
abstract mixin class _$ComposerAtMentionModelCopyWith<$Res> implements $ComposerAtMentionModelCopyWith<$Res> {
  factory _$ComposerAtMentionModelCopyWith(_ComposerAtMentionModel value, $Res Function(_ComposerAtMentionModel) _then) = __$ComposerAtMentionModelCopyWithImpl;
@override @useResult
$Res call({
 int start, int end, String query
});




}
/// @nodoc
class __$ComposerAtMentionModelCopyWithImpl<$Res>
    implements _$ComposerAtMentionModelCopyWith<$Res> {
  __$ComposerAtMentionModelCopyWithImpl(this._self, this._then);

  final _ComposerAtMentionModel _self;
  final $Res Function(_ComposerAtMentionModel) _then;

/// Create a copy of ComposerAtMentionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? end = null,Object? query = null,}) {
  return _then(_ComposerAtMentionModel(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
