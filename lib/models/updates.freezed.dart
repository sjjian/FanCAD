// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'updates.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UpdateStateModel {

 UpdatePhase get phase; bool get autoCheck; String get promptedVersion; String get skippedVersion; DateTime? get lastCheckedAt; ReleaseInfo? get release; DownloadResult? get download; DownloadProgress? get progress; String? get error; List<SourceAttempt> get attempts;
/// Create a copy of UpdateStateModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateStateModelCopyWith<UpdateStateModel> get copyWith => _$UpdateStateModelCopyWithImpl<UpdateStateModel>(this as UpdateStateModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateStateModel&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.autoCheck, autoCheck) || other.autoCheck == autoCheck)&&(identical(other.promptedVersion, promptedVersion) || other.promptedVersion == promptedVersion)&&(identical(other.skippedVersion, skippedVersion) || other.skippedVersion == skippedVersion)&&(identical(other.lastCheckedAt, lastCheckedAt) || other.lastCheckedAt == lastCheckedAt)&&(identical(other.release, release) || other.release == release)&&(identical(other.download, download) || other.download == download)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.attempts, attempts));
}


@override
int get hashCode => Object.hash(runtimeType,phase,autoCheck,promptedVersion,skippedVersion,lastCheckedAt,release,download,progress,error,const DeepCollectionEquality().hash(attempts));

@override
String toString() {
  return 'UpdateStateModel(phase: $phase, autoCheck: $autoCheck, promptedVersion: $promptedVersion, skippedVersion: $skippedVersion, lastCheckedAt: $lastCheckedAt, release: $release, download: $download, progress: $progress, error: $error, attempts: $attempts)';
}


}

/// @nodoc
abstract mixin class $UpdateStateModelCopyWith<$Res>  {
  factory $UpdateStateModelCopyWith(UpdateStateModel value, $Res Function(UpdateStateModel) _then) = _$UpdateStateModelCopyWithImpl;
@useResult
$Res call({
 UpdatePhase phase, bool autoCheck, String promptedVersion, String skippedVersion, DateTime? lastCheckedAt, ReleaseInfo? release, DownloadResult? download, DownloadProgress? progress, String? error, List<SourceAttempt> attempts
});




}
/// @nodoc
class _$UpdateStateModelCopyWithImpl<$Res>
    implements $UpdateStateModelCopyWith<$Res> {
  _$UpdateStateModelCopyWithImpl(this._self, this._then);

  final UpdateStateModel _self;
  final $Res Function(UpdateStateModel) _then;

/// Create a copy of UpdateStateModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? autoCheck = null,Object? promptedVersion = null,Object? skippedVersion = null,Object? lastCheckedAt = freezed,Object? release = freezed,Object? download = freezed,Object? progress = freezed,Object? error = freezed,Object? attempts = null,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as UpdatePhase,autoCheck: null == autoCheck ? _self.autoCheck : autoCheck // ignore: cast_nullable_to_non_nullable
as bool,promptedVersion: null == promptedVersion ? _self.promptedVersion : promptedVersion // ignore: cast_nullable_to_non_nullable
as String,skippedVersion: null == skippedVersion ? _self.skippedVersion : skippedVersion // ignore: cast_nullable_to_non_nullable
as String,lastCheckedAt: freezed == lastCheckedAt ? _self.lastCheckedAt : lastCheckedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,release: freezed == release ? _self.release : release // ignore: cast_nullable_to_non_nullable
as ReleaseInfo?,download: freezed == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as DownloadResult?,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as DownloadProgress?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as List<SourceAttempt>,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateStateModel].
extension UpdateStateModelPatterns on UpdateStateModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateStateModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateStateModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateStateModel value)  $default,){
final _that = this;
switch (_that) {
case _UpdateStateModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateStateModel value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateStateModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UpdatePhase phase,  bool autoCheck,  String promptedVersion,  String skippedVersion,  DateTime? lastCheckedAt,  ReleaseInfo? release,  DownloadResult? download,  DownloadProgress? progress,  String? error,  List<SourceAttempt> attempts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateStateModel() when $default != null:
return $default(_that.phase,_that.autoCheck,_that.promptedVersion,_that.skippedVersion,_that.lastCheckedAt,_that.release,_that.download,_that.progress,_that.error,_that.attempts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UpdatePhase phase,  bool autoCheck,  String promptedVersion,  String skippedVersion,  DateTime? lastCheckedAt,  ReleaseInfo? release,  DownloadResult? download,  DownloadProgress? progress,  String? error,  List<SourceAttempt> attempts)  $default,) {final _that = this;
switch (_that) {
case _UpdateStateModel():
return $default(_that.phase,_that.autoCheck,_that.promptedVersion,_that.skippedVersion,_that.lastCheckedAt,_that.release,_that.download,_that.progress,_that.error,_that.attempts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UpdatePhase phase,  bool autoCheck,  String promptedVersion,  String skippedVersion,  DateTime? lastCheckedAt,  ReleaseInfo? release,  DownloadResult? download,  DownloadProgress? progress,  String? error,  List<SourceAttempt> attempts)?  $default,) {final _that = this;
switch (_that) {
case _UpdateStateModel() when $default != null:
return $default(_that.phase,_that.autoCheck,_that.promptedVersion,_that.skippedVersion,_that.lastCheckedAt,_that.release,_that.download,_that.progress,_that.error,_that.attempts);case _:
  return null;

}
}

}

/// @nodoc


class _UpdateStateModel extends UpdateStateModel {
  const _UpdateStateModel({this.phase = UpdatePhase.idle, this.autoCheck = true, this.promptedVersion = '', this.skippedVersion = '', this.lastCheckedAt, this.release, this.download, this.progress, this.error, final  List<SourceAttempt> attempts = const <SourceAttempt>[]}): _attempts = attempts,super._();
  

@override@JsonKey() final  UpdatePhase phase;
@override@JsonKey() final  bool autoCheck;
@override@JsonKey() final  String promptedVersion;
@override@JsonKey() final  String skippedVersion;
@override final  DateTime? lastCheckedAt;
@override final  ReleaseInfo? release;
@override final  DownloadResult? download;
@override final  DownloadProgress? progress;
@override final  String? error;
 final  List<SourceAttempt> _attempts;
@override@JsonKey() List<SourceAttempt> get attempts {
  if (_attempts is EqualUnmodifiableListView) return _attempts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attempts);
}


/// Create a copy of UpdateStateModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateStateModelCopyWith<_UpdateStateModel> get copyWith => __$UpdateStateModelCopyWithImpl<_UpdateStateModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateStateModel&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.autoCheck, autoCheck) || other.autoCheck == autoCheck)&&(identical(other.promptedVersion, promptedVersion) || other.promptedVersion == promptedVersion)&&(identical(other.skippedVersion, skippedVersion) || other.skippedVersion == skippedVersion)&&(identical(other.lastCheckedAt, lastCheckedAt) || other.lastCheckedAt == lastCheckedAt)&&(identical(other.release, release) || other.release == release)&&(identical(other.download, download) || other.download == download)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other._attempts, _attempts));
}


@override
int get hashCode => Object.hash(runtimeType,phase,autoCheck,promptedVersion,skippedVersion,lastCheckedAt,release,download,progress,error,const DeepCollectionEquality().hash(_attempts));

@override
String toString() {
  return 'UpdateStateModel(phase: $phase, autoCheck: $autoCheck, promptedVersion: $promptedVersion, skippedVersion: $skippedVersion, lastCheckedAt: $lastCheckedAt, release: $release, download: $download, progress: $progress, error: $error, attempts: $attempts)';
}


}

/// @nodoc
abstract mixin class _$UpdateStateModelCopyWith<$Res> implements $UpdateStateModelCopyWith<$Res> {
  factory _$UpdateStateModelCopyWith(_UpdateStateModel value, $Res Function(_UpdateStateModel) _then) = __$UpdateStateModelCopyWithImpl;
@override @useResult
$Res call({
 UpdatePhase phase, bool autoCheck, String promptedVersion, String skippedVersion, DateTime? lastCheckedAt, ReleaseInfo? release, DownloadResult? download, DownloadProgress? progress, String? error, List<SourceAttempt> attempts
});




}
/// @nodoc
class __$UpdateStateModelCopyWithImpl<$Res>
    implements _$UpdateStateModelCopyWith<$Res> {
  __$UpdateStateModelCopyWithImpl(this._self, this._then);

  final _UpdateStateModel _self;
  final $Res Function(_UpdateStateModel) _then;

/// Create a copy of UpdateStateModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? autoCheck = null,Object? promptedVersion = null,Object? skippedVersion = null,Object? lastCheckedAt = freezed,Object? release = freezed,Object? download = freezed,Object? progress = freezed,Object? error = freezed,Object? attempts = null,}) {
  return _then(_UpdateStateModel(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as UpdatePhase,autoCheck: null == autoCheck ? _self.autoCheck : autoCheck // ignore: cast_nullable_to_non_nullable
as bool,promptedVersion: null == promptedVersion ? _self.promptedVersion : promptedVersion // ignore: cast_nullable_to_non_nullable
as String,skippedVersion: null == skippedVersion ? _self.skippedVersion : skippedVersion // ignore: cast_nullable_to_non_nullable
as String,lastCheckedAt: freezed == lastCheckedAt ? _self.lastCheckedAt : lastCheckedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,release: freezed == release ? _self.release : release // ignore: cast_nullable_to_non_nullable
as ReleaseInfo?,download: freezed == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as DownloadResult?,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as DownloadProgress?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attempts: null == attempts ? _self._attempts : attempts // ignore: cast_nullable_to_non_nullable
as List<SourceAttempt>,
  ));
}


}

// dart format on
