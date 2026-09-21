// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkspaceModel {

 List<WorkspaceSessionModel> get sessions; int get activeIndex; List<NoticeModel> get notices; ApprovalRequestModel? get approval; bool get assistantBusy; String? get runningCommand; bool get snapEnabled; bool get ortho; bool get polar; List<String> get snapModes; List<String> get recentFiles; List<int> get lastCreatedIds; List<int> get lastModifiedIds; int get collectedPointCount;
/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceModelCopyWith<WorkspaceModel> get copyWith => _$WorkspaceModelCopyWithImpl<WorkspaceModel>(this as WorkspaceModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceModel&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.activeIndex, activeIndex) || other.activeIndex == activeIndex)&&const DeepCollectionEquality().equals(other.notices, notices)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.assistantBusy, assistantBusy) || other.assistantBusy == assistantBusy)&&(identical(other.runningCommand, runningCommand) || other.runningCommand == runningCommand)&&(identical(other.snapEnabled, snapEnabled) || other.snapEnabled == snapEnabled)&&(identical(other.ortho, ortho) || other.ortho == ortho)&&(identical(other.polar, polar) || other.polar == polar)&&const DeepCollectionEquality().equals(other.snapModes, snapModes)&&const DeepCollectionEquality().equals(other.recentFiles, recentFiles)&&const DeepCollectionEquality().equals(other.lastCreatedIds, lastCreatedIds)&&const DeepCollectionEquality().equals(other.lastModifiedIds, lastModifiedIds)&&(identical(other.collectedPointCount, collectedPointCount) || other.collectedPointCount == collectedPointCount));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions),activeIndex,const DeepCollectionEquality().hash(notices),approval,assistantBusy,runningCommand,snapEnabled,ortho,polar,const DeepCollectionEquality().hash(snapModes),const DeepCollectionEquality().hash(recentFiles),const DeepCollectionEquality().hash(lastCreatedIds),const DeepCollectionEquality().hash(lastModifiedIds),collectedPointCount);

@override
String toString() {
  return 'WorkspaceModel(sessions: $sessions, activeIndex: $activeIndex, notices: $notices, approval: $approval, assistantBusy: $assistantBusy, runningCommand: $runningCommand, snapEnabled: $snapEnabled, ortho: $ortho, polar: $polar, snapModes: $snapModes, recentFiles: $recentFiles, lastCreatedIds: $lastCreatedIds, lastModifiedIds: $lastModifiedIds, collectedPointCount: $collectedPointCount)';
}


}

/// @nodoc
abstract mixin class $WorkspaceModelCopyWith<$Res>  {
  factory $WorkspaceModelCopyWith(WorkspaceModel value, $Res Function(WorkspaceModel) _then) = _$WorkspaceModelCopyWithImpl;
@useResult
$Res call({
 List<WorkspaceSessionModel> sessions, int activeIndex, List<NoticeModel> notices, ApprovalRequestModel? approval, bool assistantBusy, String? runningCommand, bool snapEnabled, bool ortho, bool polar, List<String> snapModes, List<String> recentFiles, List<int> lastCreatedIds, List<int> lastModifiedIds, int collectedPointCount
});


$ApprovalRequestModelCopyWith<$Res>? get approval;

}
/// @nodoc
class _$WorkspaceModelCopyWithImpl<$Res>
    implements $WorkspaceModelCopyWith<$Res> {
  _$WorkspaceModelCopyWithImpl(this._self, this._then);

  final WorkspaceModel _self;
  final $Res Function(WorkspaceModel) _then;

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,Object? activeIndex = null,Object? notices = null,Object? approval = freezed,Object? assistantBusy = null,Object? runningCommand = freezed,Object? snapEnabled = null,Object? ortho = null,Object? polar = null,Object? snapModes = null,Object? recentFiles = null,Object? lastCreatedIds = null,Object? lastModifiedIds = null,Object? collectedPointCount = null,}) {
  return _then(_self.copyWith(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<WorkspaceSessionModel>,activeIndex: null == activeIndex ? _self.activeIndex : activeIndex // ignore: cast_nullable_to_non_nullable
as int,notices: null == notices ? _self.notices : notices // ignore: cast_nullable_to_non_nullable
as List<NoticeModel>,approval: freezed == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalRequestModel?,assistantBusy: null == assistantBusy ? _self.assistantBusy : assistantBusy // ignore: cast_nullable_to_non_nullable
as bool,runningCommand: freezed == runningCommand ? _self.runningCommand : runningCommand // ignore: cast_nullable_to_non_nullable
as String?,snapEnabled: null == snapEnabled ? _self.snapEnabled : snapEnabled // ignore: cast_nullable_to_non_nullable
as bool,ortho: null == ortho ? _self.ortho : ortho // ignore: cast_nullable_to_non_nullable
as bool,polar: null == polar ? _self.polar : polar // ignore: cast_nullable_to_non_nullable
as bool,snapModes: null == snapModes ? _self.snapModes : snapModes // ignore: cast_nullable_to_non_nullable
as List<String>,recentFiles: null == recentFiles ? _self.recentFiles : recentFiles // ignore: cast_nullable_to_non_nullable
as List<String>,lastCreatedIds: null == lastCreatedIds ? _self.lastCreatedIds : lastCreatedIds // ignore: cast_nullable_to_non_nullable
as List<int>,lastModifiedIds: null == lastModifiedIds ? _self.lastModifiedIds : lastModifiedIds // ignore: cast_nullable_to_non_nullable
as List<int>,collectedPointCount: null == collectedPointCount ? _self.collectedPointCount : collectedPointCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalRequestModelCopyWith<$Res>? get approval {
    if (_self.approval == null) {
    return null;
  }

  return $ApprovalRequestModelCopyWith<$Res>(_self.approval!, (value) {
    return _then(_self.copyWith(approval: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceModel].
extension WorkspaceModelPatterns on WorkspaceModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceModel value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceModel value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<WorkspaceSessionModel> sessions,  int activeIndex,  List<NoticeModel> notices,  ApprovalRequestModel? approval,  bool assistantBusy,  String? runningCommand,  bool snapEnabled,  bool ortho,  bool polar,  List<String> snapModes,  List<String> recentFiles,  List<int> lastCreatedIds,  List<int> lastModifiedIds,  int collectedPointCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
return $default(_that.sessions,_that.activeIndex,_that.notices,_that.approval,_that.assistantBusy,_that.runningCommand,_that.snapEnabled,_that.ortho,_that.polar,_that.snapModes,_that.recentFiles,_that.lastCreatedIds,_that.lastModifiedIds,_that.collectedPointCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<WorkspaceSessionModel> sessions,  int activeIndex,  List<NoticeModel> notices,  ApprovalRequestModel? approval,  bool assistantBusy,  String? runningCommand,  bool snapEnabled,  bool ortho,  bool polar,  List<String> snapModes,  List<String> recentFiles,  List<int> lastCreatedIds,  List<int> lastModifiedIds,  int collectedPointCount)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceModel():
return $default(_that.sessions,_that.activeIndex,_that.notices,_that.approval,_that.assistantBusy,_that.runningCommand,_that.snapEnabled,_that.ortho,_that.polar,_that.snapModes,_that.recentFiles,_that.lastCreatedIds,_that.lastModifiedIds,_that.collectedPointCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<WorkspaceSessionModel> sessions,  int activeIndex,  List<NoticeModel> notices,  ApprovalRequestModel? approval,  bool assistantBusy,  String? runningCommand,  bool snapEnabled,  bool ortho,  bool polar,  List<String> snapModes,  List<String> recentFiles,  List<int> lastCreatedIds,  List<int> lastModifiedIds,  int collectedPointCount)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
return $default(_that.sessions,_that.activeIndex,_that.notices,_that.approval,_that.assistantBusy,_that.runningCommand,_that.snapEnabled,_that.ortho,_that.polar,_that.snapModes,_that.recentFiles,_that.lastCreatedIds,_that.lastModifiedIds,_that.collectedPointCount);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceModel extends WorkspaceModel {
  const _WorkspaceModel({final  List<WorkspaceSessionModel> sessions = const [], this.activeIndex = -1, final  List<NoticeModel> notices = const [], this.approval, this.assistantBusy = false, this.runningCommand, this.snapEnabled = true, this.ortho = false, this.polar = true, final  List<String> snapModes = const [], final  List<String> recentFiles = const [], final  List<int> lastCreatedIds = const [], final  List<int> lastModifiedIds = const [], this.collectedPointCount = 0}): _sessions = sessions,_notices = notices,_snapModes = snapModes,_recentFiles = recentFiles,_lastCreatedIds = lastCreatedIds,_lastModifiedIds = lastModifiedIds,super._();
  

 final  List<WorkspaceSessionModel> _sessions;
@override@JsonKey() List<WorkspaceSessionModel> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

@override@JsonKey() final  int activeIndex;
 final  List<NoticeModel> _notices;
@override@JsonKey() List<NoticeModel> get notices {
  if (_notices is EqualUnmodifiableListView) return _notices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notices);
}

@override final  ApprovalRequestModel? approval;
@override@JsonKey() final  bool assistantBusy;
@override final  String? runningCommand;
@override@JsonKey() final  bool snapEnabled;
@override@JsonKey() final  bool ortho;
@override@JsonKey() final  bool polar;
 final  List<String> _snapModes;
@override@JsonKey() List<String> get snapModes {
  if (_snapModes is EqualUnmodifiableListView) return _snapModes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_snapModes);
}

 final  List<String> _recentFiles;
@override@JsonKey() List<String> get recentFiles {
  if (_recentFiles is EqualUnmodifiableListView) return _recentFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentFiles);
}

 final  List<int> _lastCreatedIds;
@override@JsonKey() List<int> get lastCreatedIds {
  if (_lastCreatedIds is EqualUnmodifiableListView) return _lastCreatedIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lastCreatedIds);
}

 final  List<int> _lastModifiedIds;
@override@JsonKey() List<int> get lastModifiedIds {
  if (_lastModifiedIds is EqualUnmodifiableListView) return _lastModifiedIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lastModifiedIds);
}

@override@JsonKey() final  int collectedPointCount;

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceModelCopyWith<_WorkspaceModel> get copyWith => __$WorkspaceModelCopyWithImpl<_WorkspaceModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceModel&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.activeIndex, activeIndex) || other.activeIndex == activeIndex)&&const DeepCollectionEquality().equals(other._notices, _notices)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.assistantBusy, assistantBusy) || other.assistantBusy == assistantBusy)&&(identical(other.runningCommand, runningCommand) || other.runningCommand == runningCommand)&&(identical(other.snapEnabled, snapEnabled) || other.snapEnabled == snapEnabled)&&(identical(other.ortho, ortho) || other.ortho == ortho)&&(identical(other.polar, polar) || other.polar == polar)&&const DeepCollectionEquality().equals(other._snapModes, _snapModes)&&const DeepCollectionEquality().equals(other._recentFiles, _recentFiles)&&const DeepCollectionEquality().equals(other._lastCreatedIds, _lastCreatedIds)&&const DeepCollectionEquality().equals(other._lastModifiedIds, _lastModifiedIds)&&(identical(other.collectedPointCount, collectedPointCount) || other.collectedPointCount == collectedPointCount));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),activeIndex,const DeepCollectionEquality().hash(_notices),approval,assistantBusy,runningCommand,snapEnabled,ortho,polar,const DeepCollectionEquality().hash(_snapModes),const DeepCollectionEquality().hash(_recentFiles),const DeepCollectionEquality().hash(_lastCreatedIds),const DeepCollectionEquality().hash(_lastModifiedIds),collectedPointCount);

@override
String toString() {
  return 'WorkspaceModel(sessions: $sessions, activeIndex: $activeIndex, notices: $notices, approval: $approval, assistantBusy: $assistantBusy, runningCommand: $runningCommand, snapEnabled: $snapEnabled, ortho: $ortho, polar: $polar, snapModes: $snapModes, recentFiles: $recentFiles, lastCreatedIds: $lastCreatedIds, lastModifiedIds: $lastModifiedIds, collectedPointCount: $collectedPointCount)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceModelCopyWith<$Res> implements $WorkspaceModelCopyWith<$Res> {
  factory _$WorkspaceModelCopyWith(_WorkspaceModel value, $Res Function(_WorkspaceModel) _then) = __$WorkspaceModelCopyWithImpl;
@override @useResult
$Res call({
 List<WorkspaceSessionModel> sessions, int activeIndex, List<NoticeModel> notices, ApprovalRequestModel? approval, bool assistantBusy, String? runningCommand, bool snapEnabled, bool ortho, bool polar, List<String> snapModes, List<String> recentFiles, List<int> lastCreatedIds, List<int> lastModifiedIds, int collectedPointCount
});


@override $ApprovalRequestModelCopyWith<$Res>? get approval;

}
/// @nodoc
class __$WorkspaceModelCopyWithImpl<$Res>
    implements _$WorkspaceModelCopyWith<$Res> {
  __$WorkspaceModelCopyWithImpl(this._self, this._then);

  final _WorkspaceModel _self;
  final $Res Function(_WorkspaceModel) _then;

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? activeIndex = null,Object? notices = null,Object? approval = freezed,Object? assistantBusy = null,Object? runningCommand = freezed,Object? snapEnabled = null,Object? ortho = null,Object? polar = null,Object? snapModes = null,Object? recentFiles = null,Object? lastCreatedIds = null,Object? lastModifiedIds = null,Object? collectedPointCount = null,}) {
  return _then(_WorkspaceModel(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<WorkspaceSessionModel>,activeIndex: null == activeIndex ? _self.activeIndex : activeIndex // ignore: cast_nullable_to_non_nullable
as int,notices: null == notices ? _self._notices : notices // ignore: cast_nullable_to_non_nullable
as List<NoticeModel>,approval: freezed == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalRequestModel?,assistantBusy: null == assistantBusy ? _self.assistantBusy : assistantBusy // ignore: cast_nullable_to_non_nullable
as bool,runningCommand: freezed == runningCommand ? _self.runningCommand : runningCommand // ignore: cast_nullable_to_non_nullable
as String?,snapEnabled: null == snapEnabled ? _self.snapEnabled : snapEnabled // ignore: cast_nullable_to_non_nullable
as bool,ortho: null == ortho ? _self.ortho : ortho // ignore: cast_nullable_to_non_nullable
as bool,polar: null == polar ? _self.polar : polar // ignore: cast_nullable_to_non_nullable
as bool,snapModes: null == snapModes ? _self._snapModes : snapModes // ignore: cast_nullable_to_non_nullable
as List<String>,recentFiles: null == recentFiles ? _self._recentFiles : recentFiles // ignore: cast_nullable_to_non_nullable
as List<String>,lastCreatedIds: null == lastCreatedIds ? _self._lastCreatedIds : lastCreatedIds // ignore: cast_nullable_to_non_nullable
as List<int>,lastModifiedIds: null == lastModifiedIds ? _self._lastModifiedIds : lastModifiedIds // ignore: cast_nullable_to_non_nullable
as List<int>,collectedPointCount: null == collectedPointCount ? _self.collectedPointCount : collectedPointCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalRequestModelCopyWith<$Res>? get approval {
    if (_self.approval == null) {
    return null;
  }

  return $ApprovalRequestModelCopyWith<$Res>(_self.approval!, (value) {
    return _then(_self.copyWith(approval: value));
  });
}
}

/// @nodoc
mixin _$WorkspaceSessionsModel {

 List<WorkspaceTabRefModel> get sessions; int get activeIndex;
/// Create a copy of WorkspaceSessionsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceSessionsModelCopyWith<WorkspaceSessionsModel> get copyWith => _$WorkspaceSessionsModelCopyWithImpl<WorkspaceSessionsModel>(this as WorkspaceSessionsModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceSessionsModel&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.activeIndex, activeIndex) || other.activeIndex == activeIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions),activeIndex);

@override
String toString() {
  return 'WorkspaceSessionsModel(sessions: $sessions, activeIndex: $activeIndex)';
}


}

/// @nodoc
abstract mixin class $WorkspaceSessionsModelCopyWith<$Res>  {
  factory $WorkspaceSessionsModelCopyWith(WorkspaceSessionsModel value, $Res Function(WorkspaceSessionsModel) _then) = _$WorkspaceSessionsModelCopyWithImpl;
@useResult
$Res call({
 List<WorkspaceTabRefModel> sessions, int activeIndex
});




}
/// @nodoc
class _$WorkspaceSessionsModelCopyWithImpl<$Res>
    implements $WorkspaceSessionsModelCopyWith<$Res> {
  _$WorkspaceSessionsModelCopyWithImpl(this._self, this._then);

  final WorkspaceSessionsModel _self;
  final $Res Function(WorkspaceSessionsModel) _then;

/// Create a copy of WorkspaceSessionsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,Object? activeIndex = null,}) {
  return _then(_self.copyWith(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<WorkspaceTabRefModel>,activeIndex: null == activeIndex ? _self.activeIndex : activeIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceSessionsModel].
extension WorkspaceSessionsModelPatterns on WorkspaceSessionsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceSessionsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceSessionsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceSessionsModel value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceSessionsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceSessionsModel value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceSessionsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<WorkspaceTabRefModel> sessions,  int activeIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceSessionsModel() when $default != null:
return $default(_that.sessions,_that.activeIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<WorkspaceTabRefModel> sessions,  int activeIndex)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceSessionsModel():
return $default(_that.sessions,_that.activeIndex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<WorkspaceTabRefModel> sessions,  int activeIndex)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceSessionsModel() when $default != null:
return $default(_that.sessions,_that.activeIndex);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceSessionsModel implements WorkspaceSessionsModel {
  const _WorkspaceSessionsModel({final  List<WorkspaceTabRefModel> sessions = const [], this.activeIndex = -1}): _sessions = sessions;
  

 final  List<WorkspaceTabRefModel> _sessions;
@override@JsonKey() List<WorkspaceTabRefModel> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

@override@JsonKey() final  int activeIndex;

/// Create a copy of WorkspaceSessionsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceSessionsModelCopyWith<_WorkspaceSessionsModel> get copyWith => __$WorkspaceSessionsModelCopyWithImpl<_WorkspaceSessionsModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceSessionsModel&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.activeIndex, activeIndex) || other.activeIndex == activeIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),activeIndex);

@override
String toString() {
  return 'WorkspaceSessionsModel(sessions: $sessions, activeIndex: $activeIndex)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceSessionsModelCopyWith<$Res> implements $WorkspaceSessionsModelCopyWith<$Res> {
  factory _$WorkspaceSessionsModelCopyWith(_WorkspaceSessionsModel value, $Res Function(_WorkspaceSessionsModel) _then) = __$WorkspaceSessionsModelCopyWithImpl;
@override @useResult
$Res call({
 List<WorkspaceTabRefModel> sessions, int activeIndex
});




}
/// @nodoc
class __$WorkspaceSessionsModelCopyWithImpl<$Res>
    implements _$WorkspaceSessionsModelCopyWith<$Res> {
  __$WorkspaceSessionsModelCopyWithImpl(this._self, this._then);

  final _WorkspaceSessionsModel _self;
  final $Res Function(_WorkspaceSessionsModel) _then;

/// Create a copy of WorkspaceSessionsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? activeIndex = null,}) {
  return _then(_WorkspaceSessionsModel(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<WorkspaceTabRefModel>,activeIndex: null == activeIndex ? _self.activeIndex : activeIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$WorkspaceTabRefModel {

 String get id; bool get isStartPage; String get title; bool get isDirty; int get diagnosticCount;
/// Create a copy of WorkspaceTabRefModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceTabRefModelCopyWith<WorkspaceTabRefModel> get copyWith => _$WorkspaceTabRefModelCopyWithImpl<WorkspaceTabRefModel>(this as WorkspaceTabRefModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceTabRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.isStartPage, isStartPage) || other.isStartPage == isStartPage)&&(identical(other.title, title) || other.title == title)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.diagnosticCount, diagnosticCount) || other.diagnosticCount == diagnosticCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,isStartPage,title,isDirty,diagnosticCount);

@override
String toString() {
  return 'WorkspaceTabRefModel(id: $id, isStartPage: $isStartPage, title: $title, isDirty: $isDirty, diagnosticCount: $diagnosticCount)';
}


}

/// @nodoc
abstract mixin class $WorkspaceTabRefModelCopyWith<$Res>  {
  factory $WorkspaceTabRefModelCopyWith(WorkspaceTabRefModel value, $Res Function(WorkspaceTabRefModel) _then) = _$WorkspaceTabRefModelCopyWithImpl;
@useResult
$Res call({
 String id, bool isStartPage, String title, bool isDirty, int diagnosticCount
});




}
/// @nodoc
class _$WorkspaceTabRefModelCopyWithImpl<$Res>
    implements $WorkspaceTabRefModelCopyWith<$Res> {
  _$WorkspaceTabRefModelCopyWithImpl(this._self, this._then);

  final WorkspaceTabRefModel _self;
  final $Res Function(WorkspaceTabRefModel) _then;

/// Create a copy of WorkspaceTabRefModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? isStartPage = null,Object? title = null,Object? isDirty = null,Object? diagnosticCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isStartPage: null == isStartPage ? _self.isStartPage : isStartPage // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,diagnosticCount: null == diagnosticCount ? _self.diagnosticCount : diagnosticCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceTabRefModel].
extension WorkspaceTabRefModelPatterns on WorkspaceTabRefModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceTabRefModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceTabRefModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceTabRefModel value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceTabRefModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceTabRefModel value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceTabRefModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool isStartPage,  String title,  bool isDirty,  int diagnosticCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceTabRefModel() when $default != null:
return $default(_that.id,_that.isStartPage,_that.title,_that.isDirty,_that.diagnosticCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool isStartPage,  String title,  bool isDirty,  int diagnosticCount)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceTabRefModel():
return $default(_that.id,_that.isStartPage,_that.title,_that.isDirty,_that.diagnosticCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool isStartPage,  String title,  bool isDirty,  int diagnosticCount)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceTabRefModel() when $default != null:
return $default(_that.id,_that.isStartPage,_that.title,_that.isDirty,_that.diagnosticCount);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceTabRefModel implements WorkspaceTabRefModel {
  const _WorkspaceTabRefModel({required this.id, this.isStartPage = false, this.title = '', this.isDirty = false, this.diagnosticCount = 0});
  

@override final  String id;
@override@JsonKey() final  bool isStartPage;
@override@JsonKey() final  String title;
@override@JsonKey() final  bool isDirty;
@override@JsonKey() final  int diagnosticCount;

/// Create a copy of WorkspaceTabRefModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceTabRefModelCopyWith<_WorkspaceTabRefModel> get copyWith => __$WorkspaceTabRefModelCopyWithImpl<_WorkspaceTabRefModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceTabRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.isStartPage, isStartPage) || other.isStartPage == isStartPage)&&(identical(other.title, title) || other.title == title)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.diagnosticCount, diagnosticCount) || other.diagnosticCount == diagnosticCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,isStartPage,title,isDirty,diagnosticCount);

@override
String toString() {
  return 'WorkspaceTabRefModel(id: $id, isStartPage: $isStartPage, title: $title, isDirty: $isDirty, diagnosticCount: $diagnosticCount)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceTabRefModelCopyWith<$Res> implements $WorkspaceTabRefModelCopyWith<$Res> {
  factory _$WorkspaceTabRefModelCopyWith(_WorkspaceTabRefModel value, $Res Function(_WorkspaceTabRefModel) _then) = __$WorkspaceTabRefModelCopyWithImpl;
@override @useResult
$Res call({
 String id, bool isStartPage, String title, bool isDirty, int diagnosticCount
});




}
/// @nodoc
class __$WorkspaceTabRefModelCopyWithImpl<$Res>
    implements _$WorkspaceTabRefModelCopyWith<$Res> {
  __$WorkspaceTabRefModelCopyWithImpl(this._self, this._then);

  final _WorkspaceTabRefModel _self;
  final $Res Function(_WorkspaceTabRefModel) _then;

/// Create a copy of WorkspaceTabRefModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? isStartPage = null,Object? title = null,Object? isDirty = null,Object? diagnosticCount = null,}) {
  return _then(_WorkspaceTabRefModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isStartPage: null == isStartPage ? _self.isStartPage : isStartPage // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,diagnosticCount: null == diagnosticCount ? _self.diagnosticCount : diagnosticCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$WorkspaceSessionModel {

 String get id; bool get isStartPage; String get title; bool get isDirty; bool get showGrid; Set<String>? get isolatedLayers; List<String> get diagnostics; List<int> get heldIds; List<int> get flashIds; List<int> get hoverIds;
/// Create a copy of WorkspaceSessionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceSessionModelCopyWith<WorkspaceSessionModel> get copyWith => _$WorkspaceSessionModelCopyWithImpl<WorkspaceSessionModel>(this as WorkspaceSessionModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceSessionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.isStartPage, isStartPage) || other.isStartPage == isStartPage)&&(identical(other.title, title) || other.title == title)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.showGrid, showGrid) || other.showGrid == showGrid)&&const DeepCollectionEquality().equals(other.isolatedLayers, isolatedLayers)&&const DeepCollectionEquality().equals(other.diagnostics, diagnostics)&&const DeepCollectionEquality().equals(other.heldIds, heldIds)&&const DeepCollectionEquality().equals(other.flashIds, flashIds)&&const DeepCollectionEquality().equals(other.hoverIds, hoverIds));
}


@override
int get hashCode => Object.hash(runtimeType,id,isStartPage,title,isDirty,showGrid,const DeepCollectionEquality().hash(isolatedLayers),const DeepCollectionEquality().hash(diagnostics),const DeepCollectionEquality().hash(heldIds),const DeepCollectionEquality().hash(flashIds),const DeepCollectionEquality().hash(hoverIds));

@override
String toString() {
  return 'WorkspaceSessionModel(id: $id, isStartPage: $isStartPage, title: $title, isDirty: $isDirty, showGrid: $showGrid, isolatedLayers: $isolatedLayers, diagnostics: $diagnostics, heldIds: $heldIds, flashIds: $flashIds, hoverIds: $hoverIds)';
}


}

/// @nodoc
abstract mixin class $WorkspaceSessionModelCopyWith<$Res>  {
  factory $WorkspaceSessionModelCopyWith(WorkspaceSessionModel value, $Res Function(WorkspaceSessionModel) _then) = _$WorkspaceSessionModelCopyWithImpl;
@useResult
$Res call({
 String id, bool isStartPage, String title, bool isDirty, bool showGrid, Set<String>? isolatedLayers, List<String> diagnostics, List<int> heldIds, List<int> flashIds, List<int> hoverIds
});




}
/// @nodoc
class _$WorkspaceSessionModelCopyWithImpl<$Res>
    implements $WorkspaceSessionModelCopyWith<$Res> {
  _$WorkspaceSessionModelCopyWithImpl(this._self, this._then);

  final WorkspaceSessionModel _self;
  final $Res Function(WorkspaceSessionModel) _then;

/// Create a copy of WorkspaceSessionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? isStartPage = null,Object? title = null,Object? isDirty = null,Object? showGrid = null,Object? isolatedLayers = freezed,Object? diagnostics = null,Object? heldIds = null,Object? flashIds = null,Object? hoverIds = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isStartPage: null == isStartPage ? _self.isStartPage : isStartPage // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,showGrid: null == showGrid ? _self.showGrid : showGrid // ignore: cast_nullable_to_non_nullable
as bool,isolatedLayers: freezed == isolatedLayers ? _self.isolatedLayers : isolatedLayers // ignore: cast_nullable_to_non_nullable
as Set<String>?,diagnostics: null == diagnostics ? _self.diagnostics : diagnostics // ignore: cast_nullable_to_non_nullable
as List<String>,heldIds: null == heldIds ? _self.heldIds : heldIds // ignore: cast_nullable_to_non_nullable
as List<int>,flashIds: null == flashIds ? _self.flashIds : flashIds // ignore: cast_nullable_to_non_nullable
as List<int>,hoverIds: null == hoverIds ? _self.hoverIds : hoverIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceSessionModel].
extension WorkspaceSessionModelPatterns on WorkspaceSessionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceSessionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceSessionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceSessionModel value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceSessionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceSessionModel value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceSessionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool isStartPage,  String title,  bool isDirty,  bool showGrid,  Set<String>? isolatedLayers,  List<String> diagnostics,  List<int> heldIds,  List<int> flashIds,  List<int> hoverIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceSessionModel() when $default != null:
return $default(_that.id,_that.isStartPage,_that.title,_that.isDirty,_that.showGrid,_that.isolatedLayers,_that.diagnostics,_that.heldIds,_that.flashIds,_that.hoverIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool isStartPage,  String title,  bool isDirty,  bool showGrid,  Set<String>? isolatedLayers,  List<String> diagnostics,  List<int> heldIds,  List<int> flashIds,  List<int> hoverIds)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceSessionModel():
return $default(_that.id,_that.isStartPage,_that.title,_that.isDirty,_that.showGrid,_that.isolatedLayers,_that.diagnostics,_that.heldIds,_that.flashIds,_that.hoverIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool isStartPage,  String title,  bool isDirty,  bool showGrid,  Set<String>? isolatedLayers,  List<String> diagnostics,  List<int> heldIds,  List<int> flashIds,  List<int> hoverIds)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceSessionModel() when $default != null:
return $default(_that.id,_that.isStartPage,_that.title,_that.isDirty,_that.showGrid,_that.isolatedLayers,_that.diagnostics,_that.heldIds,_that.flashIds,_that.hoverIds);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceSessionModel implements WorkspaceSessionModel {
  const _WorkspaceSessionModel({required this.id, this.isStartPage = false, this.title = '', this.isDirty = false, this.showGrid = true, final  Set<String>? isolatedLayers, final  List<String> diagnostics = const [], final  List<int> heldIds = const [], final  List<int> flashIds = const [], final  List<int> hoverIds = const []}): _isolatedLayers = isolatedLayers,_diagnostics = diagnostics,_heldIds = heldIds,_flashIds = flashIds,_hoverIds = hoverIds;
  

@override final  String id;
@override@JsonKey() final  bool isStartPage;
@override@JsonKey() final  String title;
@override@JsonKey() final  bool isDirty;
@override@JsonKey() final  bool showGrid;
 final  Set<String>? _isolatedLayers;
@override Set<String>? get isolatedLayers {
  final value = _isolatedLayers;
  if (value == null) return null;
  if (_isolatedLayers is EqualUnmodifiableSetView) return _isolatedLayers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(value);
}

 final  List<String> _diagnostics;
@override@JsonKey() List<String> get diagnostics {
  if (_diagnostics is EqualUnmodifiableListView) return _diagnostics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diagnostics);
}

 final  List<int> _heldIds;
@override@JsonKey() List<int> get heldIds {
  if (_heldIds is EqualUnmodifiableListView) return _heldIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_heldIds);
}

 final  List<int> _flashIds;
@override@JsonKey() List<int> get flashIds {
  if (_flashIds is EqualUnmodifiableListView) return _flashIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flashIds);
}

 final  List<int> _hoverIds;
@override@JsonKey() List<int> get hoverIds {
  if (_hoverIds is EqualUnmodifiableListView) return _hoverIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hoverIds);
}


/// Create a copy of WorkspaceSessionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceSessionModelCopyWith<_WorkspaceSessionModel> get copyWith => __$WorkspaceSessionModelCopyWithImpl<_WorkspaceSessionModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceSessionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.isStartPage, isStartPage) || other.isStartPage == isStartPage)&&(identical(other.title, title) || other.title == title)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.showGrid, showGrid) || other.showGrid == showGrid)&&const DeepCollectionEquality().equals(other._isolatedLayers, _isolatedLayers)&&const DeepCollectionEquality().equals(other._diagnostics, _diagnostics)&&const DeepCollectionEquality().equals(other._heldIds, _heldIds)&&const DeepCollectionEquality().equals(other._flashIds, _flashIds)&&const DeepCollectionEquality().equals(other._hoverIds, _hoverIds));
}


@override
int get hashCode => Object.hash(runtimeType,id,isStartPage,title,isDirty,showGrid,const DeepCollectionEquality().hash(_isolatedLayers),const DeepCollectionEquality().hash(_diagnostics),const DeepCollectionEquality().hash(_heldIds),const DeepCollectionEquality().hash(_flashIds),const DeepCollectionEquality().hash(_hoverIds));

@override
String toString() {
  return 'WorkspaceSessionModel(id: $id, isStartPage: $isStartPage, title: $title, isDirty: $isDirty, showGrid: $showGrid, isolatedLayers: $isolatedLayers, diagnostics: $diagnostics, heldIds: $heldIds, flashIds: $flashIds, hoverIds: $hoverIds)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceSessionModelCopyWith<$Res> implements $WorkspaceSessionModelCopyWith<$Res> {
  factory _$WorkspaceSessionModelCopyWith(_WorkspaceSessionModel value, $Res Function(_WorkspaceSessionModel) _then) = __$WorkspaceSessionModelCopyWithImpl;
@override @useResult
$Res call({
 String id, bool isStartPage, String title, bool isDirty, bool showGrid, Set<String>? isolatedLayers, List<String> diagnostics, List<int> heldIds, List<int> flashIds, List<int> hoverIds
});




}
/// @nodoc
class __$WorkspaceSessionModelCopyWithImpl<$Res>
    implements _$WorkspaceSessionModelCopyWith<$Res> {
  __$WorkspaceSessionModelCopyWithImpl(this._self, this._then);

  final _WorkspaceSessionModel _self;
  final $Res Function(_WorkspaceSessionModel) _then;

/// Create a copy of WorkspaceSessionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? isStartPage = null,Object? title = null,Object? isDirty = null,Object? showGrid = null,Object? isolatedLayers = freezed,Object? diagnostics = null,Object? heldIds = null,Object? flashIds = null,Object? hoverIds = null,}) {
  return _then(_WorkspaceSessionModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isStartPage: null == isStartPage ? _self.isStartPage : isStartPage // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,showGrid: null == showGrid ? _self.showGrid : showGrid // ignore: cast_nullable_to_non_nullable
as bool,isolatedLayers: freezed == isolatedLayers ? _self._isolatedLayers : isolatedLayers // ignore: cast_nullable_to_non_nullable
as Set<String>?,diagnostics: null == diagnostics ? _self._diagnostics : diagnostics // ignore: cast_nullable_to_non_nullable
as List<String>,heldIds: null == heldIds ? _self._heldIds : heldIds // ignore: cast_nullable_to_non_nullable
as List<int>,flashIds: null == flashIds ? _self._flashIds : flashIds // ignore: cast_nullable_to_non_nullable
as List<int>,hoverIds: null == hoverIds ? _self._hoverIds : hoverIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

/// @nodoc
mixin _$CommandLineModel {

 List<HistoryLineModel> get lines; CommandPromptModel? get prompt; String get status; String? get offeredInput; List<String> get entered;
/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandLineModelCopyWith<CommandLineModel> get copyWith => _$CommandLineModelCopyWithImpl<CommandLineModel>(this as CommandLineModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandLineModel&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.status, status) || other.status == status)&&(identical(other.offeredInput, offeredInput) || other.offeredInput == offeredInput)&&const DeepCollectionEquality().equals(other.entered, entered));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(lines),prompt,status,offeredInput,const DeepCollectionEquality().hash(entered));

@override
String toString() {
  return 'CommandLineModel(lines: $lines, prompt: $prompt, status: $status, offeredInput: $offeredInput, entered: $entered)';
}


}

/// @nodoc
abstract mixin class $CommandLineModelCopyWith<$Res>  {
  factory $CommandLineModelCopyWith(CommandLineModel value, $Res Function(CommandLineModel) _then) = _$CommandLineModelCopyWithImpl;
@useResult
$Res call({
 List<HistoryLineModel> lines, CommandPromptModel? prompt, String status, String? offeredInput, List<String> entered
});


$CommandPromptModelCopyWith<$Res>? get prompt;

}
/// @nodoc
class _$CommandLineModelCopyWithImpl<$Res>
    implements $CommandLineModelCopyWith<$Res> {
  _$CommandLineModelCopyWithImpl(this._self, this._then);

  final CommandLineModel _self;
  final $Res Function(CommandLineModel) _then;

/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lines = null,Object? prompt = freezed,Object? status = null,Object? offeredInput = freezed,Object? entered = null,}) {
  return _then(_self.copyWith(
lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<HistoryLineModel>,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as CommandPromptModel?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,offeredInput: freezed == offeredInput ? _self.offeredInput : offeredInput // ignore: cast_nullable_to_non_nullable
as String?,entered: null == entered ? _self.entered : entered // ignore: cast_nullable_to_non_nullable
as List<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<HistoryLineModel> lines,  CommandPromptModel? prompt,  String status,  String? offeredInput,  List<String> entered)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandLineModel() when $default != null:
return $default(_that.lines,_that.prompt,_that.status,_that.offeredInput,_that.entered);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<HistoryLineModel> lines,  CommandPromptModel? prompt,  String status,  String? offeredInput,  List<String> entered)  $default,) {final _that = this;
switch (_that) {
case _CommandLineModel():
return $default(_that.lines,_that.prompt,_that.status,_that.offeredInput,_that.entered);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<HistoryLineModel> lines,  CommandPromptModel? prompt,  String status,  String? offeredInput,  List<String> entered)?  $default,) {final _that = this;
switch (_that) {
case _CommandLineModel() when $default != null:
return $default(_that.lines,_that.prompt,_that.status,_that.offeredInput,_that.entered);case _:
  return null;

}
}

}

/// @nodoc


class _CommandLineModel implements CommandLineModel {
  const _CommandLineModel({final  List<HistoryLineModel> lines = const [], this.prompt, this.status = '', this.offeredInput, final  List<String> entered = const []}): _lines = lines,_entered = entered;
  

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


/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandLineModelCopyWith<_CommandLineModel> get copyWith => __$CommandLineModelCopyWithImpl<_CommandLineModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandLineModel&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.status, status) || other.status == status)&&(identical(other.offeredInput, offeredInput) || other.offeredInput == offeredInput)&&const DeepCollectionEquality().equals(other._entered, _entered));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_lines),prompt,status,offeredInput,const DeepCollectionEquality().hash(_entered));

@override
String toString() {
  return 'CommandLineModel(lines: $lines, prompt: $prompt, status: $status, offeredInput: $offeredInput, entered: $entered)';
}


}

/// @nodoc
abstract mixin class _$CommandLineModelCopyWith<$Res> implements $CommandLineModelCopyWith<$Res> {
  factory _$CommandLineModelCopyWith(_CommandLineModel value, $Res Function(_CommandLineModel) _then) = __$CommandLineModelCopyWithImpl;
@override @useResult
$Res call({
 List<HistoryLineModel> lines, CommandPromptModel? prompt, String status, String? offeredInput, List<String> entered
});


@override $CommandPromptModelCopyWith<$Res>? get prompt;

}
/// @nodoc
class __$CommandLineModelCopyWithImpl<$Res>
    implements _$CommandLineModelCopyWith<$Res> {
  __$CommandLineModelCopyWithImpl(this._self, this._then);

  final _CommandLineModel _self;
  final $Res Function(_CommandLineModel) _then;

/// Create a copy of CommandLineModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lines = null,Object? prompt = freezed,Object? status = null,Object? offeredInput = freezed,Object? entered = null,}) {
  return _then(_CommandLineModel(
lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<HistoryLineModel>,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as CommandPromptModel?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,offeredInput: freezed == offeredInput ? _self.offeredInput : offeredInput // ignore: cast_nullable_to_non_nullable
as String?,entered: null == entered ? _self._entered : entered // ignore: cast_nullable_to_non_nullable
as List<String>,
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
}
}

/// @nodoc
mixin _$NoticeModel {

 String get message; bool get isError; DateTime get at;
/// Create a copy of NoticeModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoticeModelCopyWith<NoticeModel> get copyWith => _$NoticeModelCopyWithImpl<NoticeModel>(this as NoticeModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NoticeModel&&(identical(other.message, message) || other.message == message)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.at, at) || other.at == at));
}


@override
int get hashCode => Object.hash(runtimeType,message,isError,at);

@override
String toString() {
  return 'NoticeModel(message: $message, isError: $isError, at: $at)';
}


}

/// @nodoc
abstract mixin class $NoticeModelCopyWith<$Res>  {
  factory $NoticeModelCopyWith(NoticeModel value, $Res Function(NoticeModel) _then) = _$NoticeModelCopyWithImpl;
@useResult
$Res call({
 String message, bool isError, DateTime at
});




}
/// @nodoc
class _$NoticeModelCopyWithImpl<$Res>
    implements $NoticeModelCopyWith<$Res> {
  _$NoticeModelCopyWithImpl(this._self, this._then);

  final NoticeModel _self;
  final $Res Function(NoticeModel) _then;

/// Create a copy of NoticeModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? isError = null,Object? at = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [NoticeModel].
extension NoticeModelPatterns on NoticeModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NoticeModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NoticeModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NoticeModel value)  $default,){
final _that = this;
switch (_that) {
case _NoticeModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NoticeModel value)?  $default,){
final _that = this;
switch (_that) {
case _NoticeModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  bool isError,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NoticeModel() when $default != null:
return $default(_that.message,_that.isError,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  bool isError,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _NoticeModel():
return $default(_that.message,_that.isError,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  bool isError,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _NoticeModel() when $default != null:
return $default(_that.message,_that.isError,_that.at);case _:
  return null;

}
}

}

/// @nodoc


class _NoticeModel implements NoticeModel {
  const _NoticeModel(this.message, {this.isError = false, required this.at});
  

@override final  String message;
@override@JsonKey() final  bool isError;
@override final  DateTime at;

/// Create a copy of NoticeModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NoticeModelCopyWith<_NoticeModel> get copyWith => __$NoticeModelCopyWithImpl<_NoticeModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NoticeModel&&(identical(other.message, message) || other.message == message)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.at, at) || other.at == at));
}


@override
int get hashCode => Object.hash(runtimeType,message,isError,at);

@override
String toString() {
  return 'NoticeModel(message: $message, isError: $isError, at: $at)';
}


}

/// @nodoc
abstract mixin class _$NoticeModelCopyWith<$Res> implements $NoticeModelCopyWith<$Res> {
  factory _$NoticeModelCopyWith(_NoticeModel value, $Res Function(_NoticeModel) _then) = __$NoticeModelCopyWithImpl;
@override @useResult
$Res call({
 String message, bool isError, DateTime at
});




}
/// @nodoc
class __$NoticeModelCopyWithImpl<$Res>
    implements _$NoticeModelCopyWith<$Res> {
  __$NoticeModelCopyWithImpl(this._self, this._then);

  final _NoticeModel _self;
  final $Res Function(_NoticeModel) _then;

/// Create a copy of NoticeModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? isError = null,Object? at = null,}) {
  return _then(_NoticeModel(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$ApprovalRequestModel {

 String get title; String get details;/// Entities the change would touch, highlighted on the canvas while the user
/// decides. Seeing what is about to change is most of what makes an approval
/// gate worth having.
 List<int> get highlightIds;
/// Create a copy of ApprovalRequestModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalRequestModelCopyWith<ApprovalRequestModel> get copyWith => _$ApprovalRequestModelCopyWithImpl<ApprovalRequestModel>(this as ApprovalRequestModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalRequestModel&&(identical(other.title, title) || other.title == title)&&(identical(other.details, details) || other.details == details)&&const DeepCollectionEquality().equals(other.highlightIds, highlightIds));
}


@override
int get hashCode => Object.hash(runtimeType,title,details,const DeepCollectionEquality().hash(highlightIds));

@override
String toString() {
  return 'ApprovalRequestModel(title: $title, details: $details, highlightIds: $highlightIds)';
}


}

/// @nodoc
abstract mixin class $ApprovalRequestModelCopyWith<$Res>  {
  factory $ApprovalRequestModelCopyWith(ApprovalRequestModel value, $Res Function(ApprovalRequestModel) _then) = _$ApprovalRequestModelCopyWithImpl;
@useResult
$Res call({
 String title, String details, List<int> highlightIds
});




}
/// @nodoc
class _$ApprovalRequestModelCopyWithImpl<$Res>
    implements $ApprovalRequestModelCopyWith<$Res> {
  _$ApprovalRequestModelCopyWithImpl(this._self, this._then);

  final ApprovalRequestModel _self;
  final $Res Function(ApprovalRequestModel) _then;

/// Create a copy of ApprovalRequestModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? details = null,Object? highlightIds = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String,highlightIds: null == highlightIds ? _self.highlightIds : highlightIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ApprovalRequestModel].
extension ApprovalRequestModelPatterns on ApprovalRequestModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApprovalRequestModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApprovalRequestModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApprovalRequestModel value)  $default,){
final _that = this;
switch (_that) {
case _ApprovalRequestModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApprovalRequestModel value)?  $default,){
final _that = this;
switch (_that) {
case _ApprovalRequestModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String details,  List<int> highlightIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApprovalRequestModel() when $default != null:
return $default(_that.title,_that.details,_that.highlightIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String details,  List<int> highlightIds)  $default,) {final _that = this;
switch (_that) {
case _ApprovalRequestModel():
return $default(_that.title,_that.details,_that.highlightIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String details,  List<int> highlightIds)?  $default,) {final _that = this;
switch (_that) {
case _ApprovalRequestModel() when $default != null:
return $default(_that.title,_that.details,_that.highlightIds);case _:
  return null;

}
}

}

/// @nodoc


class _ApprovalRequestModel implements ApprovalRequestModel {
  const _ApprovalRequestModel({required this.title, required this.details, final  List<int> highlightIds = const []}): _highlightIds = highlightIds;
  

@override final  String title;
@override final  String details;
/// Entities the change would touch, highlighted on the canvas while the user
/// decides. Seeing what is about to change is most of what makes an approval
/// gate worth having.
 final  List<int> _highlightIds;
/// Entities the change would touch, highlighted on the canvas while the user
/// decides. Seeing what is about to change is most of what makes an approval
/// gate worth having.
@override@JsonKey() List<int> get highlightIds {
  if (_highlightIds is EqualUnmodifiableListView) return _highlightIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_highlightIds);
}


/// Create a copy of ApprovalRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApprovalRequestModelCopyWith<_ApprovalRequestModel> get copyWith => __$ApprovalRequestModelCopyWithImpl<_ApprovalRequestModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApprovalRequestModel&&(identical(other.title, title) || other.title == title)&&(identical(other.details, details) || other.details == details)&&const DeepCollectionEquality().equals(other._highlightIds, _highlightIds));
}


@override
int get hashCode => Object.hash(runtimeType,title,details,const DeepCollectionEquality().hash(_highlightIds));

@override
String toString() {
  return 'ApprovalRequestModel(title: $title, details: $details, highlightIds: $highlightIds)';
}


}

/// @nodoc
abstract mixin class _$ApprovalRequestModelCopyWith<$Res> implements $ApprovalRequestModelCopyWith<$Res> {
  factory _$ApprovalRequestModelCopyWith(_ApprovalRequestModel value, $Res Function(_ApprovalRequestModel) _then) = __$ApprovalRequestModelCopyWithImpl;
@override @useResult
$Res call({
 String title, String details, List<int> highlightIds
});




}
/// @nodoc
class __$ApprovalRequestModelCopyWithImpl<$Res>
    implements _$ApprovalRequestModelCopyWith<$Res> {
  __$ApprovalRequestModelCopyWithImpl(this._self, this._then);

  final _ApprovalRequestModel _self;
  final $Res Function(_ApprovalRequestModel) _then;

/// Create a copy of ApprovalRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? details = null,Object? highlightIds = null,}) {
  return _then(_ApprovalRequestModel(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String,highlightIds: null == highlightIds ? _self._highlightIds : highlightIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
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

/// @nodoc
mixin _$DocumentTabModel {

 String get prompt;
/// Create a copy of DocumentTabModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentTabModelCopyWith<DocumentTabModel> get copyWith => _$DocumentTabModelCopyWithImpl<DocumentTabModel>(this as DocumentTabModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentTabModel&&(identical(other.prompt, prompt) || other.prompt == prompt));
}


@override
int get hashCode => Object.hash(runtimeType,prompt);

@override
String toString() {
  return 'DocumentTabModel(prompt: $prompt)';
}


}

/// @nodoc
abstract mixin class $DocumentTabModelCopyWith<$Res>  {
  factory $DocumentTabModelCopyWith(DocumentTabModel value, $Res Function(DocumentTabModel) _then) = _$DocumentTabModelCopyWithImpl;
@useResult
$Res call({
 String prompt
});




}
/// @nodoc
class _$DocumentTabModelCopyWithImpl<$Res>
    implements $DocumentTabModelCopyWith<$Res> {
  _$DocumentTabModelCopyWithImpl(this._self, this._then);

  final DocumentTabModel _self;
  final $Res Function(DocumentTabModel) _then;

/// Create a copy of DocumentTabModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prompt = null,}) {
  return _then(_self.copyWith(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentTabModel].
extension DocumentTabModelPatterns on DocumentTabModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentTabModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentTabModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentTabModel value)  $default,){
final _that = this;
switch (_that) {
case _DocumentTabModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentTabModel value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentTabModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String prompt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentTabModel() when $default != null:
return $default(_that.prompt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String prompt)  $default,) {final _that = this;
switch (_that) {
case _DocumentTabModel():
return $default(_that.prompt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String prompt)?  $default,) {final _that = this;
switch (_that) {
case _DocumentTabModel() when $default != null:
return $default(_that.prompt);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentTabModel implements DocumentTabModel {
  const _DocumentTabModel({this.prompt = ''});
  

@override@JsonKey() final  String prompt;

/// Create a copy of DocumentTabModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentTabModelCopyWith<_DocumentTabModel> get copyWith => __$DocumentTabModelCopyWithImpl<_DocumentTabModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentTabModel&&(identical(other.prompt, prompt) || other.prompt == prompt));
}


@override
int get hashCode => Object.hash(runtimeType,prompt);

@override
String toString() {
  return 'DocumentTabModel(prompt: $prompt)';
}


}

/// @nodoc
abstract mixin class _$DocumentTabModelCopyWith<$Res> implements $DocumentTabModelCopyWith<$Res> {
  factory _$DocumentTabModelCopyWith(_DocumentTabModel value, $Res Function(_DocumentTabModel) _then) = __$DocumentTabModelCopyWithImpl;
@override @useResult
$Res call({
 String prompt
});




}
/// @nodoc
class __$DocumentTabModelCopyWithImpl<$Res>
    implements _$DocumentTabModelCopyWith<$Res> {
  __$DocumentTabModelCopyWithImpl(this._self, this._then);

  final _DocumentTabModel _self;
  final $Res Function(_DocumentTabModel) _then;

/// Create a copy of DocumentTabModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prompt = null,}) {
  return _then(_DocumentTabModel(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginEditorTargetModel {

 String get id; String get relative;
/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginEditorTargetModelCopyWith<PluginEditorTargetModel> get copyWith => _$PluginEditorTargetModelCopyWithImpl<PluginEditorTargetModel>(this as PluginEditorTargetModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginEditorTargetModel&&(identical(other.id, id) || other.id == id)&&(identical(other.relative, relative) || other.relative == relative));
}


@override
int get hashCode => Object.hash(runtimeType,id,relative);

@override
String toString() {
  return 'PluginEditorTargetModel(id: $id, relative: $relative)';
}


}

/// @nodoc
abstract mixin class $PluginEditorTargetModelCopyWith<$Res>  {
  factory $PluginEditorTargetModelCopyWith(PluginEditorTargetModel value, $Res Function(PluginEditorTargetModel) _then) = _$PluginEditorTargetModelCopyWithImpl;
@useResult
$Res call({
 String id, String relative
});




}
/// @nodoc
class _$PluginEditorTargetModelCopyWithImpl<$Res>
    implements $PluginEditorTargetModelCopyWith<$Res> {
  _$PluginEditorTargetModelCopyWithImpl(this._self, this._then);

  final PluginEditorTargetModel _self;
  final $Res Function(PluginEditorTargetModel) _then;

/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? relative = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,relative: null == relative ? _self.relative : relative // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginEditorTargetModel].
extension PluginEditorTargetModelPatterns on PluginEditorTargetModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginEditorTargetModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginEditorTargetModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginEditorTargetModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginEditorTargetModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String relative)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
return $default(_that.id,_that.relative);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String relative)  $default,) {final _that = this;
switch (_that) {
case _PluginEditorTargetModel():
return $default(_that.id,_that.relative);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String relative)?  $default,) {final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
return $default(_that.id,_that.relative);case _:
  return null;

}
}

}

/// @nodoc


class _PluginEditorTargetModel implements PluginEditorTargetModel {
  const _PluginEditorTargetModel({required this.id, required this.relative});
  

@override final  String id;
@override final  String relative;

/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginEditorTargetModelCopyWith<_PluginEditorTargetModel> get copyWith => __$PluginEditorTargetModelCopyWithImpl<_PluginEditorTargetModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginEditorTargetModel&&(identical(other.id, id) || other.id == id)&&(identical(other.relative, relative) || other.relative == relative));
}


@override
int get hashCode => Object.hash(runtimeType,id,relative);

@override
String toString() {
  return 'PluginEditorTargetModel(id: $id, relative: $relative)';
}


}

/// @nodoc
abstract mixin class _$PluginEditorTargetModelCopyWith<$Res> implements $PluginEditorTargetModelCopyWith<$Res> {
  factory _$PluginEditorTargetModelCopyWith(_PluginEditorTargetModel value, $Res Function(_PluginEditorTargetModel) _then) = __$PluginEditorTargetModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String relative
});




}
/// @nodoc
class __$PluginEditorTargetModelCopyWithImpl<$Res>
    implements _$PluginEditorTargetModelCopyWith<$Res> {
  __$PluginEditorTargetModelCopyWithImpl(this._self, this._then);

  final _PluginEditorTargetModel _self;
  final $Res Function(_PluginEditorTargetModel) _then;

/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? relative = null,}) {
  return _then(_PluginEditorTargetModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,relative: null == relative ? _self.relative : relative // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginEditorModel {

 PluginEditorTargetModel? get target; int get request;
/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginEditorModelCopyWith<PluginEditorModel> get copyWith => _$PluginEditorModelCopyWithImpl<PluginEditorModel>(this as PluginEditorModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginEditorModel&&(identical(other.target, target) || other.target == target)&&(identical(other.request, request) || other.request == request));
}


@override
int get hashCode => Object.hash(runtimeType,target,request);

@override
String toString() {
  return 'PluginEditorModel(target: $target, request: $request)';
}


}

/// @nodoc
abstract mixin class $PluginEditorModelCopyWith<$Res>  {
  factory $PluginEditorModelCopyWith(PluginEditorModel value, $Res Function(PluginEditorModel) _then) = _$PluginEditorModelCopyWithImpl;
@useResult
$Res call({
 PluginEditorTargetModel? target, int request
});


$PluginEditorTargetModelCopyWith<$Res>? get target;

}
/// @nodoc
class _$PluginEditorModelCopyWithImpl<$Res>
    implements $PluginEditorModelCopyWith<$Res> {
  _$PluginEditorModelCopyWithImpl(this._self, this._then);

  final PluginEditorModel _self;
  final $Res Function(PluginEditorModel) _then;

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = freezed,Object? request = null,}) {
  return _then(_self.copyWith(
target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PluginEditorTargetModel?,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginEditorTargetModelCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $PluginEditorTargetModelCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginEditorModel].
extension PluginEditorModelPatterns on PluginEditorModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginEditorModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginEditorModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginEditorModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginEditorModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginEditorTargetModel? target,  int request)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
return $default(_that.target,_that.request);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginEditorTargetModel? target,  int request)  $default,) {final _that = this;
switch (_that) {
case _PluginEditorModel():
return $default(_that.target,_that.request);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginEditorTargetModel? target,  int request)?  $default,) {final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
return $default(_that.target,_that.request);case _:
  return null;

}
}

}

/// @nodoc


class _PluginEditorModel implements PluginEditorModel {
  const _PluginEditorModel({this.target, this.request = 0});
  

@override final  PluginEditorTargetModel? target;
@override@JsonKey() final  int request;

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginEditorModelCopyWith<_PluginEditorModel> get copyWith => __$PluginEditorModelCopyWithImpl<_PluginEditorModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginEditorModel&&(identical(other.target, target) || other.target == target)&&(identical(other.request, request) || other.request == request));
}


@override
int get hashCode => Object.hash(runtimeType,target,request);

@override
String toString() {
  return 'PluginEditorModel(target: $target, request: $request)';
}


}

/// @nodoc
abstract mixin class _$PluginEditorModelCopyWith<$Res> implements $PluginEditorModelCopyWith<$Res> {
  factory _$PluginEditorModelCopyWith(_PluginEditorModel value, $Res Function(_PluginEditorModel) _then) = __$PluginEditorModelCopyWithImpl;
@override @useResult
$Res call({
 PluginEditorTargetModel? target, int request
});


@override $PluginEditorTargetModelCopyWith<$Res>? get target;

}
/// @nodoc
class __$PluginEditorModelCopyWithImpl<$Res>
    implements _$PluginEditorModelCopyWith<$Res> {
  __$PluginEditorModelCopyWithImpl(this._self, this._then);

  final _PluginEditorModel _self;
  final $Res Function(_PluginEditorModel) _then;

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = freezed,Object? request = null,}) {
  return _then(_PluginEditorModel(
target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PluginEditorTargetModel?,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginEditorTargetModelCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $PluginEditorTargetModelCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc
mixin _$PluginCommandRefModel {

 String get id; String get title;
/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginCommandRefModelCopyWith<PluginCommandRefModel> get copyWith => _$PluginCommandRefModelCopyWithImpl<PluginCommandRefModel>(this as PluginCommandRefModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginCommandRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title));
}


@override
int get hashCode => Object.hash(runtimeType,id,title);

@override
String toString() {
  return 'PluginCommandRefModel(id: $id, title: $title)';
}


}

/// @nodoc
abstract mixin class $PluginCommandRefModelCopyWith<$Res>  {
  factory $PluginCommandRefModelCopyWith(PluginCommandRefModel value, $Res Function(PluginCommandRefModel) _then) = _$PluginCommandRefModelCopyWithImpl;
@useResult
$Res call({
 String id, String title
});




}
/// @nodoc
class _$PluginCommandRefModelCopyWithImpl<$Res>
    implements $PluginCommandRefModelCopyWith<$Res> {
  _$PluginCommandRefModelCopyWithImpl(this._self, this._then);

  final PluginCommandRefModel _self;
  final $Res Function(PluginCommandRefModel) _then;

/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginCommandRefModel].
extension PluginCommandRefModelPatterns on PluginCommandRefModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginCommandRefModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginCommandRefModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginCommandRefModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginCommandRefModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
return $default(_that.id,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title)  $default,) {final _that = this;
switch (_that) {
case _PluginCommandRefModel():
return $default(_that.id,_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title)?  $default,) {final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
return $default(_that.id,_that.title);case _:
  return null;

}
}

}

/// @nodoc


class _PluginCommandRefModel implements PluginCommandRefModel {
  const _PluginCommandRefModel({required this.id, this.title = ''});
  

@override final  String id;
@override@JsonKey() final  String title;

/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginCommandRefModelCopyWith<_PluginCommandRefModel> get copyWith => __$PluginCommandRefModelCopyWithImpl<_PluginCommandRefModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginCommandRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title));
}


@override
int get hashCode => Object.hash(runtimeType,id,title);

@override
String toString() {
  return 'PluginCommandRefModel(id: $id, title: $title)';
}


}

/// @nodoc
abstract mixin class _$PluginCommandRefModelCopyWith<$Res> implements $PluginCommandRefModelCopyWith<$Res> {
  factory _$PluginCommandRefModelCopyWith(_PluginCommandRefModel value, $Res Function(_PluginCommandRefModel) _then) = __$PluginCommandRefModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title
});




}
/// @nodoc
class __$PluginCommandRefModelCopyWithImpl<$Res>
    implements _$PluginCommandRefModelCopyWith<$Res> {
  __$PluginCommandRefModelCopyWithImpl(this._self, this._then);

  final _PluginCommandRefModel _self;
  final $Res Function(_PluginCommandRefModel) _then;

/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,}) {
  return _then(_PluginCommandRefModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginRefModel {

 String get id; String get name; String get version; String get state; String? get error; String get description; String get directory; String get entryPoint; List<String> get permissions; List<PluginCommandRefModel> get commands; List<String> get log;
/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginRefModelCopyWith<PluginRefModel> get copyWith => _$PluginRefModelCopyWithImpl<PluginRefModel>(this as PluginRefModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.version, version) || other.version == version)&&(identical(other.state, state) || other.state == state)&&(identical(other.error, error) || other.error == error)&&(identical(other.description, description) || other.description == description)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.entryPoint, entryPoint) || other.entryPoint == entryPoint)&&const DeepCollectionEquality().equals(other.permissions, permissions)&&const DeepCollectionEquality().equals(other.commands, commands)&&const DeepCollectionEquality().equals(other.log, log));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,version,state,error,description,directory,entryPoint,const DeepCollectionEquality().hash(permissions),const DeepCollectionEquality().hash(commands),const DeepCollectionEquality().hash(log));

@override
String toString() {
  return 'PluginRefModel(id: $id, name: $name, version: $version, state: $state, error: $error, description: $description, directory: $directory, entryPoint: $entryPoint, permissions: $permissions, commands: $commands, log: $log)';
}


}

/// @nodoc
abstract mixin class $PluginRefModelCopyWith<$Res>  {
  factory $PluginRefModelCopyWith(PluginRefModel value, $Res Function(PluginRefModel) _then) = _$PluginRefModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String version, String state, String? error, String description, String directory, String entryPoint, List<String> permissions, List<PluginCommandRefModel> commands, List<String> log
});




}
/// @nodoc
class _$PluginRefModelCopyWithImpl<$Res>
    implements $PluginRefModelCopyWith<$Res> {
  _$PluginRefModelCopyWithImpl(this._self, this._then);

  final PluginRefModel _self;
  final $Res Function(PluginRefModel) _then;

/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? version = null,Object? state = null,Object? error = freezed,Object? description = null,Object? directory = null,Object? entryPoint = null,Object? permissions = null,Object? commands = null,Object? log = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,entryPoint: null == entryPoint ? _self.entryPoint : entryPoint // ignore: cast_nullable_to_non_nullable
as String,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<PluginCommandRefModel>,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginRefModel].
extension PluginRefModelPatterns on PluginRefModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginRefModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginRefModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginRefModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginRefModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String version,  String state,  String? error,  String description,  String directory,  String entryPoint,  List<String> permissions,  List<PluginCommandRefModel> commands,  List<String> log)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
return $default(_that.id,_that.name,_that.version,_that.state,_that.error,_that.description,_that.directory,_that.entryPoint,_that.permissions,_that.commands,_that.log);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String version,  String state,  String? error,  String description,  String directory,  String entryPoint,  List<String> permissions,  List<PluginCommandRefModel> commands,  List<String> log)  $default,) {final _that = this;
switch (_that) {
case _PluginRefModel():
return $default(_that.id,_that.name,_that.version,_that.state,_that.error,_that.description,_that.directory,_that.entryPoint,_that.permissions,_that.commands,_that.log);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String version,  String state,  String? error,  String description,  String directory,  String entryPoint,  List<String> permissions,  List<PluginCommandRefModel> commands,  List<String> log)?  $default,) {final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
return $default(_that.id,_that.name,_that.version,_that.state,_that.error,_that.description,_that.directory,_that.entryPoint,_that.permissions,_that.commands,_that.log);case _:
  return null;

}
}

}

/// @nodoc


class _PluginRefModel implements PluginRefModel {
  const _PluginRefModel({required this.id, this.name = '', this.version = '', this.state = 'installed', this.error, this.description = '', this.directory = '', this.entryPoint = 'main.js', final  List<String> permissions = const [], final  List<PluginCommandRefModel> commands = const [], final  List<String> log = const []}): _permissions = permissions,_commands = commands,_log = log;
  

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String version;
@override@JsonKey() final  String state;
@override final  String? error;
@override@JsonKey() final  String description;
@override@JsonKey() final  String directory;
@override@JsonKey() final  String entryPoint;
 final  List<String> _permissions;
@override@JsonKey() List<String> get permissions {
  if (_permissions is EqualUnmodifiableListView) return _permissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_permissions);
}

 final  List<PluginCommandRefModel> _commands;
@override@JsonKey() List<PluginCommandRefModel> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}

 final  List<String> _log;
@override@JsonKey() List<String> get log {
  if (_log is EqualUnmodifiableListView) return _log;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_log);
}


/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginRefModelCopyWith<_PluginRefModel> get copyWith => __$PluginRefModelCopyWithImpl<_PluginRefModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.version, version) || other.version == version)&&(identical(other.state, state) || other.state == state)&&(identical(other.error, error) || other.error == error)&&(identical(other.description, description) || other.description == description)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.entryPoint, entryPoint) || other.entryPoint == entryPoint)&&const DeepCollectionEquality().equals(other._permissions, _permissions)&&const DeepCollectionEquality().equals(other._commands, _commands)&&const DeepCollectionEquality().equals(other._log, _log));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,version,state,error,description,directory,entryPoint,const DeepCollectionEquality().hash(_permissions),const DeepCollectionEquality().hash(_commands),const DeepCollectionEquality().hash(_log));

@override
String toString() {
  return 'PluginRefModel(id: $id, name: $name, version: $version, state: $state, error: $error, description: $description, directory: $directory, entryPoint: $entryPoint, permissions: $permissions, commands: $commands, log: $log)';
}


}

/// @nodoc
abstract mixin class _$PluginRefModelCopyWith<$Res> implements $PluginRefModelCopyWith<$Res> {
  factory _$PluginRefModelCopyWith(_PluginRefModel value, $Res Function(_PluginRefModel) _then) = __$PluginRefModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String version, String state, String? error, String description, String directory, String entryPoint, List<String> permissions, List<PluginCommandRefModel> commands, List<String> log
});




}
/// @nodoc
class __$PluginRefModelCopyWithImpl<$Res>
    implements _$PluginRefModelCopyWith<$Res> {
  __$PluginRefModelCopyWithImpl(this._self, this._then);

  final _PluginRefModel _self;
  final $Res Function(_PluginRefModel) _then;

/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? version = null,Object? state = null,Object? error = freezed,Object? description = null,Object? directory = null,Object? entryPoint = null,Object? permissions = null,Object? commands = null,Object? log = null,}) {
  return _then(_PluginRefModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,entryPoint: null == entryPoint ? _self.entryPoint : entryPoint // ignore: cast_nullable_to_non_nullable
as String,permissions: null == permissions ? _self._permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<PluginCommandRefModel>,log: null == log ? _self._log : log // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$PluginModel {

 bool get started; String get directory; List<PluginRefModel> get plugins; Map<String, List<String>> get logs; int get epoch;
/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginModelCopyWith<PluginModel> get copyWith => _$PluginModelCopyWithImpl<PluginModel>(this as PluginModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginModel&&(identical(other.started, started) || other.started == started)&&(identical(other.directory, directory) || other.directory == directory)&&const DeepCollectionEquality().equals(other.plugins, plugins)&&const DeepCollectionEquality().equals(other.logs, logs)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode => Object.hash(runtimeType,started,directory,const DeepCollectionEquality().hash(plugins),const DeepCollectionEquality().hash(logs),epoch);

@override
String toString() {
  return 'PluginModel(started: $started, directory: $directory, plugins: $plugins, logs: $logs, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class $PluginModelCopyWith<$Res>  {
  factory $PluginModelCopyWith(PluginModel value, $Res Function(PluginModel) _then) = _$PluginModelCopyWithImpl;
@useResult
$Res call({
 bool started, String directory, List<PluginRefModel> plugins, Map<String, List<String>> logs, int epoch
});




}
/// @nodoc
class _$PluginModelCopyWithImpl<$Res>
    implements $PluginModelCopyWith<$Res> {
  _$PluginModelCopyWithImpl(this._self, this._then);

  final PluginModel _self;
  final $Res Function(PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? started = null,Object? directory = null,Object? plugins = null,Object? logs = null,Object? epoch = null,}) {
  return _then(_self.copyWith(
started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginRefModel>,logs: null == logs ? _self.logs : logs // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,epoch: null == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginModel].
extension PluginModelPatterns on PluginModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool started,  String directory,  List<PluginRefModel> plugins,  Map<String, List<String>> logs,  int epoch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
return $default(_that.started,_that.directory,_that.plugins,_that.logs,_that.epoch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool started,  String directory,  List<PluginRefModel> plugins,  Map<String, List<String>> logs,  int epoch)  $default,) {final _that = this;
switch (_that) {
case _PluginModel():
return $default(_that.started,_that.directory,_that.plugins,_that.logs,_that.epoch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool started,  String directory,  List<PluginRefModel> plugins,  Map<String, List<String>> logs,  int epoch)?  $default,) {final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
return $default(_that.started,_that.directory,_that.plugins,_that.logs,_that.epoch);case _:
  return null;

}
}

}

/// @nodoc


class _PluginModel implements PluginModel {
  const _PluginModel({this.started = false, this.directory = '', final  List<PluginRefModel> plugins = const [], final  Map<String, List<String>> logs = const {}, this.epoch = 0}): _plugins = plugins,_logs = logs;
  

@override@JsonKey() final  bool started;
@override@JsonKey() final  String directory;
 final  List<PluginRefModel> _plugins;
@override@JsonKey() List<PluginRefModel> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}

 final  Map<String, List<String>> _logs;
@override@JsonKey() Map<String, List<String>> get logs {
  if (_logs is EqualUnmodifiableMapView) return _logs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_logs);
}

@override@JsonKey() final  int epoch;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginModelCopyWith<_PluginModel> get copyWith => __$PluginModelCopyWithImpl<_PluginModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginModel&&(identical(other.started, started) || other.started == started)&&(identical(other.directory, directory) || other.directory == directory)&&const DeepCollectionEquality().equals(other._plugins, _plugins)&&const DeepCollectionEquality().equals(other._logs, _logs)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode => Object.hash(runtimeType,started,directory,const DeepCollectionEquality().hash(_plugins),const DeepCollectionEquality().hash(_logs),epoch);

@override
String toString() {
  return 'PluginModel(started: $started, directory: $directory, plugins: $plugins, logs: $logs, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class _$PluginModelCopyWith<$Res> implements $PluginModelCopyWith<$Res> {
  factory _$PluginModelCopyWith(_PluginModel value, $Res Function(_PluginModel) _then) = __$PluginModelCopyWithImpl;
@override @useResult
$Res call({
 bool started, String directory, List<PluginRefModel> plugins, Map<String, List<String>> logs, int epoch
});




}
/// @nodoc
class __$PluginModelCopyWithImpl<$Res>
    implements _$PluginModelCopyWith<$Res> {
  __$PluginModelCopyWithImpl(this._self, this._then);

  final _PluginModel _self;
  final $Res Function(_PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? started = null,Object? directory = null,Object? plugins = null,Object? logs = null,Object? epoch = null,}) {
  return _then(_PluginModel(
started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginRefModel>,logs: null == logs ? _self._logs : logs // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,epoch: null == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
