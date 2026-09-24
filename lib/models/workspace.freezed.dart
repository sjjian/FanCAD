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

 List<WorkspaceSessionModel> get sessions; int get activeIndex; List<NoticeModel> get notices; ApprovalRequestModel? get approval; bool get assistantBusy; String? get runningCommand; bool get snapEnabled; bool get ortho; bool get polar; List<String> get snapModes; List<String> get recentFiles;/// Last geometry the human or the assistant created or changed.
 List<int> get lastCreatedIds; List<int> get lastModifiedIds; int get collectedPointCount;
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

/// Last geometry the human or the assistant created or changed.
 final  List<int> _lastCreatedIds;
/// Last geometry the human or the assistant created or changed.
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
mixin _$DocumentTabModel {

 String get prompt; int get contentEpoch; int get selectionEpoch;
/// Create a copy of DocumentTabModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentTabModelCopyWith<DocumentTabModel> get copyWith => _$DocumentTabModelCopyWithImpl<DocumentTabModel>(this as DocumentTabModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentTabModel&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.contentEpoch, contentEpoch) || other.contentEpoch == contentEpoch)&&(identical(other.selectionEpoch, selectionEpoch) || other.selectionEpoch == selectionEpoch));
}


@override
int get hashCode => Object.hash(runtimeType,prompt,contentEpoch,selectionEpoch);

@override
String toString() {
  return 'DocumentTabModel(prompt: $prompt, contentEpoch: $contentEpoch, selectionEpoch: $selectionEpoch)';
}


}

/// @nodoc
abstract mixin class $DocumentTabModelCopyWith<$Res>  {
  factory $DocumentTabModelCopyWith(DocumentTabModel value, $Res Function(DocumentTabModel) _then) = _$DocumentTabModelCopyWithImpl;
@useResult
$Res call({
 String prompt, int contentEpoch, int selectionEpoch
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
@pragma('vm:prefer-inline') @override $Res call({Object? prompt = null,Object? contentEpoch = null,Object? selectionEpoch = null,}) {
  return _then(_self.copyWith(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,contentEpoch: null == contentEpoch ? _self.contentEpoch : contentEpoch // ignore: cast_nullable_to_non_nullable
as int,selectionEpoch: null == selectionEpoch ? _self.selectionEpoch : selectionEpoch // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String prompt,  int contentEpoch,  int selectionEpoch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentTabModel() when $default != null:
return $default(_that.prompt,_that.contentEpoch,_that.selectionEpoch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String prompt,  int contentEpoch,  int selectionEpoch)  $default,) {final _that = this;
switch (_that) {
case _DocumentTabModel():
return $default(_that.prompt,_that.contentEpoch,_that.selectionEpoch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String prompt,  int contentEpoch,  int selectionEpoch)?  $default,) {final _that = this;
switch (_that) {
case _DocumentTabModel() when $default != null:
return $default(_that.prompt,_that.contentEpoch,_that.selectionEpoch);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentTabModel implements DocumentTabModel {
  const _DocumentTabModel({this.prompt = '', this.contentEpoch = 0, this.selectionEpoch = 0});
  

@override@JsonKey() final  String prompt;
@override@JsonKey() final  int contentEpoch;
@override@JsonKey() final  int selectionEpoch;

/// Create a copy of DocumentTabModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentTabModelCopyWith<_DocumentTabModel> get copyWith => __$DocumentTabModelCopyWithImpl<_DocumentTabModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentTabModel&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.contentEpoch, contentEpoch) || other.contentEpoch == contentEpoch)&&(identical(other.selectionEpoch, selectionEpoch) || other.selectionEpoch == selectionEpoch));
}


@override
int get hashCode => Object.hash(runtimeType,prompt,contentEpoch,selectionEpoch);

@override
String toString() {
  return 'DocumentTabModel(prompt: $prompt, contentEpoch: $contentEpoch, selectionEpoch: $selectionEpoch)';
}


}

/// @nodoc
abstract mixin class _$DocumentTabModelCopyWith<$Res> implements $DocumentTabModelCopyWith<$Res> {
  factory _$DocumentTabModelCopyWith(_DocumentTabModel value, $Res Function(_DocumentTabModel) _then) = __$DocumentTabModelCopyWithImpl;
@override @useResult
$Res call({
 String prompt, int contentEpoch, int selectionEpoch
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
@override @pragma('vm:prefer-inline') $Res call({Object? prompt = null,Object? contentEpoch = null,Object? selectionEpoch = null,}) {
  return _then(_DocumentTabModel(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,contentEpoch: null == contentEpoch ? _self.contentEpoch : contentEpoch // ignore: cast_nullable_to_non_nullable
as int,selectionEpoch: null == selectionEpoch ? _self.selectionEpoch : selectionEpoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
