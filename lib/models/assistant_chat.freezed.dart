// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant_chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AssistantChat {

 String get id; String get title; DateTime get updatedAt; Conversation get conversation; LlmUsage? get usage; String get draft;
/// Create a copy of AssistantChat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantChatCopyWith<AssistantChat> get copyWith => _$AssistantChatCopyWithImpl<AssistantChat>(this as AssistantChat, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantChat&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.conversation, conversation) || other.conversation == conversation)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.draft, draft) || other.draft == draft));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,updatedAt,conversation,usage,draft);

@override
String toString() {
  return 'AssistantChat(id: $id, title: $title, updatedAt: $updatedAt, conversation: $conversation, usage: $usage, draft: $draft)';
}


}

/// @nodoc
abstract mixin class $AssistantChatCopyWith<$Res>  {
  factory $AssistantChatCopyWith(AssistantChat value, $Res Function(AssistantChat) _then) = _$AssistantChatCopyWithImpl;
@useResult
$Res call({
 String id, String title, DateTime updatedAt, Conversation conversation, LlmUsage? usage, String draft
});




}
/// @nodoc
class _$AssistantChatCopyWithImpl<$Res>
    implements $AssistantChatCopyWith<$Res> {
  _$AssistantChatCopyWithImpl(this._self, this._then);

  final AssistantChat _self;
  final $Res Function(AssistantChat) _then;

/// Create a copy of AssistantChat
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


/// Adds pattern-matching-related methods to [AssistantChat].
extension AssistantChatPatterns on AssistantChat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _AssistantChat value)?  raw,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantChat() when raw != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _AssistantChat value)  raw,}){
final _that = this;
switch (_that) {
case _AssistantChat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _AssistantChat value)?  raw,}){
final _that = this;
switch (_that) {
case _AssistantChat() when raw != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String title,  DateTime updatedAt,  Conversation conversation,  LlmUsage? usage,  String draft)?  raw,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantChat() when raw != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String title,  DateTime updatedAt,  Conversation conversation,  LlmUsage? usage,  String draft)  raw,}) {final _that = this;
switch (_that) {
case _AssistantChat():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String title,  DateTime updatedAt,  Conversation conversation,  LlmUsage? usage,  String draft)?  raw,}) {final _that = this;
switch (_that) {
case _AssistantChat() when raw != null:
return raw(_that.id,_that.title,_that.updatedAt,_that.conversation,_that.usage,_that.draft);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantChat extends AssistantChat {
  const _AssistantChat({required this.id, this.title = '', required this.updatedAt, required this.conversation, this.usage, this.draft = ''}): super._();
  

@override final  String id;
@override@JsonKey() final  String title;
@override final  DateTime updatedAt;
@override final  Conversation conversation;
@override final  LlmUsage? usage;
@override@JsonKey() final  String draft;

/// Create a copy of AssistantChat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantChatCopyWith<_AssistantChat> get copyWith => __$AssistantChatCopyWithImpl<_AssistantChat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantChat&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.conversation, conversation) || other.conversation == conversation)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.draft, draft) || other.draft == draft));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,updatedAt,conversation,usage,draft);

@override
String toString() {
  return 'AssistantChat.raw(id: $id, title: $title, updatedAt: $updatedAt, conversation: $conversation, usage: $usage, draft: $draft)';
}


}

/// @nodoc
abstract mixin class _$AssistantChatCopyWith<$Res> implements $AssistantChatCopyWith<$Res> {
  factory _$AssistantChatCopyWith(_AssistantChat value, $Res Function(_AssistantChat) _then) = __$AssistantChatCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, DateTime updatedAt, Conversation conversation, LlmUsage? usage, String draft
});




}
/// @nodoc
class __$AssistantChatCopyWithImpl<$Res>
    implements _$AssistantChatCopyWith<$Res> {
  __$AssistantChatCopyWithImpl(this._self, this._then);

  final _AssistantChat _self;
  final $Res Function(_AssistantChat) _then;

/// Create a copy of AssistantChat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? updatedAt = null,Object? conversation = null,Object? usage = freezed,Object? draft = null,}) {
  return _then(_AssistantChat(
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

// dart format on
