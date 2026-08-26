// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant_receipt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AssistantReceipt {

 String get verb; String get summary; String get status; String get raw; String? get toolName; bool get isError; int get count;
/// Create a copy of AssistantReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantReceiptCopyWith<AssistantReceipt> get copyWith => _$AssistantReceiptCopyWithImpl<AssistantReceipt>(this as AssistantReceipt, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantReceipt&&(identical(other.verb, verb) || other.verb == verb)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.status, status) || other.status == status)&&(identical(other.raw, raw) || other.raw == raw)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.count, count) || other.count == count));
}


@override
int get hashCode => Object.hash(runtimeType,verb,summary,status,raw,toolName,isError,count);

@override
String toString() {
  return 'AssistantReceipt(verb: $verb, summary: $summary, status: $status, raw: $raw, toolName: $toolName, isError: $isError, count: $count)';
}


}

/// @nodoc
abstract mixin class $AssistantReceiptCopyWith<$Res>  {
  factory $AssistantReceiptCopyWith(AssistantReceipt value, $Res Function(AssistantReceipt) _then) = _$AssistantReceiptCopyWithImpl;
@useResult
$Res call({
 String verb, String summary, String status, String raw, String? toolName, bool isError, int count
});




}
/// @nodoc
class _$AssistantReceiptCopyWithImpl<$Res>
    implements $AssistantReceiptCopyWith<$Res> {
  _$AssistantReceiptCopyWithImpl(this._self, this._then);

  final AssistantReceipt _self;
  final $Res Function(AssistantReceipt) _then;

/// Create a copy of AssistantReceipt
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


/// Adds pattern-matching-related methods to [AssistantReceipt].
extension AssistantReceiptPatterns on AssistantReceipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantReceipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantReceipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantReceipt value)  $default,){
final _that = this;
switch (_that) {
case _AssistantReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantReceipt value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantReceipt() when $default != null:
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
case _AssistantReceipt() when $default != null:
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
case _AssistantReceipt():
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
case _AssistantReceipt() when $default != null:
return $default(_that.verb,_that.summary,_that.status,_that.raw,_that.toolName,_that.isError,_that.count);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantReceipt extends AssistantReceipt {
  const _AssistantReceipt({required this.verb, required this.summary, required this.status, required this.raw, this.toolName, this.isError = false, this.count = 1}): super._();
  

@override final  String verb;
@override final  String summary;
@override final  String status;
@override final  String raw;
@override final  String? toolName;
@override@JsonKey() final  bool isError;
@override@JsonKey() final  int count;

/// Create a copy of AssistantReceipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantReceiptCopyWith<_AssistantReceipt> get copyWith => __$AssistantReceiptCopyWithImpl<_AssistantReceipt>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantReceipt&&(identical(other.verb, verb) || other.verb == verb)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.status, status) || other.status == status)&&(identical(other.raw, raw) || other.raw == raw)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.count, count) || other.count == count));
}


@override
int get hashCode => Object.hash(runtimeType,verb,summary,status,raw,toolName,isError,count);

@override
String toString() {
  return 'AssistantReceipt(verb: $verb, summary: $summary, status: $status, raw: $raw, toolName: $toolName, isError: $isError, count: $count)';
}


}

/// @nodoc
abstract mixin class _$AssistantReceiptCopyWith<$Res> implements $AssistantReceiptCopyWith<$Res> {
  factory _$AssistantReceiptCopyWith(_AssistantReceipt value, $Res Function(_AssistantReceipt) _then) = __$AssistantReceiptCopyWithImpl;
@override @useResult
$Res call({
 String verb, String summary, String status, String raw, String? toolName, bool isError, int count
});




}
/// @nodoc
class __$AssistantReceiptCopyWithImpl<$Res>
    implements _$AssistantReceiptCopyWith<$Res> {
  __$AssistantReceiptCopyWithImpl(this._self, this._then);

  final _AssistantReceipt _self;
  final $Res Function(_AssistantReceipt) _then;

/// Create a copy of AssistantReceipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? verb = null,Object? summary = null,Object? status = null,Object? raw = null,Object? toolName = freezed,Object? isError = null,Object? count = null,}) {
  return _then(_AssistantReceipt(
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
mixin _$AssistantLogEntry {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantLogEntry);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AssistantLogEntry()';
}


}

/// @nodoc
class $AssistantLogEntryCopyWith<$Res>  {
$AssistantLogEntryCopyWith(AssistantLogEntry _, $Res Function(AssistantLogEntry) __);
}


/// Adds pattern-matching-related methods to [AssistantLogEntry].
extension AssistantLogEntryPatterns on AssistantLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AssistantLogMessage value)?  message,TResult Function( AssistantLogReceipt value)?  receipt,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AssistantLogMessage() when message != null:
return message(_that);case AssistantLogReceipt() when receipt != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AssistantLogMessage value)  message,required TResult Function( AssistantLogReceipt value)  receipt,}){
final _that = this;
switch (_that) {
case AssistantLogMessage():
return message(_that);case AssistantLogReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AssistantLogMessage value)?  message,TResult? Function( AssistantLogReceipt value)?  receipt,}){
final _that = this;
switch (_that) {
case AssistantLogMessage() when message != null:
return message(_that);case AssistantLogReceipt() when receipt != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ChatMessage message)?  message,TResult Function( AssistantReceipt receipt)?  receipt,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AssistantLogMessage() when message != null:
return message(_that.message);case AssistantLogReceipt() when receipt != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ChatMessage message)  message,required TResult Function( AssistantReceipt receipt)  receipt,}) {final _that = this;
switch (_that) {
case AssistantLogMessage():
return message(_that.message);case AssistantLogReceipt():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ChatMessage message)?  message,TResult? Function( AssistantReceipt receipt)?  receipt,}) {final _that = this;
switch (_that) {
case AssistantLogMessage() when message != null:
return message(_that.message);case AssistantLogReceipt() when receipt != null:
return receipt(_that.receipt);case _:
  return null;

}
}

}

/// @nodoc


class AssistantLogMessage extends AssistantLogEntry {
  const AssistantLogMessage(this.message): super._();
  

 final  ChatMessage message;

/// Create a copy of AssistantLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantLogMessageCopyWith<AssistantLogMessage> get copyWith => _$AssistantLogMessageCopyWithImpl<AssistantLogMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantLogMessage&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AssistantLogEntry.message(message: $message)';
}


}

/// @nodoc
abstract mixin class $AssistantLogMessageCopyWith<$Res> implements $AssistantLogEntryCopyWith<$Res> {
  factory $AssistantLogMessageCopyWith(AssistantLogMessage value, $Res Function(AssistantLogMessage) _then) = _$AssistantLogMessageCopyWithImpl;
@useResult
$Res call({
 ChatMessage message
});




}
/// @nodoc
class _$AssistantLogMessageCopyWithImpl<$Res>
    implements $AssistantLogMessageCopyWith<$Res> {
  _$AssistantLogMessageCopyWithImpl(this._self, this._then);

  final AssistantLogMessage _self;
  final $Res Function(AssistantLogMessage) _then;

/// Create a copy of AssistantLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AssistantLogMessage(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as ChatMessage,
  ));
}


}

/// @nodoc


class AssistantLogReceipt extends AssistantLogEntry {
  const AssistantLogReceipt(this.receipt): super._();
  

 final  AssistantReceipt receipt;

/// Create a copy of AssistantLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantLogReceiptCopyWith<AssistantLogReceipt> get copyWith => _$AssistantLogReceiptCopyWithImpl<AssistantLogReceipt>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantLogReceipt&&(identical(other.receipt, receipt) || other.receipt == receipt));
}


@override
int get hashCode => Object.hash(runtimeType,receipt);

@override
String toString() {
  return 'AssistantLogEntry.receipt(receipt: $receipt)';
}


}

/// @nodoc
abstract mixin class $AssistantLogReceiptCopyWith<$Res> implements $AssistantLogEntryCopyWith<$Res> {
  factory $AssistantLogReceiptCopyWith(AssistantLogReceipt value, $Res Function(AssistantLogReceipt) _then) = _$AssistantLogReceiptCopyWithImpl;
@useResult
$Res call({
 AssistantReceipt receipt
});


$AssistantReceiptCopyWith<$Res> get receipt;

}
/// @nodoc
class _$AssistantLogReceiptCopyWithImpl<$Res>
    implements $AssistantLogReceiptCopyWith<$Res> {
  _$AssistantLogReceiptCopyWithImpl(this._self, this._then);

  final AssistantLogReceipt _self;
  final $Res Function(AssistantLogReceipt) _then;

/// Create a copy of AssistantLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? receipt = null,}) {
  return _then(AssistantLogReceipt(
null == receipt ? _self.receipt : receipt // ignore: cast_nullable_to_non_nullable
as AssistantReceipt,
  ));
}

/// Create a copy of AssistantLogEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantReceiptCopyWith<$Res> get receipt {
  
  return $AssistantReceiptCopyWith<$Res>(_self.receipt, (value) {
    return _then(_self.copyWith(receipt: value));
  });
}
}

// dart format on
